import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/sync/cloud_sync_types.dart';
import 'package:Kelivo/core/services/sync/e2ee_realtime_sync_listener.dart';

/// 可编排的 SSE 响应流 adapter：每个连接按队列依次提供响应体流，用尽后
/// 复用最后一个；[closeAfterFrames] 控制每连接帧发完后是否关闭流
/// （false = 长连接保持打开，真实服务器直到 90s 上限才关闭）。
final class _SseAdapter implements HttpClientAdapter {
  _SseAdapter(this.statusCodes, this.frames, this.closeAfterFrames);

  final List<int> statusCodes;
  final List<List<String>> frames; // 每个连接的 SSE 帧序列
  final List<bool> closeAfterFrames; // 每连接发完后是否关闭
  int connections = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final index = connections < frames.length ? connections : frames.length - 1;
    connections += 1;
    final closeAfter = closeAfterFrames.length > index
        ? closeAfterFrames[index]
        : closeAfterFrames.last;
    final joined = StringBuffer();
    for (final frame in frames[index]) {
      joined.write(frame);
    }
    final controller = StreamController<Uint8List>();
    if (joined.isNotEmpty) {
      controller.add(_Utf8Helper.encode(joined.toString()));
    }
    if (closeAfter) {
      unawaited(controller.close());
    }
    return ResponseBody(
      controller.stream,
      statusCodes[index],
      headers: const <String, List<String>>{
        'content-type': <String>['text/event-stream'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

final class _Utf8Helper {
  static Uint8List encode(String text) {
    final bytes = <int>[];
    for (final rune in text.runes) {
      if (rune < 0x80) {
        bytes.add(rune);
      } else if (rune < 0x800) {
        bytes
          ..add(0xC0 | (rune >> 6))
          ..add(0x80 | (rune & 0x3F));
      } else if (rune < 0x10000) {
        bytes
          ..add(0xE0 | (rune >> 12))
          ..add(0x80 | ((rune >> 6) & 0x3F))
          ..add(0x80 | (rune & 0x3F));
      } else {
        bytes
          ..add(0xF0 | (rune >> 18))
          ..add(0x80 | ((rune >> 12) & 0x3F))
          ..add(0x80 | ((rune >> 6) & 0x3F))
          ..add(0x80 | (rune & 0x3F));
      }
    }
    return Uint8List.fromList(bytes);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final token = CloudSyncFullSessionToken.generate();

  E2eeRealtimeSyncListener listener({
    required _SseAdapter adapter,
    required void Function() onChanges,
    void Function()? onAuthFailure,
    int changeSeq = 0,
  }) {
    final dio = Dio(BaseOptions());
    dio.httpClientAdapter = adapter;
    return E2eeRealtimeSyncListener(
      baseUrl: 'https://sync.test',
      tokenProvider: () => token,
      readChangeSeq: () async => changeSeq,
      onChanges: onChanges,
      onAuthFailure: onAuthFailure ?? () {},
      dio: dio,
    );
  }

  test('收到 sync changes 事件触发 onChanges', () async {
    var fired = 0;
    final adapter = _SseAdapter(
      <int>[200],
      <List<String>>[
        <String>[
          'event: sync\n',
          'data: {"type":"changes","watermark":7,"dataGeneration":1}\n',
          '\n',
        ],
      ],
      <bool>[false],
    );
    final l = listener(adapter: adapter, onChanges: () => fired++);
    final run = l.start();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(fired, 1);
    await l.close();
    await run;
  });

  test('心跳注释帧与无关帧被忽略', () async {
    var fired = 0;
    final adapter = _SseAdapter(
      <int>[200],
      <List<String>>[
        <String>[
          ': ping\n',
          '\n',
          'event: other\n',
          'data: {"type":"x"}\n',
          '\n',
        ],
      ],
      <bool>[false],
    );
    final l = listener(adapter: adapter, onChanges: () => fired++);
    final run = l.start();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(fired, 0);
    await l.close();
    await run;
  });

  test('401 触发 onAuthFailure 并停止重连', () async {
    var authFailures = 0;
    final adapter = _SseAdapter(<int>[401], <List<String>>[<String>[]], <bool>[
      true,
    ]);
    final l = listener(
      adapter: adapter,
      onChanges: () {},
      onAuthFailure: () => authFailures++,
    );
    final run = l.start();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(authFailures, 1);
    await l.close();
    await run;
  });

  test('连接断开后按退避重连并补拉新水位', () async {
    var fired = 0;
    // 第一次连接：无变更（仅心跳），流立即结束 → 触发重连；
    // 第二次连接：推送变更事件。
    final adapter = _SseAdapter(
      <int>[200, 200],
      <List<String>>[
        <String>[': ping\n', '\n'],
        <String>[
          'event: sync\n',
          'data: {"type":"changes","watermark":9,"dataGeneration":1}\n',
          '\n',
        ],
      ],
      <bool>[true, false],
    );
    final l = listener(adapter: adapter, onChanges: () => fired++);
    final run = l.start();
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    expect(adapter.connections, greaterThanOrEqualTo(2));
    expect(fired, 1);
    await l.close();
    await run;
  });
}
