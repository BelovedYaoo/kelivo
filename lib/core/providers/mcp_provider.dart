import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:kelivo_secure_core/kelivo_secure_core.dart';
import 'package:mcp_client/mcp_client.dart' as mcp;
import '../services/mcp/kelivo_fetch/kelivo_fetch_server.dart';
import '../services/mcp/stdio_command_resolver.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../services/sync/config_sync_keys.dart';
import '../services/sync/sync_codec.dart';
import '../services/sync/sync_write_executor.dart';
import '../utils/batched_change_notifier.dart';

/// Transport type: SSE, Streamable HTTP, and STDIO (desktop-only).
enum McpTransportType { sse, http, stdio, inmemory }

/// Connection status for an MCP server.
enum McpStatus { idle, connecting, connected, error }

class McpParamSpec {
  final String name;
  final bool required;
  final String? type;
  final dynamic defaultValue;

  McpParamSpec({
    required this.name,
    required this.required,
    this.type,
    this.defaultValue,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'required': required,
    'type': type,
    'default': defaultValue,
  };

  factory McpParamSpec.fromJson(Map<String, dynamic> json) => McpParamSpec(
    name: json['name'] as String? ?? '',
    required: json['required'] as bool? ?? false,
    type: json['type'] as String?,
    defaultValue: json['default'],
  );
}

class McpToolConfig {
  final bool enabled;
  final String name;
  final String? description;
  final List<McpParamSpec> params;
  // Raw JSON schema for parameters, if provided by the server
  final Map<String, dynamic>? schema;

  /// Whether this tool requires user approval before execution.
  final bool needsApproval;

  McpToolConfig({
    required this.enabled,
    required this.name,
    this.description,
    this.params = const [],
    this.schema,
    this.needsApproval = false,
  });

  McpToolConfig copyWith({
    bool? enabled,
    String? name,
    String? description,
    List<McpParamSpec>? params,
    Map<String, dynamic>? schema,
    bool? needsApproval,
  }) => McpToolConfig(
    enabled: enabled ?? this.enabled,
    name: name ?? this.name,
    description: description ?? this.description,
    params: params ?? this.params,
    schema: schema ?? this.schema,
    needsApproval: needsApproval ?? this.needsApproval,
  );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'name': name,
    'description': description,
    'params': params.map((e) => e.toJson()).toList(),
    if (schema != null) 'schema': schema,
    if (needsApproval) 'needsApproval': true,
  };

  factory McpToolConfig.fromJson(Map<String, dynamic> json) => McpToolConfig(
    enabled: json['enabled'] as bool? ?? true,
    name: json['name'] as String? ?? '',
    description: json['description'] as String?,
    params:
        (json['params'] as List?)
            ?.map(
              (e) => McpParamSpec.fromJson((e as Map).cast<String, dynamic>()),
            )
            .toList() ??
        const [],
    schema: (json['schema'] is Map)
        ? (json['schema'] as Map).cast<String, dynamic>()
        : null,
    needsApproval: json['needsApproval'] as bool? ?? false,
  );
}

class McpServerConfig {
  final String id; // stable id
  final bool enabled;
  final String name;
  final McpTransportType transport;
  // For SSE/HTTP
  final String url; // SSE endpoint or HTTP base URL
  final List<McpToolConfig> tools;
  final Map<String, String> headers; // custom HTTP headers
  // For STDIO (desktop-only)
  final String? command;
  final List<String> args;
  final Map<String, String> env;
  final String? workingDirectory;

  McpServerConfig({
    required this.id,
    required this.enabled,
    required this.name,
    required this.transport,
    this.url = '',
    this.tools = const [],
    this.headers = const {},
    this.command,
    this.args = const [],
    this.env = const {},
    this.workingDirectory,
  });

  McpServerConfig copyWith({
    String? id,
    bool? enabled,
    String? name,
    McpTransportType? transport,
    String? url,
    List<McpToolConfig>? tools,
    Map<String, String>? headers,
    String? command,
    List<String>? args,
    Map<String, String>? env,
    String? workingDirectory,
    bool clearWorkingDirectory = false,
  }) => McpServerConfig(
    id: id ?? this.id,
    enabled: enabled ?? this.enabled,
    name: name ?? this.name,
    transport: transport ?? this.transport,
    url: url ?? this.url,
    tools: tools ?? this.tools,
    headers: headers ?? this.headers,
    command: command ?? this.command,
    args: args ?? this.args,
    env: env ?? this.env,
    workingDirectory: clearWorkingDirectory
        ? null
        : (workingDirectory ?? this.workingDirectory),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'enabled': enabled,
    'name': name,
    'transport': transport.name,
    if (transport != McpTransportType.stdio &&
        transport != McpTransportType.inmemory)
      'url': url,
    'tools': tools.map((e) => e.toJson()).toList(),
    if (transport != McpTransportType.stdio &&
        transport != McpTransportType.inmemory)
      'headers': headers,
    if (transport == McpTransportType.stdio) 'command': command,
    if (transport == McpTransportType.stdio) 'args': args,
    if (transport == McpTransportType.stdio) 'env': env,
    if (transport == McpTransportType.stdio && workingDirectory != null)
      'workingDirectory': workingDirectory,
  };

  factory McpServerConfig.fromJson(Map<String, dynamic> json) {
    final tRaw = (json['transport'] as String?) ?? '';
    final t = tRaw == 'http'
        ? McpTransportType.http
        : (tRaw == 'stdio'
              ? McpTransportType.stdio
              : (tRaw == 'inmemory'
                    ? McpTransportType.inmemory
                    : McpTransportType.sse));
    final tools =
        (json['tools'] as List?)
            ?.map(
              (e) => McpToolConfig.fromJson((e as Map).cast<String, dynamic>()),
            )
            .toList() ??
        const <McpToolConfig>[];
    if (t == McpTransportType.stdio) {
      final argsAny = json['args'];
      final envAny = json['env'];
      return McpServerConfig(
        id: json['id'] as String? ?? const Uuid().v4(),
        enabled: json['enabled'] as bool? ?? true,
        name: json['name'] as String? ?? '',
        transport: McpTransportType.stdio,
        tools: tools,
        command: (json['command'] as String?)?.trim(),
        args: argsAny is List
            ? argsAny.map((e) => e.toString()).toList()
            : const <String>[],
        env: envAny is Map
            ? envAny.map((k, v) => MapEntry(k.toString(), v.toString()))
            : const <String, String>{},
        workingDirectory: (json['workingDirectory'] as String?)?.trim(),
      );
    } else if (t == McpTransportType.inmemory) {
      return McpServerConfig(
        id: json['id'] as String? ?? const Uuid().v4(),
        enabled: json['enabled'] as bool? ?? true,
        name: json['name'] as String? ?? '',
        transport: McpTransportType.inmemory,
        tools: tools,
      );
    } else {
      return McpServerConfig(
        id: json['id'] as String? ?? const Uuid().v4(),
        enabled: json['enabled'] as bool? ?? true,
        name: json['name'] as String? ?? '',
        transport: t,
        url: json['url'] as String? ?? '',
        tools: tools,
        headers:
            ((json['headers'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), v.toString()),
            )) ??
            const {},
      );
    }
  }
}

class _Cooldown {
  final DateTime startedAt;
  final DateTime until;

  const _Cooldown({required this.startedAt, required this.until});
}

/// Per-server connection state for remote MCP session reuse.
class _ServerConnection {
  mcp.Client? client;
  Future<bool>? connectFuture;
  int generation = 0;
  _Cooldown? cooldown;
  Future<void>? refreshFuture;
  bool refreshDirty = false;
}

