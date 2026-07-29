import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../utils/app_directories.dart';
import '../../database/database_encryption_cutover.dart';
import '../backup/restore_business_lease.dart';
import '../backup/restore_durability.dart';
import '../sync/cloud_sync_state_retirement.dart';
import '../sync/cloud_sync_types.dart';
import 'account_session_token_store.dart';

final class AccountWorkspaceContext {
  const AccountWorkspaceContext._({
    required this.workspaceKey,
    required this.dataDirectory,
    required this.preferencesPrefix,
    required this.accountScope,
    required this.session,
  });

  final String workspaceKey;
  final Directory dataDirectory;
  final String preferencesPrefix;
  final String? accountScope;
  final CloudSyncAccountSession? session;

  bool get isLocal => accountScope == null;

  AccountWorkspaceContext _withSession(CloudSyncAccountSession value) {
    return AccountWorkspaceContext._(
      workspaceKey: workspaceKey,
      dataDirectory: dataDirectory,
      preferencesPrefix: preferencesPrefix,
      accountScope: accountScope,
      session: value,
    );
  }

  AccountWorkspaceContext _withoutSession() {
    return AccountWorkspaceContext._(
      workspaceKey: workspaceKey,
      dataDirectory: dataDirectory,
      preferencesPrefix: preferencesPrefix,
      accountScope: accountScope,
      session: null,
    );
  }
}

sealed class AccountWorkspaceBindResult {
  const AccountWorkspaceBindResult(this.target);

  final AccountWorkspaceContext target;
}

final class AccountWorkspaceRetained extends AccountWorkspaceBindResult {
  const AccountWorkspaceRetained(super.target);
}

final class AccountWorkspaceRestartRequired extends AccountWorkspaceBindResult {
  const AccountWorkspaceRestartRequired(super.target);
}

final class AccountWorkspaceRuntime {
  AccountWorkspaceRuntime._(
    this.installationRoot,
    this._workspaceRoot,
    this._canonicalWorkspaceRoot,
    this._localDataDirectory,
    this._lease,
    this._durability,
    this._sessionTokenStore,
    this._current,
    this._registryGeneration,
    this._registrySlot,
    this._pendingTokenCleanup,
  );

  static const _workspaceDirectoryName = '.kelivo-workspaces';
  static const _localDirectoryName = 'local';
  static const _accountsDirectoryName = 'accounts';
  static const _dataDirectoryName = 'data';
  static const _localWorkspaceKey = 'local';
  static const _registryRecordName = 'registry-v1';
  static const _legacySessionRecordName = 'session-v1';
  static const _sessionRecordName = 'session-v2';
  static const _localPreferencesPrefix = 'flutter.';
  static const _accountPreferencesPrefix = 'kelivo.account.';

  final Directory installationRoot;
  final Directory _workspaceRoot;
  final String _canonicalWorkspaceRoot;
  final Directory _localDataDirectory;
  final RestoreBusinessLease _lease;
  final RestoreDurability _durability;
  final AccountSessionTokenStore _sessionTokenStore;
  AccountWorkspaceContext _current;
  int _registryGeneration;
  String? _registrySlot;
  // 活动账号指针清除后，只能依靠注册表队列跨进程定位待清理令牌。
  final Set<String> _pendingTokenCleanup;
  bool _closed = false;

  AccountWorkspaceContext get current => _current;

  Future<void> discardPlaintextLocalState() async {
    _requireOpen();
    final dataDirectories = await _existingDataDirectories();
    // 所有工作区必须先通过拓扑校验，避免后发现歧义时只清掉一部分旧状态。
    for (final dataDirectory in dataDirectories) {
      await DatabaseEncryptionCutover.validatePlaintextStateTopology(
        appDataDirectory: dataDirectory,
      );
      await CloudSyncStateRetirement.validatePlaintextStateTopology(
        appDataDirectory: dataDirectory,
      );
    }
    for (final dataDirectory in dataDirectories) {
      await DatabaseEncryptionCutover.discardPlaintextState(
        appDataDirectory: dataDirectory,
        durability: _durability,
      );
      await CloudSyncStateRetirement.discardPlaintextState(
        appDataDirectory: dataDirectory,
        durability: _durability,
      );
    }
    await DatabaseEncryptionCutover.discardLegacyDatabaseFamily(
      appDataDirectory: installationRoot,
      durability: _durability,
    );
  }

