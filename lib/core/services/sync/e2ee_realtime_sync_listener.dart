import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'cloud_sync_types.dart';

/// SSE 实时同步监听器。
///
/// 与服务器 `/api/sync/realtime/events?afterSeq=N` 保持长连接：服务器在
/// 同步水位（全局最大 change_seq）前进时推送 `sync` 变更通知，本监听器
/// 解析后触发 [onChanges]（调用方应唤醒同步调度器立即拉取）；连接空闲时
/// 服务器以 `: ping` 注释帧保活。连接断开或超时后按指数退避重连，重连时
/// 通过 [readChangeSeq] 读取最新 checkpoint 游标补拉断线期间的变更。
///
/// 只消费通知，不传密文本体；实际增量拉取走既有 pull 链路。
final class E2eeRealtimeSyncListener {
  E2eeRealtimeSyncListener({
    required this.baseUrl,
    required this.tokenProvider,
    required this.readChangeSeq,
    required this.onChanges,
    required this.onAuthFailure,
    Dio? dio,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 15),
               receiveTimeout: const Duration(seconds: 15),
             ),
           );

  final String baseUrl;
  final CloudSyncFullSessionToken? Function() tokenProvider;
  final Future<int> Function() readChangeSeq;
  final void Function() onChanges;
  final void Function() onAuthFailure;
  final Dio _dio;

  static const String _protocolHeaderName = 'X-Kelivo-Sync-Protocol-Version';
  static const String _protocolVersion = '4';
  static const Duration _initialRetryDelay = Duration(seconds: 1);
  static const Duration _maxRetryDelay = Duration(minutes: 5);

  CancelToken? _cancelToken;
  Future<void>? _runFuture;
  bool _closed = false;
  bool _changesSeen = false;
  Duration _retryDelay = _initialRetryDelay;

  bool get isRunning => _runFuture != null;

  /// 建立 SSE 长连接并阻塞监听，直到关闭或遇到不可恢复错误。
  Future<void> start() {
    _closed = false;
    _retryDelay = _initialRetryDelay;
    return _runFuture ??= _run();
  }

  Future<void> _run() async {
    while (!_closed) {
      final token = tokenProvider();
      if (token == null) {
        // 无会话令牌（登出/未登录）：停止监听，等待重新 start。
        _cancelToken = null;
        return;
      }
      final cancelToken = CancelToken();
      _cancelToken = cancelToken;
      try {
        final afterSeq = await readChangeSeq();
        final uri = '$baseUrl/api/sync/realtime/events?afterSeq=$afterSeq';
        final response = await _dio.get<ResponseBody>(
          uri,
          options: Options(
            responseType: ResponseType.stream,
            headers: <String, String>{
              'Authorization': 'Bearer ${token.value}',
              _protocolHeaderName: _protocolVersion,
            },
          ),
          cancelToken: cancelToken,
        );
        final status = response.statusCode ?? 0;
        if (status == 401 || status == 403) {
          onAuthFailure();
          return;
        }
        if (status != 200) {
          // 服务器不可用/协议不匹配：退避重连。
          await _backoff(cancelToken);
          continue;
        }
        await _consumeStream(response.data, cancelToken);
        if (_closed) return;
        if (_changesSeen) {
          // 收到过变更：立即重连继续监听（补拉由调用方在 onChanges 完成）。
          _changesSeen = false;
          _retryDelay = _initialRetryDelay;
        } else {
          // 服务器 90s 上限/空闲关闭：退避后重连。
          await _backoff(cancelToken);
          if (_closed || cancelToken.isCancelled) return;
        }
      } on DioException catch (error) {
        if (_closed) return;
        final status = error.response?.statusCode;
        if (status == 401 || status == 403) {
          onAuthFailure();
          return;
        }
        if (cancelToken.isCancelled) return;
        await _backoff(cancelToken);
      } catch (_) {
        if (_closed) return;
        if (cancelToken.isCancelled) return;
        await _backoff(cancelToken);
      }
    }
  }

  Future<void> _consumeStream(
    ResponseBody? body,
    CancelToken cancelToken,
  ) async {
    if (body == null) return;
    final decoder = const Utf8Decoder(allowMalformed: true);
    String? eventName;
    String? eventData;
    await for (final chunk in body.stream) {
      if (_closed || cancelToken.isCancelled) return;
      final text = decoder.convert(_bytesOf(chunk));
      // SSE 帧按空行分隔；行尾可能是 \n 或 \r\n。
      for (final rawLine in text.split('\n')) {
        final line = rawLine.endsWith('\r')
            ? rawLine.substring(0, rawLine.length - 1)
            : rawLine;
        if (line.isEmpty) {
          _dispatchFrame(eventName, eventData, cancelToken);
          eventName = null;
          eventData = null;
          continue;
        }
        if (line.startsWith(':')) continue; // 注释帧（心跳）
        if (line.startsWith('event:')) {
          eventName = line.substring('event:'.length).trim();
        } else if (line.startsWith('data:')) {
          eventData = (eventData == null)
              ? line.substring('data:'.length).trim()
              : '$eventData\n${line.substring('data:'.length).trim()}';
        }
      }
    }
    _dispatchFrame(eventName, eventData, cancelToken);
  }

  void _dispatchFrame(
    String? eventName,
    String? eventData,
    CancelToken cancelToken,
  ) {
    if (_closed || cancelToken.isCancelled) return;
    if (eventName != 'sync' || eventData == null) return;
    try {
      final decoded = jsonDecode(eventData);
      if (decoded is Map && decoded['type'] == 'changes') {
        _changesSeen = true;
        onChanges();
      }
    } catch (_) {
      // 忽略无法解析的通知帧。
    }
  }

  Uint8List _bytesOf(dynamic chunk) {
    if (chunk is Uint8List) return chunk;
    if (chunk is List<int>) return Uint8List.fromList(chunk);
    if (chunk is String) return Uint8List.fromList(utf8.encode(chunk));
    return Uint8List(0);
  }

  Future<void> _backoff(CancelToken cancelToken) async {
    if (_closed) return;
    await Future<void>.delayed(_retryDelay);
    if (_closed || cancelToken.isCancelled) return;
    final next = _retryDelay * 2;
    _retryDelay = next > _maxRetryDelay ? _maxRetryDelay : next;
  }

  Future<void> close() async {
    _closed = true;
    _cancelToken?.cancel();
    _cancelToken = null;
    final run = _runFuture;
    _runFuture = null;
    await run;
  }
}