enum _ToolRefreshOutcome { success, sessionExpired, failed }

class McpProvider extends ChangeNotifier with BatchedChangeNotifier {
  static const String _prefsKey = 'mcp_servers_v1';
  static const String _localServersPrefsKey = 'mcp_local_servers_v1';
  static const String _prefsTimeoutKey = 'mcp_request_timeout_ms_v1';

  // 本地服务器（stdio/inmemory）含 env 与命令路径，属设备本地凭据，刻意不同步。
  // 存储时用设备安全槽密封；未注入 secure core（仅测试）时保持明文以便隔离。
  static const String _encryptedStoragePrefix = 'kelivo-mcp-v1:';
  static final Uint8List _localSlotId = Uint8List.fromList(
    sha256
        .convert(utf8.encode('kelivo-mcp-local-servers'))
        .bytes
        .sublist(0, 16),
  );
  static final Uint8List _localRecordId = Uint8List.fromList(
    sha256
        .convert(utf8.encode('kelivo-mcp-local-servers-record'))
        .bytes
        .sublist(0, 16),
  );
  static final Uint8List _localAssociatedData = Uint8List.fromList(
    sha256.convert(utf8.encode('kelivo-mcp-local-servers-aad-v1')).bytes,
  );
  static const int _localRecordEpoch = 1;

  final Map<String, McpStatus> _status = {}; // id -> status
  final Map<String, String> _errors = {}; // id -> last error
  List<McpServerConfig> _servers = [];
  bool _disposed = false;
  // Reconnect bookkeeping to avoid duplicate concurrent retries
  final Set<String> _reconnecting = <String>{};
  // Heartbeat timers for live-connection health checks
  final Map<String, Timer> _heartbeats = <String, Timer>{};
  // Session-reuse bookkeeping: one entry per server id, carrying the
  // connected client, connect de-duplication, generation and failure
  // cooldown so remote MCP sessions are reused instead of re-initialized.
  final Map<String, _ServerConnection> _connections =
      <String, _ServerConnection>{};
  Duration _requestTimeout = const Duration(seconds: 30);
  final McpStdioCommandResolver _stdioCommandResolver =
      McpStdioCommandResolver();
  late final Future<void> ready;
  final SyncWriteExecutor _syncWrites;
  final KelivoSecureCore? _secureCore;

  McpProvider({
    required SyncWriteExecutor syncWriteExecutor,
    KelivoSecureCore? secureCore,
  }) : _syncWrites = syncWriteExecutor,
       _secureCore = secureCore {
    ready = _load();
  }

  Future<String?> _readEncryptedStorage(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    final core = _secureCore;
    if (core == null || !raw.startsWith(_encryptedStoragePrefix)) {
      // 无安全核心（测试）或旧明文数据：按明文返回，由调用方决定迁移。
      return raw.startsWith(_encryptedStoragePrefix) ? null : raw;
    }
    final KelivoKeyHandle handle;
    try {
      handle = await core.openSlot(_localSlotId);
    } on KelivoSecureCoreException {
      // 槽不存在说明密文是孤儿数据（本地清除过安全槽）。
      return null;
    }
    try {
      final envelope = base64Decode(
        raw.substring(_encryptedStoragePrefix.length),
      );
      final plaintext = await core.openRecord(
        handle,
        recordId: _localRecordId,
        epoch: _localRecordEpoch,
        associatedData: _localAssociatedData,
        envelope: envelope,
      );
      return utf8.decode(plaintext);
    } on KelivoSecureCoreException {
      return null;
    } finally {
      await core.close(handle);
    }
  }

  Future<KelivoKeyHandle> _openOrCreateLocalSlot() async {
    final core = _secureCore!;
    try {
      return await core.createSlot(_localSlotId);
    } on KelivoSecureCoreException catch (error) {
      if (error.status != KelivoSecureCoreStatus.slotAlreadyExists) rethrow;
      return await core.openSlot(_localSlotId);
    }
  }

  Future<void> _writeEncryptedStorage(String key, String json) async {
    final prefs = await SharedPreferences.getInstance();
    final core = _secureCore;
    if (core == null) {
      await prefs.setString(key, json);
      return;
    }
    final handle = await _openOrCreateLocalSlot();
    try {
      final envelope = await core.sealRecord(
        handle,
        recordId: _localRecordId,
        epoch: _localRecordEpoch,
        associatedData: _localAssociatedData,
        plaintext: Uint8List.fromList(utf8.encode(json)),
      );
      await prefs.setString(
        key,
        '$_encryptedStoragePrefix${base64Encode(envelope)}',
      );
    } finally {
      await core.close(handle);
    }
  }

  bool _isPortable(McpServerConfig server) =>
      server.transport == McpTransportType.http ||
      server.transport == McpTransportType.sse;

  List<SyncEntityKey> _portableServerKeys({
    Iterable<McpServerConfig> extraServers = const [],
  }) {
    final ids = <String>{
      ..._servers.where(_isPortable).map((server) => server.id),
      ...extraServers.where(_isPortable).map((server) => server.id),
    };
    return ids.map(ConfigSyncKeys.mcpServer).toList(growable: false);
  }

  Future<T> _runPortableServerWrite<T>({
    required Iterable<SyncEntityKey> keys,
    required Future<T> Function() write,
  }) {
    final declared = keys.toList(growable: false);
    if (declared.isEmpty) return write();
    return _syncWrites.runLocalBatch(keys: declared, write: write);
  }

  List<McpServerConfig> get servers => List.unmodifiable(_servers);
  McpStatus statusFor(String id) => _status[id] ?? McpStatus.idle;
  String? errorFor(String id) => _errors[id];
  bool get hasAnyEnabled => _servers.any((s) => s.enabled);
  bool isConnected(String id) =>
      _connections.containsKey(id) && statusFor(id) == McpStatus.connected;
  List<McpServerConfig> get connectedServers => _servers
      .where((s) => statusFor(s.id) == McpStatus.connected)
      .toList(growable: false);
  Duration get requestTimeout => _requestTimeout;
  int get requestTimeoutSeconds => _requestTimeout.inSeconds;