  static Future<AccountWorkspaceRuntime> bootstrap({
    Directory? installationRoot,
    AccountSessionTokenStore? sessionTokenStore,
    DateTime Function()? utcNow,
  }) async {
    final resolvedSessionTokenStore =
        sessionTokenStore ?? const SecureAccountSessionTokenStore();
    final resolvedInstallationRoot = Directory(
      p.normalize(
        p.absolute(
          (installationRoot ??
                  await AppDirectories.getInstallationRootDirectory())
              .path,
        ),
      ),
    );
    await resolvedInstallationRoot.create(recursive: true);
    final canonicalInstallationRoot = p.normalize(
      await resolvedInstallationRoot.resolveSymbolicLinks(),
    );
    final workspaceRoot = Directory(
      p.join(resolvedInstallationRoot.path, _workspaceDirectoryName),
    );
    final canonicalWorkspaceRoot = p.normalize(
      p.join(canonicalInstallationRoot, _workspaceDirectoryName),
    );
    await _ensureOwnedDirectory(
      directory: workspaceRoot,
      expectedCanonicalPath: canonicalWorkspaceRoot,
      createMissing: true,
      errorCode: 'account_workspace_root_unsafe',
    );
    final lease = await RestoreBusinessLease.acquire(
      appDataDirectory: workspaceRoot,
    );
    final durability = RestorePlatformDurability();
    try {
      final localDataDirectory = await _ensureLocalDataDirectoryPath(
        workspaceRoot: workspaceRoot,
        canonicalWorkspaceRoot: canonicalWorkspaceRoot,
      );
      final now = (utcNow ?? DateTime.now)().toUtc();
      var registry = await _readLatestRecord(
        directory: workspaceRoot,
        recordName: _registryRecordName,
      );
      var activeWorkspaceKey = _parseRegistry(registry?.payload);
      final pendingTokenCleanup = _parsePendingTokenCleanup(registry?.payload);
      for (final workspaceKey in pendingTokenCleanup.toList()) {
        final tokensCleaned = await _retryPendingTokenCleanup(
          workspaceRoot: workspaceRoot,
          canonicalWorkspaceRoot: canonicalWorkspaceRoot,
          workspaceKey: workspaceKey,
          sessionTokenStore: resolvedSessionTokenStore,
          durability: durability,
        );
        if (tokensCleaned) {
          pendingTokenCleanup.remove(workspaceKey);
        }
      }
      late AccountWorkspaceContext current;
      if (activeWorkspaceKey == null) {
        current = _localContext(localDataDirectory);
      } else {
        final accountDirectory = await _ensureAccountDirectoryPath(
          workspaceRoot: workspaceRoot,
          canonicalWorkspaceRoot: canonicalWorkspaceRoot,
          workspaceKey: activeWorkspaceKey,
          createMissing: false,
        );
        final removedLegacy = await _deleteLegacySessionRecords(
          accountDirectory,
          durability: durability,
        );
        final hasEncryptedSession = await _hasRecordFile(
          directory: accountDirectory,
          recordName: _sessionRecordName,
        );
        if (removedLegacy && !hasEncryptedSession) {
          final tokensCleaned = await _deleteTokensAfterCommit(
            operation: 'discard-legacy-session',
            workspaceKey: activeWorkspaceKey,
            sessionTokenStore: resolvedSessionTokenStore,
            accountDirectory: accountDirectory,
            keep: null,
            durability: durability,
          );
          _recordTokenCleanupResult(
            pendingTokenCleanup,
            activeWorkspaceKey,
            tokensCleaned: tokensCleaned,
          );
          activeWorkspaceKey = null;
          registry = await _writeNextRecord(
            directory: workspaceRoot,
            recordName: _registryRecordName,
            currentGeneration: registry?.generation ?? 0,
            currentSlot: registry?.slot,
            payload: _registryPayload(
              activeWorkspaceKey: activeWorkspaceKey,
              pendingTokenCleanup: pendingTokenCleanup,
            ),
            durability: durability,
          );
          current = _localContext(localDataDirectory);
        } else {
          final accountRead = await _readAccountContext(
            workspaceRoot: workspaceRoot,
            canonicalWorkspaceRoot: canonicalWorkspaceRoot,
            workspaceKey: activeWorkspaceKey,
            sessionTokenStore: resolvedSessionTokenStore,
            durability: durability,
          );
          current = accountRead.context;
          if (accountRead.tokensCleaned) {
            pendingTokenCleanup.remove(activeWorkspaceKey);
          }
        }
      }
      final activeSession = current.session;
      if (activeWorkspaceKey != null &&
          activeSession != null &&
          (activeSession.baseUrl != defaultCloudSyncBaseUrl ||
              activeSession.isExpiredAt(now))) {
        // 不可再使用的凭证必须先由 tombstone 压过，再清除注册表选择。
        final tokensCleaned = await _writeSessionTombstone(
          workspaceRoot: workspaceRoot,
          canonicalWorkspaceRoot: canonicalWorkspaceRoot,
          workspaceKey: activeWorkspaceKey,
          accountScope: current.accountScope!,
          durability: durability,
          sessionTokenStore: resolvedSessionTokenStore,
        );
        _recordTokenCleanupResult(
          pendingTokenCleanup,
          activeWorkspaceKey,
          tokensCleaned: tokensCleaned,
        );
        current = current._withoutSession();
      }
      if (activeWorkspaceKey != null && current.session == null) {
        // tombstone 必须压过旧注册表选择，否则退出中断会把用户
        // 留在无凭证的账号工作区，且永远无法回到本地工作区。
        registry = await _writeNextRecord(
          directory: workspaceRoot,
          recordName: _registryRecordName,
          currentGeneration: registry?.generation ?? 0,
          currentSlot: registry?.slot,
          payload: _registryPayload(
            activeWorkspaceKey: null,
            pendingTokenCleanup: pendingTokenCleanup,
          ),
          durability: durability,
        );
        activeWorkspaceKey = null;
        current = _localContext(localDataDirectory);
      }
      final persistedPendingTokenCleanup = _parsePendingTokenCleanup(
        registry?.payload,
      );
      if (_parseRegistry(registry?.payload) != activeWorkspaceKey ||
          !_sameWorkspaceKeys(
            persistedPendingTokenCleanup,
            pendingTokenCleanup,
          )) {
        registry = await _writeNextRecord(
          directory: workspaceRoot,
          recordName: _registryRecordName,
          currentGeneration: registry?.generation ?? 0,
          currentSlot: registry?.slot,
          payload: _registryPayload(
            activeWorkspaceKey: activeWorkspaceKey,
            pendingTokenCleanup: pendingTokenCleanup,
          ),
          durability: durability,
        );
      }
      await current.dataDirectory.create(recursive: true);

      // SharedPreferences 的前缀必须早于首次 getInstance；否则配置会逃逸到
      // 其他账号命名空间，因此启动顺序错误必须直接失败。
      SharedPreferences.setPrefix(current.preferencesPrefix);
      final canonicalDataRoot = current.isLocal
          ? p.join(
              canonicalWorkspaceRoot,
              _localDirectoryName,
              _dataDirectoryName,
            )
          : p.join(
              canonicalWorkspaceRoot,
              _accountsDirectoryName,
              current.workspaceKey,
              _dataDirectoryName,
            );
      AppDirectories.bindWorkspaceRoot(
        current.dataDirectory,
        installationRoot: resolvedInstallationRoot,
        accountWorkspace: !current.isLocal,
        canonicalWorkspaceRoot: canonicalDataRoot,
      );

      return AccountWorkspaceRuntime._(
        resolvedInstallationRoot,
        workspaceRoot,
        canonicalWorkspaceRoot,
        localDataDirectory,
        lease,
        durability,
        resolvedSessionTokenStore,
        current,
        registry?.generation ?? 0,
        registry?.slot,
        pendingTokenCleanup,
      );
    } catch (_) {
      await lease.close();
      rethrow;
    }
  }

