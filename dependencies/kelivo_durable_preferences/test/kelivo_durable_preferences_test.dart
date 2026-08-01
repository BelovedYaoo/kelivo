import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelivo_durable_preferences/kelivo_durable_preferences.dart';
import 'package:shared_preferences_platform_interface/types.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('kelivo.durable_preferences');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('初始化完成后写入才返回成功', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    final store = KelivoDurablePreferences(channel: channel);

    await store.initialize();
    expect(await store.setValue('Bool', 'flutter.enabled', true), isTrue);

    expect(calls, hasLength(2));
    expect(calls.first.method, 'initialize');
    expect(calls.last.method, 'set-value');
    expect(calls.last.arguments, <String, Object>{
      'key': 'flutter.enabled',
      'valueType': 'Bool',
      'value': true,
    });
  });

  test('读取和清理完整保留前缀及白名单边界', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'get-all') {
        return <String, Object>{'kelivo.account.alpha.theme': 'dark'};
      }
      return null;
    });
    final store = KelivoDurablePreferences(channel: channel);
    const allowList = <String>{'kelivo.account.alpha.theme'};
    final filter = PreferencesFilter(
      prefix: 'kelivo.account.alpha.',
      allowList: allowList,
    );

    final values = await store.getAllWithParameters(
      GetAllParameters(filter: filter),
    );
    expect(values, <String, Object>{'kelivo.account.alpha.theme': 'dark'});
    expect(
      await store.clearWithParameters(ClearParameters(filter: filter)),
      isTrue,
    );

    expect(calls, hasLength(2));
    for (final call in calls) {
      expect(call.arguments, <String, Object>{
        'prefix': 'kelivo.account.alpha.',
        'allowList': <String>['kelivo.account.alpha.theme'],
      });
    }
  });

  test('原生耐久屏障失败时不得伪报删除成功', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'parent-directory-sync-failed');
    });
    final store = KelivoDurablePreferences(channel: channel);

    await expectLater(
      store.remove('flutter.secret'),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'parent-directory-sync-failed',
        ),
      ),
    );
  });

  test('原生返回畸形快照时失败关闭', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      return <Object?, Object?>{1: 'invalid'};
    });
    final store = KelivoDurablePreferences(channel: channel);

    await expectLater(
      store.getAllWithParameters(
        GetAllParameters(filter: PreferencesFilter(prefix: '')),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'kelivo_durable_preferences_invalid_snapshot',
        ),
      ),
    );
  });
}