  Future<void> _load() async {
    final useConfigVault = usesE2eeConfigVault(_syncWrites);
    final prefs = await SharedPreferences.getInstance();
    if (!useConfigVault) {
      final timeoutMs = prefs.getInt(_prefsTimeoutKey);
      if (timeoutMs != null && timeoutMs > 0) {
        _requestTimeout = Duration(milliseconds: timeoutMs);
      }
    }
    final storageKey = useConfigVault ? _localServersPrefsKey : _prefsKey;
    final raw = await _readEncryptedStorage(storageKey);
    var migratedPlaintext = false;
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = (jsonDecode(raw) as List)
            .map(
              (e) =>
                  McpServerConfig.fromJson((e as Map).cast<String, dynamic>()),
            )
            .toList();
        // stdio 命令依赖本机环境；账号模式只从本机键恢复这部分配置。
        _servers = useConfigVault
            ? decoded.where((server) => !_isPortable(server)).toList()
            : decoded;
        // 旧版本以明文落盘；检测到明文时立即重写为密封密文。
        final storedRaw = prefs.getString(storageKey);
        if (_secureCore != null &&
            storedRaw != null &&
            !storedRaw.startsWith(_encryptedStoragePrefix)) {
          migratedPlaintext = true;
        }
      } catch (_) {
        _servers = <McpServerConfig>[];
      }
    }
    if (migratedPlaintext) {
      await _persist();
    }
    // Ensure built-in @kelivo/fetch is present by default
    _ensureBuiltinFetchServerPresent();
    // initialize statuses
    for (final s in _servers) {
      _status[s.id] = McpStatus.idle;
      _errors.remove(s.id);
    }
    notifyListeners();

    // Auto-connect enabled servers
    for (final s in _servers.where((e) => e.enabled)) {
      // fire and forget
      unawaited(connect(s.id));
    }
  }

  void _ensureBuiltinFetchServerPresent() {
    final exists = _servers.any(
      (s) =>
          s.transport == McpTransportType.inmemory ||
          s.name == '@kelivo/fetch' ||
          s.id == 'kelivo_fetch',
    );
    if (exists) return;
    final cfg = McpServerConfig(
      id: 'kelivo_fetch',
      enabled: true,
      name: '@kelivo/fetch',
      transport: McpTransportType.inmemory,
      tools: const <McpToolConfig>[], // will refresh on connect
    );
    _servers = [..._servers, cfg];
  }

  Future<void> _persist() async {
    final useConfigVault = usesE2eeConfigVault(_syncWrites);
    final prefs = await SharedPreferences.getInstance();
    final persistedServers = useConfigVault
        ? _servers.where((server) => !_isPortable(server))
        : _servers;
    await _writeEncryptedStorage(
      useConfigVault ? _localServersPrefsKey : _prefsKey,
      jsonEncode(persistedServers.map((e) => e.toJson()).toList()),
    );
    if (!useConfigVault) {
      await prefs.setInt(_prefsTimeoutKey, _requestTimeout.inMilliseconds);
    }
  }

  Future<void> _persistTimeout() async {
    if (usesE2eeConfigVault(_syncWrites)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsTimeoutKey, _requestTimeout.inMilliseconds);
  }

  /// Export current MCP servers as a user-friendly JSON structure.
  ///
  /// Shape:
  /// {
  ///   "mcpServers": {
  ///     "serverId": {
  ///       "name": "...",
  ///       "type": "streamableHttp" | "sse",
  ///       "description": "",
  ///       "isActive": true/false,
  ///       "baseUrl": "...",
  ///       "headers": { ... }
  ///     },
  ///     ...
  ///   }
  /// }
  String exportServersAsUiJson() {
    // On mobile, skip stdio entries in exported JSON.
    final isDesktop = _isDesktopPlatform();
    final map = <String, dynamic>{
      'mcpServers': {
        for (final s in _servers)
          if (s.transport != McpTransportType.stdio || isDesktop)
            s.id: {
              'name': s.name,
              if (s.transport == McpTransportType.http)
                'type': 'streamableHttp',
              if (s.transport == McpTransportType.sse) 'type': 'sse',
              if (s.transport == McpTransportType.inmemory) 'type': 'inmemory',
              'description': '',
              'isActive': s.enabled,
              if (s.transport != McpTransportType.stdio &&
                  s.transport != McpTransportType.inmemory)
                'baseUrl': s.url,
              if (s.transport != McpTransportType.stdio &&
                  s.transport != McpTransportType.inmemory &&
                  s.headers.isNotEmpty)
                'headers': s.headers,
              // For stdio, include an optional type for compatibility
              if (s.transport == McpTransportType.stdio) 'type': 'stdio',
              // Include command/args/env
              if (s.transport == McpTransportType.stdio &&
                  (s.command ?? '').isNotEmpty)
                'command': s.command,
              if (s.transport == McpTransportType.stdio && s.args.isNotEmpty)
                'args': s.args,
              if (s.transport == McpTransportType.stdio && s.env.isNotEmpty)
                'env': s.env,
              if (s.transport == McpTransportType.stdio)
                ...() {
                  final reg =
                      s.env['NPM_CONFIG_REGISTRY'] ??
                      s.env['npm_config_registry'];
                  return reg != null && reg.isNotEmpty
                      ? {'registryUrl': reg}
                      : <String, dynamic>{};
                }(),
              if (s.transport == McpTransportType.stdio &&
                  (s.workingDirectory ?? '').isNotEmpty)
                'workingDirectory': s.workingDirectory,
            },
      },
    };
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  /// Replace all MCP servers from a JSON string.
  /// Accepts either the UI JSON (with top-level `mcpServers`) or the internal list format.
  Future<void> replaceAllFromJson(String rawJson) async {
    dynamic data;
    try {
      data = jsonDecode(rawJson);
    } catch (e) {
      throw FormatException('Invalid JSON: ${e.toString()}');
    }

    List<McpServerConfig> next = [];
    try {
      Map<String, dynamic>? serversFromMap;
      if (data is Map && data.containsKey('mcpServers')) {
        serversFromMap = (data['mcpServers'] as Map).cast<String, dynamic>();
      } else if (data is Map && data.isNotEmpty) {
        // Allow raw map format: { id: { ... } }
        // Heuristically treat it as mcpServers format when values are maps.
        final ok = data.values.every((v) => v is Map);
        if (ok) serversFromMap = data.cast<String, dynamic>();
      }

      if (serversFromMap != null) {
        final isDesktop = _isDesktopPlatform();
        bool builtinSeen = false;
        bool builtinEnabled = true;
        serversFromMap.forEach((id, cfgAny) {
          if (cfgAny is! Map) return;
          final cfg = cfgAny.cast<String, dynamic>();
          final typeLower = (cfg['type'] ?? '').toString().toLowerCase();
          if (typeLower == 'inmemory') {
            // Built-in @kelivo/fetch control via isActive; ignore name mismatches silently
            builtinSeen = true;
            builtinEnabled = (cfg['isActive'] as bool?) ?? true;
            return;
          }
          final hasStdioShape =
              cfg.containsKey('command') ||
              cfg.containsKey('args') ||
              cfg.containsKey('env') ||
              (cfg['type']?.toString().toLowerCase() == 'stdio');
          if (hasStdioShape) {
            if (!isDesktop) {
              // Mobile: skip stdio entries entirely
              return;
            }
            final enabled = (cfg['isActive'] as bool?) ?? true;
            final name = (cfg['name'] as String?)?.trim();
            final cmd = (cfg['command'] as String?)?.trim();
            if (cmd == null || cmd.isEmpty) {
              // invalid stdio entry without command
              return;
            }
            final argsAny = cfg['args'];
            final envAny = cfg['env'];
            final wd = (cfg['workingDirectory'] as String?)?.trim();
            final registryUrl = (cfg['registryUrl'] as String?)?.trim();
            Map<String, String> env = envAny is Map
                ? envAny.map((k, v) => MapEntry(k.toString(), v.toString()))
                : const <String, String>{};
            if ((registryUrl != null) && registryUrl.isNotEmpty) {
              if (!env.containsKey('NPM_CONFIG_REGISTRY') &&
                  !env.containsKey('npm_config_registry')) {
                env = {...env, 'NPM_CONFIG_REGISTRY': registryUrl};
              }
            }
            next.add(
              McpServerConfig(
                id: id,
                enabled: enabled,
                name: (name == null || name.isEmpty) ? id : name,
                transport: McpTransportType.stdio,
                command: cmd,
                args: argsAny is List
                    ? argsAny.map((e) => e.toString()).toList()
                    : const <String>[],
                env: env,
                workingDirectory: (wd != null && wd.isNotEmpty) ? wd : null,
              ),
            );
            return;
          }

          // SSE/HTTP branch using legacy fields
          final typeRaw = (cfg['type'] ?? '').toString().toLowerCase();
          final transport = (typeRaw.contains('http'))
              ? McpTransportType.http
              : McpTransportType.sse;
          final enabled = (cfg['isActive'] as bool?) ?? true;
          final name = (cfg['name'] as String?)?.trim();
          final url = (cfg['baseUrl'] as String?)?.trim();
          final headersAny = cfg['headers'];
          Map<String, String> headers = const {};
          if (headersAny is Map) {
            headers = headersAny.map(
              (k, v) => MapEntry(k.toString(), v.toString()),
            );
          }
          if ((url ?? '').isEmpty) {
            // Skip invalid entries with empty URL
            return;
          }
          next.add(
            McpServerConfig(
              id: id,
              enabled: enabled,
              name: (name == null || name.isEmpty) ? id : name,
              transport: transport,
              url: url!,
              headers: headers,
            ),
          );
        });
        if (builtinSeen) {
          // Append single built-in server with fixed id/name
          next.add(
            McpServerConfig(
              id: 'kelivo_fetch',
              enabled: builtinEnabled,
              name: '@kelivo/fetch',
              transport: McpTransportType.inmemory,
            ),
          );
        }
      } else if (data is List) {
        // Attempt to parse internal list format. Be tolerant to transport string variants.
        for (final item in data) {
          if (item is! Map) continue;
          final m = item.cast<String, dynamic>();
          final t = (m['transport'] ?? '').toString().toLowerCase();
          if (t == 'streamablehttp' || t.contains('http')) {
            m['transport'] = 'http';
          } else if (t == 'sse') {
            m['transport'] = 'sse';
          } else if (t == 'stdio') {
            m['transport'] = 'stdio';
          }
          try {
            final s = McpServerConfig.fromJson(m);
            if (s.transport != McpTransportType.stdio &&
                s.transport != McpTransportType.inmemory &&
                s.url.trim().isEmpty) {
              continue;
            }
            next.add(s);
          } catch (_) {}
        }
      } else if (data is Map && data.containsKey('servers')) {
        final list = data['servers'];
        if (list is List) {
          for (final item in list) {
            if (item is! Map) continue;
            final m = item.cast<String, dynamic>();
            final t = (m['transport'] ?? '').toString().toLowerCase();
            if (t == 'streamablehttp' || t.contains('http')) {
              m['transport'] = 'http';
            } else if (t == 'sse') {
              m['transport'] = 'sse';
            } else if (t == 'stdio') {
              m['transport'] = 'stdio';
            }
            try {
              final s = McpServerConfig.fromJson(m);
              if (s.transport != McpTransportType.stdio &&
                  s.transport != McpTransportType.inmemory &&
                  s.url.trim().isEmpty) {
                continue;
              }
              next.add(s);
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      throw FormatException('Unrecognized or invalid MCP JSON');
    }

    if (next.isEmpty) {
      throw FormatException('No valid MCP servers found in JSON');
    }

    await _runPortableServerWrite(
      keys: _portableServerKeys(extraServers: next),
      write: () async {
        for (final server in _servers) {
          try {
            await disconnect(server.id);
          } catch (_) {}
        }

        _servers = next;
        _status.clear();
        _errors.clear();
        for (final server in _servers) {
          _status[server.id] = McpStatus.idle;
        }

        await _persist();
        notifyListeners();

        for (final server in _servers.where((server) => server.enabled)) {
          unawaited(connect(server.id));
        }
      },
    );
  }

  McpServerConfig? getById(String id) {
    for (final s in _servers) {
      if (s.id == id) return s;
    }
    return null;
  }

  Future<String> addServer({
    required bool enabled,
    required String name,
    required McpTransportType transport,
    String url = '',
    Map<String, String> headers = const {},
    String? command,
    List<String> args = const <String>[],
    Map<String, String> env = const <String, String>{},
    String? workingDirectory,
  }) async {
    final id = const Uuid().v4();
    final cfg = McpServerConfig(
      id: id,
      enabled: enabled,
      name: name.trim().isEmpty ? 'MCP' : name.trim(),
      transport: transport,
      url: url.trim(),
      headers: headers,
      command: command?.trim(),
      args: args,
      env: env,
      workingDirectory: (workingDirectory?.trim().isNotEmpty ?? false)
          ? workingDirectory!.trim()
          : null,
    );
    return _runPortableServerWrite(
      keys: _isPortable(cfg)
          ? <SyncEntityKey>[ConfigSyncKeys.mcpServer(id)]
          : const <SyncEntityKey>[],
      write: () async {
        _servers = [..._servers, cfg];
        _status[id] = McpStatus.idle;
        await _persist();
        notifyListeners();
        if (enabled) {
          unawaited(connect(id));
        }
        return id;
      },
    );
  }

  Future<void> updateServer(McpServerConfig updated) async {
    final idx = _servers.indexWhere((e) => e.id == updated.id);
    if (idx < 0) return;
    final current = _servers[idx];
    await _runPortableServerWrite(
      keys: _portableServerKeys(extraServers: <McpServerConfig>[updated]).where(
        (key) =>
            key.entityId == updated.id ||
            (_isPortable(current) && key.entityId == current.id),
      ),
      write: () async {
        _servers = List<McpServerConfig>.of(_servers)..[idx] = updated;
        await _persist();
        notifyListeners();
        if (!updated.enabled) {
          // The disabled state is already persisted. Tear down the old
          // connection in the background so settings UI does not wait on a
          // remote session DELETE or a connection attempt finishing.
          unawaited(disconnect(updated.id));
        } else {
          await disconnect(updated.id);
          unawaited(connect(updated.id));
        }
      },
    );
  }

  Future<void> removeServer(String id) async {
    if (!_servers.any((server) => server.id == id)) return;
    await _runPortableServerWrite(
      keys: _portableServerKeys(),
      write: () async {
        await disconnect(id);
        _servers = _servers
            .where((server) => server.id != id)
            .toList(growable: false);
        _status.remove(id);
        await _persist();
        notifyListeners();
      },
    );
  }

  Future<void> syncUpsertServer(
    McpServerConfig server, {
    required int position,
  }) async {
    await ready;
    _disconnectClientWithoutNotification(server.id);
    final servers = List<McpServerConfig>.from(_servers)
      ..removeWhere((e) => e.id == server.id);
    servers.insert(position.clamp(0, servers.length), server);
    _servers = servers;
    _status[server.id] = McpStatus.idle;
    _errors.remove(server.id);
    await _persist();
    notifyListeners();
    if (server.enabled) {
      unawaited(Future<void>.delayed(Duration.zero, () => connect(server.id)));
    }
  }

  Future<void> syncDeleteServer(String id) async {
    await ready;
    if (!_servers.any((e) => e.id == id)) return;
    _disconnectClientWithoutNotification(id);
    _servers = _servers.where((e) => e.id != id).toList(growable: false);
    _status.remove(id);
    _errors.remove(id);
    await _persist();
    notifyListeners();
  }

  void _disconnectClientWithoutNotification(String id) {
    final state = _connections.remove(id);
    final client = state?.client;
    try {
      client?.disconnect();
    } catch (_) {}
    _status[id] = McpStatus.idle;
    _errors.remove(id);
    _stopHeartbeat(id);
  }

  Future<void> reorderServers(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;
    if (oldIndex < 0 || oldIndex >= _servers.length) return;
    if (newIndex < 0 || newIndex >= _servers.length) return;
    await _runPortableServerWrite(
      keys: _portableServerKeys(),
      write: () async {
        final moved = _servers.removeAt(oldIndex);
        _servers.insert(newIndex, moved);
        notifyListeners();
        await _persist();
      },
    );
  }

  Future<void> setToolEnabled(
    String serverId,
    String toolName,
    bool enabled,
  ) async {
    final idx = _servers.indexWhere((e) => e.id == serverId);
    if (idx < 0) return;
    final server = _servers[idx];
    await _runPortableServerWrite(
      keys: _isPortable(server)
          ? <SyncEntityKey>[ConfigSyncKeys.mcpServer(serverId)]
          : const <SyncEntityKey>[],
      write: () async {
        final tools = server.tools
            .map(
              (tool) => tool.name == toolName
                  ? tool.copyWith(enabled: enabled)
                  : tool,
            )
            .toList();
        _servers[idx] = server.copyWith(tools: tools);
        await _persist();
        notifyListeners();
      },
    );
  }

  /// Set whether a tool requires user approval before execution.
  Future<void> setToolNeedsApproval(
    String serverId,
    String toolName,
    bool needsApproval,
  ) async {
    final idx = _servers.indexWhere((e) => e.id == serverId);
    if (idx < 0) return;
    final server = _servers[idx];
    await _runPortableServerWrite(
      keys: _isPortable(server)
          ? <SyncEntityKey>[ConfigSyncKeys.mcpServer(serverId)]
          : const <SyncEntityKey>[],
      write: () async {
        final tools = server.tools
            .map(
              (tool) => tool.name == toolName
                  ? tool.copyWith(needsApproval: needsApproval)
                  : tool,
            )
            .toList();
        _servers[idx] = server.copyWith(tools: tools);
        await _persist();
        notifyListeners();
      },
    );
  }

  /// Check if a tool (by name) requires approval across all connected servers.
  /// Conservative: returns true if ANY connected server marks the tool as needing approval.
  bool toolNeedsApproval(String toolName) {
    for (final s in _servers) {
      if (statusFor(s.id) != McpStatus.connected) continue;
      if (!s.enabled) continue;
      for (final t in s.tools) {
        if (t.name == toolName && t.enabled && t.needsApproval) return true;
      }
    }
    return false;
  }

  Future<void> connect(String id) async {
    await _connect(id);
  }

  Future<bool> _connect(String id) {
    final server = _servers.firstWhere(
      (e) => e.id == id,
      orElse: () => throw StateError('Server not found'),
    );
    if (!server.enabled || _disposed) {
      return Future<bool>.value(false);
    }
    final state = _connections.putIfAbsent(id, _ServerConnection.new);
    final active = state.connectFuture;
    if (active != null) return active;
    if (_activeCooldown(state) != null) return Future<bool>.value(false);
    if (state.client?.isConnected == true) {
      // Reuse the live remote session; just re-verify tool availability.
      _status[id] = McpStatus.connected;
      _errors.remove(id);
      notifyListeners();
      unawaited(refreshTools(id));
      return Future<bool>.value(true);
    }
    return _beginConnect(id, server, state);
  }

  Future<bool> _beginConnect(
    String id,
    McpServerConfig server,
    _ServerConnection state, {
    Future<bool>? waitFor,
  }) {
    _status[id] = McpStatus.connecting;
    _errors.remove(id);
    final generation = state.generation;
    notifyListeners();
    late final Future<bool> future;
    future =
        (() async {
          if (waitFor != null) {
            try {
              await waitFor;
            } catch (_) {}
          }
          if (_disposed ||
              state.generation != generation ||
              _servers.any((s) => s.id == id && !s.enabled)) {
            return false;
          }
          return _performConnect(id, server, state, generation);
        })().whenComplete(() {
          if (identical(state.connectFuture, future)) {
            state.connectFuture = null;
          }
        });
    state.connectFuture = future;
    return future.then((connected) {
      if (connected && !_disposed) unawaited(refreshTools(id));
      return connected;
    });
  }

  Future<bool> _performConnect(
    String id,
    McpServerConfig server,
    _ServerConnection state,
    int generation,
  ) async {
    mcp.Client? client;
    final startedAt = DateTime.now();
    try {
      final clientConfig = mcp.McpClient.simpleConfig(
        name: 'Kelivo MCP',
        version: '1.0.0',
        // Turn on library-internal verbose logs
        enableDebugLogging: false,
        requestTimeout: _requestTimeout,
      );

      if (server.transport == McpTransportType.inmemory) {
        final engine = KelivoFetchMcpServerEngine();
        final transport = KelivoInMemoryClientTransport(engine);
        client = mcp.McpClient.createClient(clientConfig);
        await client.connect(transport);
      } else {
        final mergedHeaders = <String, String>{...server.headers};
        final transportConfig = await () async {
          if (server.transport == McpTransportType.sse) {
            return mcp.TransportConfig.sse(
              serverUrl: server.url,
              headers: mergedHeaders.isEmpty ? null : mergedHeaders,
            );
          } else if (server.transport == McpTransportType.http) {
            return mcp.TransportConfig.streamableHttp(
              baseUrl: server.url,
              headers: mergedHeaders.isEmpty ? null : mergedHeaders,
              timeout: _requestTimeout,
            );
          } else {
            // STDIO; only supported on desktop
            if (!_isDesktopPlatform()) {
              throw StateError(
                'STDIO transport not supported on this platform',
              );
            }
            final cmd = server.command;
            if (cmd == null || cmd.isEmpty) {
              throw StateError('STDIO command is empty');
            }
            final mergedEnv = await _stdioCommandResolver
                .resolveEnvironmentWithPath(server.env);
            final commandExists = await _stdioCommandResolver.commandExists(
              cmd,
              mergedEnv,
            );
            if (!commandExists) {
              throw StateError(
                'Command "$cmd" not found in PATH. '
                'Ensure the command is installed and accessible.',
              );
            }
            return mcp.TransportConfig.stdio(
              command: cmd,
              arguments: server.args,
              workingDirectory: server.workingDirectory,
              environment: mergedEnv.isEmpty ? null : mergedEnv,
            );
          }
        }();

        final clientResult = await mcp.McpClient.createAndConnect(
          config: clientConfig,
          transportConfig: transportConfig,
        );

        client = clientResult.fold((c) => c, (err) => throw err);
      }

      final connectedClient = client;
      if (connectedClient == null) {
        throw StateError('client_connect_failed');
      }
      if (_disposed ||
          state.generation != generation ||
          _servers.any((s) => s.id == id && !s.enabled)) {
        await connectedClient.terminateSession();
        connectedClient.dispose();
        return false;
      }
      state.client = connectedClient;
      _status[id] = McpStatus.connected;
      _errors.remove(id);
      _clearCooldownAfterSuccess(state, startedAt);
      _attachClient(id, state, connectedClient, generation);
      notifyListeners();

      // Start/refresh heartbeat for this connection
      _startHeartbeat(id);
      return true;
    } catch (error) {
      client?.dispose();
      if (_disposed || state.generation != generation) return false;
      if (error is mcp.McpHttpError && _requiresCooldown(error)) {
        _enterCooldown(state, error.retryAfter);
      } else if (error is mcp.McpHttpError &&
          (error.statusCode == 401 || error.statusCode == 403)) {
        _enterCooldown(state, const Duration(minutes: 5));
      }
      _status[id] = McpStatus.error;
      _errors[id] = error.toString();
      notifyListeners();
      return false;
    }
  }

  void _attachClient(
    String id,
    _ServerConnection state,
    mcp.Client client,
    int generation,
  ) {
    client.onDisconnect.listen((_) {
      if (_disposed ||
          state.generation != generation ||
          !identical(state.client, client)) {
        return;
      }
      state.client = null;
      _status[id] = McpStatus.idle;
      _errors.remove(id);
      notifyListeners();
    });
    client.onError.listen((error) {
      if (_disposed ||
          state.generation != generation ||
          !identical(state.client, client)) {
        return;
      }
      if (error is mcp.McpHttpError &&
          error.isBackgroundRequest &&
          error.statusCode == 404 &&
          error.sessionIdPresent) {
        unawaited(_recoverExpiredSession(id, state, client));
      } else if (error is mcp.McpHttpError && _requiresCooldown(error)) {
        _enterCooldown(state, error.retryAfter);
        notifyListeners();
      } else if (error is mcp.McpHttpError &&
          (error.statusCode == 401 || error.statusCode == 403)) {
        _enterCooldown(state, const Duration(minutes: 5));
        notifyListeners();
      }
    });
    client.onToolsListChanged(() {
      if (_disposed ||
          state.generation != generation ||
          !identical(state.client, client)) {
        return;
      }
      unawaited(refreshTools(id));
    });
  }

  _Cooldown? _activeCooldown(_ServerConnection? state) {
    final cooldown = state?.cooldown;
    if (cooldown == null) return null;
    final now = DateTime.now();
    if (now.isAfter(cooldown.until)) {
      state!.cooldown = null;
      return null;
    }
    return cooldown;
  }

  bool isInCooldown(String id) => _activeCooldown(_connections[id]) != null;

  bool _requiresCooldown(mcp.McpHttpError error) {
    if (error.statusCode == 429 || error.statusCode == 503) return true;
    if (error.retryAfter != null) return true;
    return false;
  }

  void _enterCooldown(_ServerConnection state, Duration? retryAfter) {
    final now = DateTime.now();
    final until = now.add(retryAfter ?? const Duration(seconds: 30));
    state.cooldown = _Cooldown(startedAt: now, until: until);
  }

  void _clearCooldownAfterSuccess(_ServerConnection state, DateTime startedAt) {
    final cooldown = state.cooldown;
    if (cooldown == null) return;
    if (!cooldown.startedAt.isAfter(startedAt)) {
      state.cooldown = null;
    }
  }

  Future<mcp.Client?> _recoverExpiredSession(
    String id,
    _ServerConnection state,
    mcp.Client failedClient,
  ) async {
    if (_disposed || _servers.any((s) => s.id == id && !s.enabled)) {
      return null;
    }
    if (!identical(state.client, failedClient)) {
      final active = state.connectFuture;
      if (active != null) {
        try {
          await active;
        } catch (_) {}
      }
      final current = state.client;
      return current?.isConnected == true ? current : null;
    }

    final previousConnect = state.connectFuture;
    state.generation++;
    state.client = null;
    _status[id] = McpStatus.connecting;
    _errors.remove(id);
    state.cooldown = null;

    final server = _servers.firstWhere(
      (e) => e.id == id,
      orElse: () => throw StateError('Server not found'),
    );
    if (!server.enabled || _disposed) {
      failedClient.dispose();
      return null;
    }
    try {
      final connected = await _beginConnect(
        id,
        server,
        state,
        waitFor: previousConnect,
      );
      await failedClient.waitForPendingRequests();
      return connected ? state.client : null;
    } finally {
      failedClient.dispose();
    }
  }

  Future<void> updateRequestTimeout(
    Duration duration, {
    bool reconnectActive = true,
  }) async {
    if (duration.inMilliseconds <= 0) return;
    if (duration == _requestTimeout) return;
    await _syncWrites.runLocal(
      key: ConfigSyncKeys.mcpState,
      write: () =>
          _updateRequestTimeout(duration, reconnectActive: reconnectActive),
    );
  }

  Future<void> syncUpdateRequestTimeout(Duration duration) async {
    if (duration.inMilliseconds <= 0) return;
    if (duration == _requestTimeout) return;
    await _updateRequestTimeout(duration, reconnectActive: false);
  }

  Future<void> _updateRequestTimeout(
    Duration duration, {
    required bool reconnectActive,
  }) async {
    _requestTimeout = duration;
    await _persistTimeout();
    notifyListeners();
    if (!reconnectActive) return;
    for (final id in _connections.keys.toList()) {
      if (_servers.any((server) => server.id == id && server.enabled)) {
        unawaited(reconnect(id));
      }
    }
  }

  Future<void> disconnect(String id, {bool terminateSession = true}) async {
    final state = _connections.putIfAbsent(id, _ServerConnection.new);
    state.generation++;
    final active = state.connectFuture;
    final client = state.client;
    state.client = null;
    state.cooldown = null;
    state.refreshDirty = false;
    _status[id] = McpStatus.idle;
    _errors.remove(id);
    _stopHeartbeat(id);
    notifyListeners();

    if (active != null) {
      try {
        await active;
      } catch (_) {}
    }
    try {
      if (terminateSession) {
        await client?.terminateSession();
      }
      client?.dispose();
    } catch (_) {}
  }

  Future<bool> reconnect(String id) async {
    if (_activeCooldown(_connections[id]) != null) return false;
    await disconnect(id, terminateSession: true);
    return _connect(id);
  }

  Future<void> _reconnectWithBackoff(String id, {int maxAttempts = 3}) async {
    if (_reconnecting.contains(id)) return;
    _reconnecting.add(id);
    try {
      for (int attempt = 1; attempt <= maxAttempts; attempt++) {
        await reconnect(id);
        if (isConnected(id)) return;
        // progressive backoff: 600ms, 1200ms, 2400ms
        final delayMs = 600 * (1 << (attempt - 1));
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    } finally {
      _reconnecting.remove(id);
    }
  }

  void _startHeartbeat(
    String id, {
    Duration interval = const Duration(seconds: 12),
  }) {
    _stopHeartbeat(id);
    _heartbeats[id] = Timer.periodic(interval, (t) async {
      // Heartbeat only when we think we're connected
      if (!isConnected(id)) return;
      final client = _connections[id]?.client;
      if (client == null) return;
      try {
        // A lightweight call to verify liveness
        // listTools is relatively cheap and available
        final fut = client.listTools();
        // Add a soft timeout to avoid piling up
        await fut.timeout(const Duration(seconds: 6));
      } catch (e) {
        // Consider connection lost; mark error and try auto-reconnect
        _status[id] = McpStatus.error;
        _errors[id] = e.toString();
        notifyListeners();
        await _reconnectWithBackoff(id, maxAttempts: 3);
        // If reconnected, restart heartbeat (connect() also starts it)
        if (!isConnected(id)) {
          // keep error state; next heartbeat tick will be a no-op
        }
      }
    });
  }

  void _stopHeartbeat(String id) {
    _heartbeats.remove(id)?.cancel();
  }

  McpToolConfig? _toolConfig(String serverId, String toolName) {
    final idx = _servers.indexWhere((e) => e.id == serverId);
    if (idx < 0) return null;
    final s = _servers[idx];
    for (final t in s.tools) {
      if (t.name == toolName) return t;
    }
    return null;
  }

  Map<String, dynamic> _normalizeArgsForTool(
    String serverId,
    String toolName,
    Map<String, dynamic> args,
  ) {
    try {
      final cfg = _toolConfig(serverId, toolName);
      final schema = cfg?.schema;
      if (schema == null || schema.isEmpty) return args;
      final cloned = jsonDecode(jsonEncode(args)) as Map<String, dynamic>;
      var normalized = _normalizeBySchema(cloned, schema, propertyName: null);
      if (normalized is! Map<String, dynamic>) return args;
      normalized = _normalizeSpecialCases(toolName, normalized);
      return normalized;
    } catch (_) {
      return args;
    }
  }

  Map<String, dynamic> _normalizeSpecialCases(
    String toolName,
    Map<String, dynamic> args,
  ) {
    try {
      if (toolName == 'firecrawl_search') {
        // sources: ["web"] -> [{"type":"web"}]
        final rawSources = args['sources'];
        if (rawSources is List &&
            rawSources.isNotEmpty &&
            rawSources.every((e) => e is String)) {
          args['sources'] = rawSources.map((e) => {'type': e}).toList();
        }
        // Provide pragmatic defaults for commonly required fields if absent
        args.putIfAbsent('tbs', () => '0');
        args.putIfAbsent('filter', () => '0');
        args.putIfAbsent('location', () => 'us');
        // If tbs/filter are present but empty, coerce to '0'
        if ((args['tbs'] is String) && (args['tbs'] as String).isEmpty) {
          args['tbs'] = '0';
        }
        if ((args['filter'] is String) && (args['filter'] as String).isEmpty) {
          args['filter'] = '0';
        }
        if ((args['location'] is String) &&
            (args['location'] as String).toLowerCase() == 'global') {
          args['location'] = 'us';
        }
        final so = (args['scrapeOptions'] is Map)
            ? (args['scrapeOptions'] as Map).cast<String, dynamic>()
            : <String, dynamic>{};
        so.putIfAbsent('waitFor', () => 0);
        // formats normalization: server expects union of simple literals ["markdown"|"html"|"rawHtml"] OR an object only when type=="json"
        final fm = so['formats'];
        if (fm is List) {
          final norm = <dynamic>[];
          for (final f in fm) {
            if (f is Map) {
              final t = (f['type'] ?? '').toString();
              if (t == 'markdown' || t == 'html' || t == 'rawHtml') {
                norm.add(t);
              } else if (t == 'json') {
                norm.add(f); // keep object form for json
              } else if (t.isNotEmpty) {
                norm.add(t);
              }
            } else if (f is String) {
              if (f == 'json') {
                norm.add({'type': 'json'});
              } else {
                norm.add(f);
              }
            } else {
              norm.add(f);
            }
          }
          so['formats'] = norm;
        }
        args['scrapeOptions'] = so;
      }
    } catch (_) {}
    return args;
  }

  dynamic _normalizeBySchema(
    dynamic value,
    Map<String, dynamic> schema, {
    String? propertyName,
  }) {
    try {
      // Handle anyOf/oneOf by choosing first matching branch; if value is null, attempt defaults
      final List<Map<String, dynamic>> unions = _schemaUnions(schema);
      if (unions.isNotEmpty) {
        // Heuristic only for certain fields (e.g., sources) — DO NOT apply globally.
        if (value is String && propertyName == 'sources') {
          final objBranch = unions.firstWhere(
            (m) =>
                _schemaTypes(m).contains('object') &&
                ((m['properties'] as Map?)?.containsKey('type') ?? false),
            orElse: () => const {},
          );
          if (objBranch.isNotEmpty) {
            return _normalizeBySchema(
              {'type': value},
              objBranch,
              propertyName: propertyName,
            );
          }
        }
        for (final branch in unions) {
          try {
            return _normalizeBySchema(
              value,
              branch,
              propertyName: propertyName,
            );
          } catch (_) {
            // try next branch
          }
        }
        // fallthrough to first branch
        return _normalizeBySchema(
          value,
          unions.first,
          propertyName: propertyName,
        );
      }

      final declaredTypes = _schemaTypes(schema);
      if (declaredTypes.contains('object')) {
        final props =
            (schema['properties'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
        final req =
            (schema['required'] as List?)?.map((e) => e.toString()).toSet() ??
            const <String>{};
        final out = <String, dynamic>{};
        final input = (value is Map)
            ? value.cast<String, dynamic>()
            : const <String, dynamic>{};
        // copy passthrough unknowns
        input.forEach((k, v) {
          if (!props.containsKey(k)) out[k] = v;
        });
        for (final entry in props.entries) {
          final key = entry.key;
          final propSchema = (entry.value is Map)
              ? (entry.value as Map).cast<String, dynamic>()
              : const <String, dynamic>{};
          dynamic v = input.containsKey(key) ? input[key] : null;
          if (v == null) {
            if (propSchema.containsKey('default')) {
              v = propSchema['default'];
            } else if (req.contains(key)) {
              // Only synthesize enum / waitFor defaults for required fields; optional
              // omitted keys should stay absent (do not pick enum.first).
              final enumVals = _schemaEnum(propSchema);
              if (enumVals.isNotEmpty) {
                v = enumVals.first;
              } else if (key == 'waitFor' &&
                  _schemaTypes(
                    propSchema,
                  ).any((t) => t == 'number' || t == 'integer')) {
                v = 0; // pragmatic default often acceptable for waitFor
              }
            }
          }
          if (v != null) {
            out[key] = _normalizeBySchema(v, propSchema, propertyName: key);
          } else if (!req.contains(key)) {
            // omit optional nulls
          } else {
            // keep as null for required to let server validate if still missing
          }
        }
        return out;
      }

      if (declaredTypes.contains('array')) {
        final items =
            (schema['items'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
        final list = (value is List) ? value : [value];
        final out = [];
        for (final item in list) {
          dynamic iv = item;
          // Heuristic only for sources array, not for other arrays like formats
          final itemTypes = _schemaTypes(items);
          if (propertyName == 'sources' &&
              item is String &&
              itemTypes.contains('object')) {
            final itemProps =
                (items['properties'] as Map?)?.cast<String, dynamic>() ??
                const <String, dynamic>{};
            if (itemProps.containsKey('type')) {
              iv = {'type': item};
            }
          }
          out.add(_normalizeBySchema(iv, items, propertyName: propertyName));
        }
        return out;
      }

      if (declaredTypes.contains('boolean')) {
        if (value is bool) return value;
        if (value is String) {
          final s = value.toLowerCase();
          if (s == 'true' || s == '1' || s == 'yes') return true;
          if (s == 'false' || s == '0' || s == 'no') return false;
        }
        return value;
      }

      if (declaredTypes.contains('integer')) {
        if (value is int) return value;
        if (value is num) return value.toInt();
        if (value is String) {
          final p = int.tryParse(value);
          if (p != null) return p;
        }
        return value;
      }

      if (declaredTypes.contains('number')) {
        if (value is num) return value;
        if (value is String) {
          final p = double.tryParse(value);
          if (p != null) return p;
        }
        return value;
      }

      if (declaredTypes.contains('string')) {
        if (value == null) return value;
        if (value is String) {
          final enums = _schemaEnum(schema);
          if (enums.isNotEmpty && !enums.contains(value)) {
            // keep original; server will validate
          }
          return value;
        }
        return value.toString();
      }

      // no declared type: return as-is
      return value;
    } catch (_) {
      return value;
    }
  }

  List<Map<String, dynamic>> _schemaUnions(Map<String, dynamic> schema) {
    final out = <Map<String, dynamic>>[];
    final anyOf = schema['anyOf'];
    final oneOf = schema['oneOf'];
    if (anyOf is List) {
      out.addAll(anyOf.whereType<Map>().map((e) => e.cast<String, dynamic>()));
    }
    if (oneOf is List) {
      out.addAll(oneOf.whereType<Map>().map((e) => e.cast<String, dynamic>()));
    }
    return out;
  }

  List<String> _schemaTypes(Map<String, dynamic> schema) {
    final t = schema['type'];
    if (t is String) return [t];
    if (t is List) return t.map((e) => e.toString()).toList();
    return const [];
  }

  List<dynamic> _schemaEnum(Map<String, dynamic> schema) {
    final e = schema['enum'];
    if (e is List) return e;
    return const [];
  }

  Future<void> refreshTools(String id) async {
    final state = _connections[id];
    final client = state?.client;
    if (client == null) return;
    state!.refreshDirty = true;
    final active = state.refreshFuture;
    if (active != null) return;
    final future = _drainToolRefresh(id, state);
    state.refreshFuture = future;
    await future.whenComplete(() {
      if (!identical(state.refreshFuture, future)) return;
      state.refreshFuture = null;
      if (state.refreshDirty && !_disposed) {
        unawaited(refreshTools(id));
      }
    });
  }

  Future<void> _drainToolRefresh(String id, _ServerConnection state) async {
    var sessionRecoveries = 0;
    while (state.refreshDirty && !_disposed) {
      state.refreshDirty = false;
      final failedClient = state.client;
      final outcome = await _refreshToolsOnce(id, state);
      if (outcome == _ToolRefreshOutcome.sessionExpired &&
          sessionRecoveries++ == 0 &&
          failedClient != null &&
          await _recoverExpiredSession(id, state, failedClient) != null) {
        state.refreshDirty = true;
        continue;
      }
      if (outcome != _ToolRefreshOutcome.success) return;
    }
  }

  bool _isRejectedSession(Object error) =>
      error is mcp.McpHttpError &&
      error.statusCode == 404 &&
      error.sessionIdPresent &&
      error.canRetryRequest;

  Future<_ToolRefreshOutcome> _refreshToolsOnce(
    String id,
    _ServerConnection state,
  ) async {
    final client = state.client;
    if (client == null) return _ToolRefreshOutcome.failed;
    final generation = state.generation;
    final List<mcp.Tool> tools;
    try {
      tools = await client.listTools();
    } catch (error) {
      if (_disposed || state.generation != generation) {
        return _ToolRefreshOutcome.failed;
      }
      if (_isRejectedSession(error)) return _ToolRefreshOutcome.sessionExpired;
      if (error is mcp.McpHttpError && _requiresCooldown(error)) {
        _enterCooldown(state, error.retryAfter);
      }
      _status[id] = McpStatus.error;
      _errors[id] = error.toString();
      notifyListeners();
      return _ToolRefreshOutcome.failed;
    }
    if (_disposed ||
        state.generation != generation ||
        !identical(state.client, client)) {
      return _ToolRefreshOutcome.failed;
    }

    final idx = _servers.indexWhere((server) => server.id == id);
    if (idx < 0) return _ToolRefreshOutcome.failed;
    final server = _servers[idx];
    final existingMap = <String, McpToolConfig>{
      for (final tool in server.tools) tool.name: tool,
    };
    final merged = <McpToolConfig>[];
    for (final tool in tools) {
      final prior = existingMap[tool.name];
      final params = <McpParamSpec>[];
      Map<String, dynamic>? schemaJson;
      try {
        final schema = tool.inputSchema;
        schemaJson = schema;
        final properties =
            (schema['properties'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
        final requiredNames =
            (schema['required'] as List?)
                ?.map((value) => value.toString())
                .toSet() ??
            const <String>{};
        properties.forEach((name, value) {
          String? type;
          dynamic defaultValue;
          try {
            final specification = (value as Map).cast<String, dynamic>();
            final rawType = specification['type'];
            if (rawType is String) {
              type = rawType;
            } else if (rawType is List) {
              type = rawType.map((entry) => entry.toString()).join('|');
            }
            defaultValue = specification['default'];
          } catch (_) {}
          params.add(
            McpParamSpec(
              name: name,
              required: requiredNames.contains(name),
              type: type,
              defaultValue: defaultValue,
            ),
          );
        });
      } catch (_) {}

      merged.add(
        McpToolConfig(
          enabled: prior?.enabled ?? true,
          name: tool.name,
          description: tool.description,
          params: params,
          schema: schemaJson,
          needsApproval: prior?.needsApproval ?? false,
        ),
      );
    }

    final previousJson = jsonEncode(
      server.tools.map((tool) => tool.toJson()).toList(growable: false),
    );
    final nextJson = jsonEncode(
      merged.map((tool) => tool.toJson()).toList(growable: false),
    );
    if (previousJson == nextJson) return _ToolRefreshOutcome.success;

    await _runPortableServerWrite(
      keys: _isPortable(server)
          ? <SyncEntityKey>[ConfigSyncKeys.mcpServer(id)]
          : const <SyncEntityKey>[],
      write: () async {
        final currentIndex = _servers.indexWhere((current) => current.id == id);
        if (currentIndex < 0) return;
        _servers[currentIndex] = _servers[currentIndex].copyWith(tools: merged);
        await _persist();
        notifyListeners();
      },
    );
    return _ToolRefreshOutcome.success;
  }

  Future<void> ensureConnected(String id) async {
    // Do not attempt to connect if the server is disabled
    final cfg = getById(id);
    if (cfg == null || !cfg.enabled) return;
    if (isConnected(id)) return;
    // Try a few times with short backoff in case server blips
    await _reconnectWithBackoff(id, maxAttempts: 3);
  }

  Future<mcp.CallToolResult?> callTool(
    String serverId,
    String toolName,
    Map<String, dynamic> args,
  ) async {
    try {
      await ensureConnected(serverId);
      var client = _connections[serverId]?.client;
      if (client == null) return null;
      // Normalize arguments based on tool schema (best-effort)
      final normalized = _normalizeArgsForTool(serverId, toolName, args);
      final result = await client.callTool(toolName, normalized);
      // Detailed call timing/content logging disabled
      return result;
    } catch (e) {
      // If this is a parameter validation error from the server, do NOT disconnect.
      try {
        if (e is mcp.McpError && (e.code == -32602)) {
          // Keep connection healthy status; surface error to caller via null
          _errors[serverId] = e.toString();
          return null;
        }
      } catch (_) {}

      _status[serverId] = McpStatus.error;
      _errors[serverId] = e.toString();
      notifyListeners();
      // Auto-reconnect a few times and try once more
      try {
        await _reconnectWithBackoff(serverId, maxAttempts: 3);
        if (!isConnected(serverId)) return null;
        final client = _connections[serverId]?.client;
        if (client == null) return null;
        final normalized = _normalizeArgsForTool(serverId, toolName, args);
        final result = await client.callTool(toolName, normalized);
        // Detailed retry logging disabled
        // Mark healthy again
        _status[serverId] = McpStatus.connected;
        _errors.remove(serverId);
        notifyListeners();
        return result;
      } catch (_) {
        // Keep error state; give up
        return null;
      }
    }
  }

  List<McpToolConfig> getEnabledToolsForServers(Set<String> serverIds) {
    // Only expose tools for servers that are both selected AND currently connected
    final tools = <McpToolConfig>[];
    for (final s in _servers.where((s) => serverIds.contains(s.id))) {
      if (statusFor(s.id) != McpStatus.connected) continue;
      if (!s.enabled) continue;
      tools.addAll(s.tools.where((t) => t.enabled));
    }
    return tools;
  }

  @override
  void dispose() {
    _disposed = true;
    // Clean up timers
    for (final t in _heartbeats.values) {
      t.cancel();
    }
    _heartbeats.clear();
    for (final state in _connections.values) {
      try {
        state.client?.dispose();
      } catch (_) {}
    }
    _connections.clear();
    super.dispose();
  }

  bool _isDesktopPlatform() {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }
}