  Future<AccountWorkspaceBindResult> bindAccount(
    CloudSyncAccountSession session,
  ) async {
    _requireOpen();
    final scope = session.accountScope;
    final workspaceKey = _workspaceKey(scope);
    final dataDirectory = await _ensureAccountDataDirectory(
      workspaceKey,
      createAccount: true,
    );
    final target = _accountContext(
      workspaceKey: workspaceKey,
      dataDirectory: dataDirectory,
      accountScope: scope,
      session: session,
    );
    await _writeAccountRecord(
      workspaceKey: workspaceKey,
      accountScope: scope,
      session: session,
    );

    if (_current.accountScope == scope) {
      _current = _current._withSession(session);
      return AccountWorkspaceRetained(_current);
    }

    await _writeRegistry(workspaceKey);
    return AccountWorkspaceRestartRequired(target);
  }

  Future<AccountWorkspaceRestartRequired> signOut() async {
    _requireOpen();
    final scope = _current.accountScope;
    if (scope == null) {
      throw StateError('account_workspace_already_local');
    }

    // 先发布无凭证记录，再切换活动工作区。任一步骤中断都只会留下
    // 离线账号工作区，不会让已退出的凭证继续参与同步。
    await _writeAccountRecord(
      workspaceKey: _current.workspaceKey,
      accountScope: scope,
      session: null,
    );
    _current = _current._withoutSession();
    await _writeRegistry(null);
    return AccountWorkspaceRestartRequired(_localContext(_localDataDirectory));
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _lease.close();
  }

  /// 新进程只能在安装级租约明确释放后启动，避免 Windows 的
  /// CreateProcess 子进程抢在旧进程退出前进入失败页。
  Future<void> prepareRestartHandoff() => close();

  Future<void> _writeRegistry(String? workspaceKey) async {
    await _ensureOwnedDirectory(
      directory: _workspaceRoot,
      expectedCanonicalPath: _canonicalWorkspaceRoot,
      createMissing: false,
      errorCode: 'account_workspace_root_unsafe',
    );
    final next = await _writeNextRecord(
      directory: _workspaceRoot,
      recordName: _registryRecordName,
      currentGeneration: _registryGeneration,
      currentSlot: _registrySlot,
      payload: _registryPayload(
        activeWorkspaceKey: workspaceKey,
        pendingTokenCleanup: _pendingTokenCleanup,
      ),
      durability: _durability,
    );
    _registryGeneration = next.generation;
    _registrySlot = next.slot;
  }

