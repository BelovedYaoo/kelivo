import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kelivo_secure_core/kelivo_secure_core.dart';

void main() {
  const core = KelivoSecureCore();

  Uint8List accountId(int seed) {
    final value = Uint8List(16)..fillRange(0, 16, seed);
    value[6] = (value[6] & 0x0f) | 0x40;
    value[8] = (value[8] & 0x3f) | 0x80;
    return value;
  }

  test('能力门禁声明 ABI v3 OPAQUE 客户端支持', () async {
    final capabilities = await core.getCapabilities();

    expect(capabilities.abiVersion, 3);
    expect(capabilities.supportsOpaqueClient, isTrue);
  });

  test('注册状态可显式取消且不能重复消费', () async {
    final password = Uint8List.fromList('registration-password'.codeUnits);
    final start = await core.startOpaqueRegistration(password);

    expect(start.request, hasLength(48));
    expect(password, 'registration-password'.codeUnits);
    await core.cancelOpaqueRegistration(start.state);
    await expectLater(
      core.cancelOpaqueRegistration(start.state),
      throwsStateError,
    );
  });

  test('登录状态可显式取消且不能重复消费', () async {
    final password = Uint8List.fromList('login-password'.codeUnits);
    final start = await core.startOpaqueLogin(password);

    expect(start.request, hasLength(112));
    expect(password, 'login-password'.codeUnits);
    await core.cancelOpaqueLogin(start.state);
    await expectLater(core.cancelOpaqueLogin(start.state), throwsStateError);
  });

  test('畸形注册响应失败后状态仍被永久消费', () async {
    final password = Uint8List.fromList('registration-password'.codeUnits);
    final start = await core.startOpaqueRegistration(password);

    await expectLater(
      core.finishOpaqueRegistration(
        start.state,
        password: password,
        response: Uint8List(80),
        accountId: accountId(0x31),
      ),
      throwsA(
        isA<KelivoSecureCoreException>().having(
          (error) => error.status,
          'status',
          KelivoSecureCoreStatus.opaqueMessageInvalid,
        ),
      ),
    );
    await expectLater(
      core.cancelOpaqueRegistration(start.state),
      throwsStateError,
    );
  });

  test('客户端接口拒绝非 UUIDv4 原始账户标识并消费状态', () async {
    final password = Uint8List.fromList('login-password'.codeUnits);
    final start = await core.startOpaqueLogin(password);

    await expectLater(
      core.finishOpaqueLogin(
        start.state,
        password: password,
        response: Uint8List(336),
        accountId: Uint8List(16),
      ),
      throwsArgumentError,
    );
    await expectLater(core.cancelOpaqueLogin(start.state), throwsStateError);
  });

  test('空密码不创建可发送请求或秘密状态', () async {
    await expectLater(
      core.startOpaqueRegistration(Uint8List(0)),
      throwsArgumentError,
    );
  });

  test('超长密码在复制或进入原生层前被拒绝', () async {
    await expectLater(
      core.startOpaqueLogin(Uint8List(65536)),
      throwsArgumentError,
    );
  });

  test('固定长度响应在复制前校验且失败仍消费状态', () async {
    final password = Uint8List.fromList('registration-password'.codeUnits);
    final start = await core.startOpaqueRegistration(password);

    await expectLater(
      core.finishOpaqueRegistration(
        start.state,
        password: password,
        response: Uint8List(79),
        accountId: accountId(0x32),
      ),
      throwsArgumentError,
    );
    await expectLater(
      core.cancelOpaqueRegistration(start.state),
      throwsStateError,
    );
  });

  test('已消费状态会在创建密码转移缓冲区前同步拒绝', () async {
    final password = Uint8List.fromList('login-password'.codeUnits);
    final start = await core.startOpaqueLogin(password);
    await core.cancelOpaqueLogin(start.state);

    expect(
      () => core.finishOpaqueLogin(
        start.state,
        password: Uint8List(65536),
        response: Uint8List(336),
        accountId: accountId(0x33),
      ),
      throwsStateError,
    );
  });
}