  Future<void> _writeAccountRecord({
    required String workspaceKey,
    required String accountScope,
    required CloudSyncAccountSession? session,
  }) async {
    final accountDirectory = await _ensureAccountDirectory(
      workspaceKey,
      createMissing: true,
    );
    await _deleteLegacySessionRecords(
      accountDirectory,
      durability: _durability,
    );
    final current = await _readLatestRecord(
      directory: accountDirectory,
      recordName: _sessionRecordName,
    );
    final stored = current == null
        ? null
        : _parseStoredSession(
            current.payload,
            expectedWorkspaceKey: workspaceKey,
          );
    if (stored != null && stored.accountScope != accountScope) {
      throw const FormatException('account_workspace_scope_mismatch');
    }

    if (session == null) {
      await _writeNextRecord(
        directory: accountDirectory,
        recordName: _sessionRecordName,
        currentGeneration: current?.generation ?? 0,
        currentSlot: current?.slot,
        payload: <String, Object?>{'version': 2, 'accountScope': accountScope},
        durability: _durability,
      );
      final tokensCleaned = await _deleteTokensAfterCommit(
        operation: 'sign-out',
        workspaceKey: workspaceKey,
        sessionTokenStore: _sessionTokenStore,
        accountDirectory: accountDirectory,
        keep: null,
        durability: _durability,
      );
      _recordTokenCleanupResult(
        _pendingTokenCleanup,
        workspaceKey,
        tokensCleaned: tokensCleaned,
      );
      return;
    }

    final tokenReference = await _sessionTokenStore.writeToken(
      accountDirectory: accountDirectory,
      workspaceKey: workspaceKey,
      token: session.token.value,
      currentReference: stored?.tokenReference,
      durability: _durability,
    );
    await _writeNextRecord(
      directory: accountDirectory,
      recordName: _sessionRecordName,
      currentGeneration: current?.generation ?? 0,
      currentSlot: current?.slot,
      payload: <String, Object?>{
        'version': 2,
        'accountScope': accountScope,
        'session': session.toMetadataJson(),
        'tokenReference': tokenReference.toJson(),
      },
      durability: _durability,
    );
    final tokensCleaned = await _deleteTokensAfterCommit(
      operation: 'bind-account',
      workspaceKey: workspaceKey,
      sessionTokenStore: _sessionTokenStore,
      accountDirectory: accountDirectory,
      keep: tokenReference,
      durability: _durability,
    );
    _recordTokenCleanupResult(
      _pendingTokenCleanup,
      workspaceKey,
      tokensCleaned: tokensCleaned,
    );
  }

  static Future<bool> _deleteTokensAfterCommit({
    required String operation,
    required String workspaceKey,
    required AccountSessionTokenStore sessionTokenStore,
    required Directory accountDirectory,
    required AccountSessionTokenReference? keep,
    required RestoreDurability durability,
  }) async {
    try {
      await sessionTokenStore.deleteTokens(
        accountDirectory: accountDirectory,
        keep: keep,
        durability: durability,
      );
      return true;
    } catch (error, stackTrace) {
      developer.log(
        '账号会话已提交，令牌清理将在下次启动重试：$operation:$workspaceKey',
        name: 'Kelivo.AccountWorkspaceRuntime',
        level: 900,
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  static Future<bool> _retryPendingTokenCleanup({
    required Directory workspaceRoot,
    required String canonicalWorkspaceRoot,
    required String workspaceKey,
    required AccountSessionTokenStore sessionTokenStore,
    required RestoreDurability durability,
  }) async {
    try {
      final accountDirectory = await _ensureAccountDirectoryPath(
        workspaceRoot: workspaceRoot,
        canonicalWorkspaceRoot: canonicalWorkspaceRoot,
        workspaceKey: workspaceKey,
        createMissing: false,
      );
      final record = await _readLatestRecord(
        directory: accountDirectory,
        recordName: _sessionRecordName,
      );
      final stored = record == null
          ? null
          : _parseStoredSession(
              record.payload,
              expectedWorkspaceKey: workspaceKey,
            );
      return await _deleteTokensAfterCommit(
        operation: 'bootstrap-retry',
        workspaceKey: workspaceKey,
        sessionTokenStore: sessionTokenStore,
        accountDirectory: accountDirectory,
        keep: stored?.tokenReference,
        durability: durability,
      );
    } catch (error, stackTrace) {
      developer.log(
        '账号令牌待清理项暂时无法恢复，将在下次启动重试：$workspaceKey',
        name: 'Kelivo.AccountWorkspaceRuntime',
        level: 900,
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  static void _recordTokenCleanupResult(
    Set<String> pendingTokenCleanup,
    String workspaceKey, {
    required bool tokensCleaned,
  }) {
    if (tokensCleaned) {
      pendingTokenCleanup.remove(workspaceKey);
    } else {
      pendingTokenCleanup.add(workspaceKey);
    }
  }

  void _requireOpen() {
    if (_closed) throw StateError('account_workspace_runtime_closed');
  }

  static AccountWorkspaceContext _localContext(Directory dataDirectory) {
    return AccountWorkspaceContext._(
      workspaceKey: _localWorkspaceKey,
      dataDirectory: dataDirectory,
      preferencesPrefix: _localPreferencesPrefix,
      accountScope: null,
      session: null,
    );
  }

  static Future<({AccountWorkspaceContext context, bool tokensCleaned})>
  _readAccountContext({
    required Directory workspaceRoot,
    required String canonicalWorkspaceRoot,
    required String workspaceKey,
    required AccountSessionTokenStore sessionTokenStore,
    required RestoreDurability durability,
  }) async {
    if (!_isWorkspaceKey(workspaceKey)) {
      throw const FormatException('account_workspace_key');
    }
    final accountDirectory = await _ensureAccountDirectoryPath(
      workspaceRoot: workspaceRoot,
      canonicalWorkspaceRoot: canonicalWorkspaceRoot,
      workspaceKey: workspaceKey,
      createMissing: false,
    );
    final record = await _readLatestRecord(
      directory: accountDirectory,
      recordName: _sessionRecordName,
    );
    if (record == null) {
      throw StateError('account_workspace_session_missing');
    }
    final stored = _parseStoredSession(
      record.payload,
      expectedWorkspaceKey: workspaceKey,
    );
    final accountScope = stored.accountScope;
    final CloudSyncAccountSession? session;
    final bool tokensCleaned;
    if (stored.sessionMetadata == null) {
      tokensCleaned = await _deleteTokensAfterCommit(
        operation: 'bootstrap-tombstone',
        workspaceKey: workspaceKey,
        sessionTokenStore: sessionTokenStore,
        accountDirectory: accountDirectory,
        keep: null,
        durability: durability,
      );
      session = null;
    } else {
      final token = CloudSyncFullSessionToken.parse(
        await sessionTokenStore.readToken(
          accountDirectory: accountDirectory,
          workspaceKey: workspaceKey,
          reference: stored.tokenReference!,
        ),
      );
      session = CloudSyncAccountSession.fromMetadataJson(
        stored.sessionMetadata!,
        token: token,
      );
      if (session.accountScope != accountScope) {
        throw const FormatException('account_workspace_session_scope');
      }
      tokensCleaned = await _deleteTokensAfterCommit(
        operation: 'bootstrap-session',
        workspaceKey: workspaceKey,
        sessionTokenStore: sessionTokenStore,
        accountDirectory: accountDirectory,
        keep: stored.tokenReference!,
        durability: durability,
      );
    }
    final dataDirectory = await _ensureAccountDataDirectoryPath(
      workspaceRoot: workspaceRoot,
      canonicalWorkspaceRoot: canonicalWorkspaceRoot,
      workspaceKey: workspaceKey,
      createAccount: false,
    );
    return (
      context: _accountContext(
        workspaceKey: workspaceKey,
        dataDirectory: dataDirectory,
        accountScope: accountScope,
        session: session,
      ),
      tokensCleaned: tokensCleaned,
    );
  }

  static AccountWorkspaceContext _accountContext({
    required String workspaceKey,
    required Directory dataDirectory,
    required String accountScope,
    required CloudSyncAccountSession? session,
  }) {
    return AccountWorkspaceContext._(
      workspaceKey: workspaceKey,
      dataDirectory: dataDirectory,
      preferencesPrefix: '$_accountPreferencesPrefix$workspaceKey.',
      accountScope: accountScope,
      session: session,
    );
  }

  static Future<bool> _writeSessionTombstone({
    required Directory workspaceRoot,
    required String canonicalWorkspaceRoot,
    required String workspaceKey,
    required String accountScope,
    required RestoreDurability durability,
    required AccountSessionTokenStore sessionTokenStore,
  }) async {
    final accountDirectory = await _ensureAccountDirectoryPath(
      workspaceRoot: workspaceRoot,
      canonicalWorkspaceRoot: canonicalWorkspaceRoot,
      workspaceKey: workspaceKey,
      createMissing: false,
    );
    final current = await _readLatestRecord(
      directory: accountDirectory,
      recordName: _sessionRecordName,
    );
    if (current != null) {
      final stored = _parseStoredSession(
        current.payload,
        expectedWorkspaceKey: workspaceKey,
      );
      if (stored.accountScope != accountScope) {
        throw const FormatException('account_workspace_scope_mismatch');
      }
    }
    await _writeNextRecord(
      directory: accountDirectory,
      recordName: _sessionRecordName,
      currentGeneration: current?.generation ?? 0,
      currentSlot: current?.slot,
      payload: <String, Object?>{'version': 2, 'accountScope': accountScope},
      durability: durability,
    );
    return _deleteTokensAfterCommit(
      operation: 'invalidate-session',
      workspaceKey: workspaceKey,
      sessionTokenStore: sessionTokenStore,
      accountDirectory: accountDirectory,
      keep: null,
      durability: durability,
    );
  }

  Future<Directory> _ensureAccountDirectory(
    String workspaceKey, {
    required bool createMissing,
  }) {
    return _ensureAccountDirectoryPath(
      workspaceRoot: _workspaceRoot,
      canonicalWorkspaceRoot: _canonicalWorkspaceRoot,
      workspaceKey: workspaceKey,
      createMissing: createMissing,
    );
  }

  Future<List<Directory>> _existingDataDirectories() async {
    final canonicalInstallationRoot = p.dirname(_canonicalWorkspaceRoot);
    final legacyInstallationDirectory = await _ensureOwnedDirectory(
      directory: installationRoot,
      expectedCanonicalPath: canonicalInstallationRoot,
      createMissing: false,
      errorCode: 'account_workspace_installation_root_unsafe',
    );
    final localDataDirectory = await _ensureLocalDataDirectoryPath(
      workspaceRoot: _workspaceRoot,
      canonicalWorkspaceRoot: _canonicalWorkspaceRoot,
      createMissing: false,
    );
    final dataDirectories = <Directory>[
      legacyInstallationDirectory,
      localDataDirectory,
    ];
    final accountsDirectory = Directory(
      p.join(_workspaceRoot.path, _accountsDirectoryName),
    );
    final accountsType = await FileSystemEntity.type(
      accountsDirectory.path,
      followLinks: false,
    );
    if (accountsType == FileSystemEntityType.notFound) {
      return List<Directory>.unmodifiable(dataDirectories);
    }
    final ownedAccountsDirectory = await _ensureOwnedDirectory(
      directory: accountsDirectory,
      expectedCanonicalPath: p.join(
        _canonicalWorkspaceRoot,
        _accountsDirectoryName,
      ),
      createMissing: false,
      errorCode: 'account_workspace_accounts_unsafe',
    );
    await for (final entity in ownedAccountsDirectory.list(
      followLinks: false,
    )) {
      final entityType = await FileSystemEntity.type(
        entity.path,
        followLinks: false,
      );
      final workspaceKey = p.basename(entity.path);
      if (entityType != FileSystemEntityType.directory ||
          !_isWorkspaceKey(workspaceKey)) {
        throw StateError('account_workspace_account_entry_unsafe');
      }
      final accountDirectory = await _ensureAccountDirectoryPath(
        workspaceRoot: _workspaceRoot,
        canonicalWorkspaceRoot: _canonicalWorkspaceRoot,
        workspaceKey: workspaceKey,
        createMissing: false,
      );
      final dataDirectory = Directory(
        p.join(accountDirectory.path, _dataDirectoryName),
      );
      final dataType = await FileSystemEntity.type(
        dataDirectory.path,
        followLinks: false,
      );
      if (dataType == FileSystemEntityType.notFound) continue;
      dataDirectories.add(
        await _ensureOwnedDirectory(
          directory: dataDirectory,
          expectedCanonicalPath: p.join(
            _canonicalWorkspaceRoot,
            _accountsDirectoryName,
            workspaceKey,
            _dataDirectoryName,
          ),
          createMissing: false,
          errorCode: 'account_workspace_data_unsafe',
        ),
      );
    }
    dataDirectories.sort(
      (left, right) => p
          .normalize(left.path)
          .toLowerCase()
          .compareTo(p.normalize(right.path).toLowerCase()),
    );
    return List<Directory>.unmodifiable(dataDirectories);
  }

  Future<Directory> _ensureAccountDataDirectory(
    String workspaceKey, {
    required bool createAccount,
  }) {
    return _ensureAccountDataDirectoryPath(
      workspaceRoot: _workspaceRoot,
      canonicalWorkspaceRoot: _canonicalWorkspaceRoot,
      workspaceKey: workspaceKey,
      createAccount: createAccount,
    );
  }

  static Future<Directory> _ensureLocalDataDirectoryPath({
    required Directory workspaceRoot,
    required String canonicalWorkspaceRoot,
    bool createMissing = true,
  }) async {
    await _ensureOwnedDirectory(
      directory: workspaceRoot,
      expectedCanonicalPath: canonicalWorkspaceRoot,
      createMissing: false,
      errorCode: 'account_workspace_root_unsafe',
    );
    final localDirectory = await _ensureOwnedDirectory(
      directory: Directory(p.join(workspaceRoot.path, _localDirectoryName)),
      expectedCanonicalPath: p.join(
        canonicalWorkspaceRoot,
        _localDirectoryName,
      ),
      createMissing: createMissing,
      errorCode: 'account_workspace_local_unsafe',
    );
    return _ensureOwnedDirectory(
      directory: Directory(p.join(localDirectory.path, _dataDirectoryName)),
      expectedCanonicalPath: p.join(
        canonicalWorkspaceRoot,
        _localDirectoryName,
        _dataDirectoryName,
      ),
      createMissing: createMissing,
      errorCode: 'account_workspace_local_data_unsafe',
    );
  }

  static Future<Directory> _ensureAccountDataDirectoryPath({
    required Directory workspaceRoot,
    required String canonicalWorkspaceRoot,
    required String workspaceKey,
    required bool createAccount,
  }) async {
    final accountDirectory = await _ensureAccountDirectoryPath(
      workspaceRoot: workspaceRoot,
      canonicalWorkspaceRoot: canonicalWorkspaceRoot,
      workspaceKey: workspaceKey,
      createMissing: createAccount,
    );
    return _ensureOwnedDirectory(
      directory: Directory(p.join(accountDirectory.path, _dataDirectoryName)),
      expectedCanonicalPath: p.join(
        canonicalWorkspaceRoot,
        _accountsDirectoryName,
        workspaceKey,
        _dataDirectoryName,
      ),
      createMissing: true,
      errorCode: 'account_workspace_data_unsafe',
    );
  }

  static Future<Directory> _ensureAccountDirectoryPath({
    required Directory workspaceRoot,
    required String canonicalWorkspaceRoot,
    required String workspaceKey,
    required bool createMissing,
  }) async {
    if (!_isWorkspaceKey(workspaceKey)) {
      throw const FormatException('account_workspace_key');
    }
    await _ensureOwnedDirectory(
      directory: workspaceRoot,
      expectedCanonicalPath: canonicalWorkspaceRoot,
      createMissing: false,
      errorCode: 'account_workspace_root_unsafe',
    );
    final accountsDirectory = await _ensureOwnedDirectory(
      directory: Directory(p.join(workspaceRoot.path, _accountsDirectoryName)),
      expectedCanonicalPath: p.join(
        canonicalWorkspaceRoot,
        _accountsDirectoryName,
      ),
      createMissing: createMissing,
      errorCode: 'account_workspace_accounts_unsafe',
    );
    return _ensureOwnedDirectory(
      directory: Directory(p.join(accountsDirectory.path, workspaceKey)),
      expectedCanonicalPath: p.join(
        canonicalWorkspaceRoot,
        _accountsDirectoryName,
        workspaceKey,
      ),
      createMissing: createMissing,
      errorCode: 'account_workspace_account_unsafe',
    );
  }

  static Future<Directory> _ensureOwnedDirectory({
    required Directory directory,
    required String expectedCanonicalPath,
    required bool createMissing,
    required String errorCode,
  }) async {
    var type = await FileSystemEntity.type(directory.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      if (!createMissing) throw StateError('${errorCode}_missing');
      await directory.create();
      type = await FileSystemEntity.type(directory.path, followLinks: false);
    }
    if (type != FileSystemEntityType.directory) {
      throw StateError(errorCode);
    }
    final canonical = p.normalize(await directory.resolveSymbolicLinks());
    if (!p.equals(canonical, p.normalize(expectedCanonicalPath))) {
      throw StateError(errorCode);
    }
    return directory;
  }

  static String _workspaceKey(String accountScope) {
    return sha256.convert(utf8.encode(accountScope)).toString();
  }

  static bool _isWorkspaceKey(String value) {
    return RegExp(r'^[0-9a-f]{64}$').hasMatch(value);
  }

  static Map<String, Object?> _registryPayload({
    required String? activeWorkspaceKey,
    required Set<String> pendingTokenCleanup,
  }) {
    final sortedPendingTokenCleanup = pendingTokenCleanup.toList()..sort();
    return <String, Object?>{
      'version': 1,
      if (activeWorkspaceKey != null) 'activeAccount': activeWorkspaceKey,
      if (sortedPendingTokenCleanup.isNotEmpty)
        'pendingTokenCleanup': sortedPendingTokenCleanup,
    };
  }

  static String? _parseRegistry(Map<String, Object?>? payload) {
    if (payload == null) return null;
    if (payload['version'] != 1) {
      throw const FormatException('account_workspace_registry_version');
    }
    final active = payload['activeAccount'];
    if (active == null) return null;
    if (active is! String || !_isWorkspaceKey(active)) {
      throw const FormatException('account_workspace_registry');
    }
    return active;
  }

  static Set<String> _parsePendingTokenCleanup(Map<String, Object?>? payload) {
    if (payload == null || !payload.containsKey('pendingTokenCleanup')) {
      return <String>{};
    }
    final rawPending = payload['pendingTokenCleanup'];
    if (rawPending is! List<Object?>) {
      throw const FormatException('account_workspace_registry_cleanup');
    }
    final pending = <String>{};
    for (final rawWorkspaceKey in rawPending) {
      if (rawWorkspaceKey is! String ||
          !_isWorkspaceKey(rawWorkspaceKey) ||
          !pending.add(rawWorkspaceKey)) {
        throw const FormatException('account_workspace_registry_cleanup');
      }
    }
    return pending;
  }

  static bool _sameWorkspaceKeys(Set<String> left, Set<String> right) {
    return left.length == right.length && left.every(right.contains);
  }

  static _StoredAccountSession _parseStoredSession(
    Map<String, Object?> payload, {
    required String expectedWorkspaceKey,
  }) {
    if (payload['version'] != 2 || payload['accountScope'] is! String) {
      throw const FormatException('account_workspace_session');
    }
    final accountScope = (payload['accountScope'] as String).trim();
    if (accountScope.isEmpty ||
        _workspaceKey(accountScope) != expectedWorkspaceKey) {
      throw const FormatException('account_workspace_scope_mismatch');
    }

    final rawSession = payload['session'];
    final rawTokenReference = payload['tokenReference'];
    if (rawSession == null && rawTokenReference == null) {
      if (payload.length != 2) {
        throw const FormatException('account_workspace_session');
      }
      return _StoredAccountSession(accountScope: accountScope);
    }
    if (payload.length != 4 ||
        rawSession is! Map<String, Object?> ||
        rawSession.containsKey('token') ||
        rawTokenReference == null) {
      throw const FormatException('account_workspace_session');
    }
    return _StoredAccountSession(
      accountScope: accountScope,
      sessionMetadata: Map<String, Object?>.from(rawSession),
      tokenReference: AccountSessionTokenReference.fromJson(rawTokenReference),
    );
  }

  static Future<bool> _hasRecordFile({
    required Directory directory,
    required String recordName,
  }) async {
    var found = false;
    for (final slot in const <String>['a', 'b']) {
      final file = File(p.join(directory.path, '$recordName-$slot.json'));
      final type = await FileSystemEntity.type(file.path, followLinks: false);
      if (type == FileSystemEntityType.notFound) continue;
      if (type != FileSystemEntityType.file) {
        throw const FormatException('account_workspace_record_corrupt');
      }
      found = true;
    }
    return found;
  }

  static Future<bool> _deleteLegacySessionRecords(
    Directory directory, {
    required RestoreDurability durability,
  }) async {
    var deleted = false;
    for (final slot in const <String>['a', 'b']) {
      for (final name in <String>[
        '$_legacySessionRecordName-$slot.json',
        '.$_legacySessionRecordName-$slot.next',
      ]) {
        final file = File(p.join(directory.path, name));
        final type = await FileSystemEntity.type(file.path, followLinks: false);
        if (type == FileSystemEntityType.notFound) continue;
        if (type != FileSystemEntityType.file) {
          throw StateError('account_workspace_legacy_session_target');
        }
        await file.delete();
        deleted = true;
      }
    }
    if (deleted) {
      await durability.syncDirectory(directory, fullBarrier: true);
    }
    return deleted;
  }

  static Future<_WorkspaceRecord?> _readLatestRecord({
    required Directory directory,
    required String recordName,
  }) async {
    final records = <_WorkspaceRecord>[];
    var foundRecordFile = false;
    for (final slot in const <String>['a', 'b']) {
      final file = File(p.join(directory.path, '$recordName-$slot.json'));
      final type = await FileSystemEntity.type(file.path, followLinks: false);
      if (type == FileSystemEntityType.notFound) continue;
      foundRecordFile = true;
      if (type != FileSystemEntityType.file) {
        throw const FormatException('account_workspace_record_corrupt');
      }
      final Object? decoded;
      try {
        decoded = jsonDecode(await file.readAsString());
      } on FormatException {
        throw const FormatException('account_workspace_record_corrupt');
      }
      if (decoded is! Map<String, Object?> ||
          decoded['generation'] is! int ||
          decoded['payload'] is! Map<String, Object?>) {
        throw const FormatException('account_workspace_record_corrupt');
      }
      final generation = decoded['generation'] as int;
      if (generation <= 0) {
        throw const FormatException('account_workspace_record_corrupt');
      }
      records.add(
        _WorkspaceRecord(
          generation: generation,
          slot: slot,
          payload: decoded['payload'] as Map<String, Object?>,
        ),
      );
    }
    if (records.isEmpty) {
      if (foundRecordFile) {
        throw const FormatException('account_workspace_record_corrupt');
      }
      return null;
    }
    records.sort((left, right) => right.generation.compareTo(left.generation));
    if (records.length > 1 && records[0].generation == records[1].generation) {
      throw const FormatException('account_workspace_record_split_brain');
    }
    return records.first;
  }

  static Future<_WorkspaceRecord> _writeNextRecord({
    required Directory directory,
    required String recordName,
    required int currentGeneration,
    required String? currentSlot,
    required Map<String, Object?> payload,
    required RestoreDurability durability,
  }) async {
    await directory.create(recursive: true);
    final slot = currentSlot == 'a' ? 'b' : 'a';
    final target = File(p.join(directory.path, '$recordName-$slot.json'));
    final temporary = File(p.join(directory.path, '.$recordName-$slot.next'));
    if (await FileSystemEntity.type(temporary.path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      await temporary.delete(recursive: true);
    }
    final generation = currentGeneration + 1;
    await temporary.writeAsString(
      jsonEncode(<String, Object?>{
        'generation': generation,
        'payload': payload,
      }),
      flush: true,
    );
    await durability.restrictFile(temporary);
    await durability.syncFile(temporary, fullBarrier: true);
    final targetType = await FileSystemEntity.type(
      target.path,
      followLinks: false,
    );
    if (targetType != FileSystemEntityType.notFound) {
      if (targetType != FileSystemEntityType.file) {
        throw StateError('account_workspace_record_target');
      }
      await target.delete();
      await durability.syncDirectory(directory, fullBarrier: true);
    }
    await durability.renameAndSync(source: temporary, targetPath: target.path);
    return _WorkspaceRecord(
      generation: generation,
      slot: slot,
      payload: payload,
    );
  }
}

final class _WorkspaceRecord {
  const _WorkspaceRecord({
    required this.generation,
    required this.slot,
    required this.payload,
  });

  final int generation;
  final String slot;
  final Map<String, Object?> payload;
}

final class _StoredAccountSession {
  const _StoredAccountSession({
    required this.accountScope,
    this.sessionMetadata,
    this.tokenReference,
  }) : assert(
         (sessionMetadata == null) == (tokenReference == null),
         '会话元数据与 token 引用必须同时存在',
       );

  final String accountScope;
  final Map<String, Object?>? sessionMetadata;
  final AccountSessionTokenReference? tokenReference;
}
