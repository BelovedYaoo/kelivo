library;

import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'kelivo_secure_core_bindings_generated.dart' as native;

const _expectedAbiVersion = 3;
const _keySlotIdLength = 16;
const _keyPolicyVersion = 1;
const _keySlotsCapability = 1 << 0;
const _backgroundAccessCapability = 1 << 1;
const _recordEnvelopesCapability = 1 << 2;
const _sqlCipherKeyApplicationCapability = 1 << 3;
const _sqlCipherDatabaseAttachCapability = 1 << 4;
const _opaqueClientCapability = 1 << 5;
const _secureStorageCapabilityFlags =
    _keySlotsCapability |
    _backgroundAccessCapability |
    _recordEnvelopesCapability |
    _sqlCipherKeyApplicationCapability |
    _sqlCipherDatabaseAttachCapability;
const _knownCapabilityFlags =
    _secureStorageCapabilityFlags | _opaqueClientCapability;
const _recordIdLength = native.KELIVO_RECORD_ID_SIZE;
const _recordMaxAssociatedDataSize =
    native.KELIVO_RECORD_MAX_ASSOCIATED_DATA_SIZE;
const _recordMaxPlaintextSize = native.KELIVO_RECORD_MAX_PLAINTEXT_SIZE;
const _recordMaxEnvelopeSize = native.KELIVO_RECORD_MAX_ENVELOPE_SIZE;
const _databaseIdLength = native.KELIVO_DATABASE_ID_SIZE;
const _databaseNameMaxLength = native.KELIVO_DATABASE_NAME_MAX_SIZE;
const _databasePathMaxLength = native.KELIVO_DATABASE_PATH_MAX_SIZE;
const _opaqueInvalidStateHandle = native.KELIVO_OPAQUE_INVALID_STATE_HANDLE;
const _opaqueMaxInputSize = native.KELIVO_OPAQUE_MAX_INPUT_SIZE;
const _opaqueAccountIdSize = native.KELIVO_OPAQUE_ACCOUNT_ID_SIZE;
const _opaqueRegistrationRequestSize =
    native.KELIVO_OPAQUE_REGISTRATION_REQUEST_SIZE;
const _opaqueRegistrationResponseSize =
    native.KELIVO_OPAQUE_REGISTRATION_RESPONSE_SIZE;
const _opaqueRegistrationUploadSize =
    native.KELIVO_OPAQUE_REGISTRATION_UPLOAD_SIZE;
const _opaqueCredentialRequestSize =
    native.KELIVO_OPAQUE_CREDENTIAL_REQUEST_SIZE;
const _opaqueCredentialResponseSize =
    native.KELIVO_OPAQUE_CREDENTIAL_RESPONSE_SIZE;
const _opaqueCredentialFinalizationSize =
    native.KELIVO_OPAQUE_CREDENTIAL_FINALIZATION_SIZE;
// Dart FFI 用有符号 int 传递 Uint64；保留正数域可避免跨平台符号歧义。
const _recordMaxEpoch = 0x7fffffffffffffff;

enum KelivoSecureStorageBackend {
  none(0),
  windowsDpapi(1),
  androidKeystore(2),
  linuxSecretService(3);

  const KelivoSecureStorageBackend(this.code);

  final int code;

  static KelivoSecureStorageBackend fromCode(int code) {
    for (final backend in values) {
      if (backend.code == code) return backend;
    }
    throw StateError('安全核心返回了未知的安全存储后端：$code');
  }
}

enum KelivoSecureCoreStatus {
  ok(0),
  nullPointer(1),
  invalidSlotIdLength(2),
  unsupportedPolicy(3),
  invalidKeyHandle(4),
  outputBufferTooSmall(5),
  slotNotFound(6),
  slotAlreadyExists(7),
  slotDataInvalid(8),
  slotUnwrapFailed(9),
  secureStorageUnavailable(10),
  randomSourceFailure(11),
  ioFailure(12),
  internalState(13),
  invalidRecordIdLength(14),
  invalidArgument(15),
  recordEnvelopeInvalid(16),
  recordAuthenticationFailed(17),
  inputTooLarge(18),
  sqlCipherKeyFailed(19),
  sqlCipherAttachFailed(20),
  invalidOpaqueStateHandle(21),
  opaqueMessageInvalid(22),
  opaqueProtocolFailed(23),
  tooManyActiveHandles(24),
  handleSpaceExhausted(25),
  invalidAccountId(26),
  unsupportedPlatform(100);

  const KelivoSecureCoreStatus(this.code);

  final int code;

  static KelivoSecureCoreStatus fromCode(int code) {
    for (final status in values) {
      if (status.code == code) return status;
    }
    throw StateError('安全核心返回了未知状态码：$code');
  }
}

final class KelivoCoreCapabilities {
  const KelivoCoreCapabilities({
    required this.abiVersion,
    required this.backend,
    required this.supportsKeySlots,
    required this.supportsBackgroundAccess,
    required this.supportsRecordEnvelopes,
    required this.supportsSqlCipherKeyApplication,
    required this.supportsSqlCipherDatabaseAttach,
    required this.supportsOpaqueClient,
  });

  final int abiVersion;
  final KelivoSecureStorageBackend backend;
  final bool supportsKeySlots;
  final bool supportsBackgroundAccess;
  final bool supportsRecordEnvelopes;
  final bool supportsSqlCipherKeyApplication;
  final bool supportsSqlCipherDatabaseAttach;
  final bool supportsOpaqueClient;
}

typedef KelivoSqlCipherKeyNative =
    ffi.Int32 Function(
      ffi.Pointer<ffi.Void> database,
      ffi.Pointer<ffi.Void> key,
      ffi.Int32 keyLength,
    );

typedef KelivoSqlitePrepareNative =
    ffi.Int32 Function(
      ffi.Pointer<ffi.Void> database,
      ffi.Pointer<ffi.Char> sql,
      ffi.Int32 sqlLength,
      ffi.Pointer<ffi.Pointer<ffi.Void>> outStatement,
      ffi.Pointer<ffi.Pointer<ffi.Char>> sqlTail,
    );
typedef KelivoSqliteDestructorNative =
    ffi.Void Function(ffi.Pointer<ffi.Void> value);
typedef KelivoSqliteBindTextNative =
    ffi.Int32 Function(
      ffi.Pointer<ffi.Void> statement,
      ffi.Int32 index,
      ffi.Pointer<ffi.Char> value,
      ffi.Int32 valueLength,
      ffi.Pointer<ffi.NativeFunction<KelivoSqliteDestructorNative>> destructor,
    );
typedef KelivoSqliteBindBlobNative =
    ffi.Int32 Function(
      ffi.Pointer<ffi.Void> statement,
      ffi.Int32 index,
      ffi.Pointer<ffi.Void> value,
      ffi.Int32 valueLength,
      ffi.Pointer<ffi.NativeFunction<KelivoSqliteDestructorNative>> destructor,
    );
typedef KelivoSqliteStepNative =
    ffi.Int32 Function(ffi.Pointer<ffi.Void> statement);
typedef KelivoSqliteFinalizeNative =
    ffi.Int32 Function(ffi.Pointer<ffi.Void> statement);

final class KelivoKeyHandle {
  KelivoKeyHandle._(this._value);

  final int _value;
  _KelivoKeyHandleState _state = _KelivoKeyHandleState.open;

  int _requireOpen() {
    if (_state != _KelivoKeyHandleState.open) {
      throw StateError('密钥句柄已关闭或正在关闭');
    }
    return _value;
  }

  int _beginClose() {
    final value = _requireOpen();
    _state = _KelivoKeyHandleState.closing;
    return value;
  }

  void _completeClose() {
    _state = _KelivoKeyHandleState.closed;
  }

  void _cancelClose() {
    if (_state == _KelivoKeyHandleState.closing) {
      _state = _KelivoKeyHandleState.open;
    }
  }

  @override
  String toString() => 'KelivoKeyHandle(opaque)';
}

enum _KelivoKeyHandleState { open, closing, closed }

final class _KelivoOpaqueStateHandle {
  _KelivoOpaqueStateHandle(this.value);

  final int value;
  _KelivoOpaqueStateHandleState state = _KelivoOpaqueStateHandleState.active;

  int beginConsume() {
    if (state != _KelivoOpaqueStateHandleState.active) {
      throw StateError('OPAQUE 客户端状态已消费或正在消费');
    }
    state = _KelivoOpaqueStateHandleState.consuming;
    return value;
  }

  void completeConsume() {
    state = _KelivoOpaqueStateHandleState.closed;
  }
}

enum _KelivoOpaqueStateHandleState { active, consuming, closed }

final class KelivoOpaqueRegistrationHandle {
  KelivoOpaqueRegistrationHandle._(int value)
    : _state = _KelivoOpaqueStateHandle(value);

  final _KelivoOpaqueStateHandle _state;

  @override
  String toString() => 'KelivoOpaqueRegistrationHandle(opaque)';
}

final class KelivoOpaqueLoginHandle {
  KelivoOpaqueLoginHandle._(int value)
    : _state = _KelivoOpaqueStateHandle(value);

  final _KelivoOpaqueStateHandle _state;

  @override
  String toString() => 'KelivoOpaqueLoginHandle(opaque)';
}

final class KelivoOpaqueRegistrationStart {
  const KelivoOpaqueRegistrationStart({
    required this.state,
    required this.request,
  });

  final KelivoOpaqueRegistrationHandle state;
  final Uint8List request;
}

final class KelivoOpaqueLoginStart {
  const KelivoOpaqueLoginStart({required this.state, required this.request});

  final KelivoOpaqueLoginHandle state;
  final Uint8List request;
}

final class KelivoSecureCoreException implements Exception {
  const KelivoSecureCoreException({
    required this.operation,
    required this.status,
  });

  final String operation;
  final KelivoSecureCoreStatus status;

  @override
  String toString() =>
      'KelivoSecureCoreException(operation: $operation, status: ${status.name})';
}

final class KelivoSecureCore {
  const KelivoSecureCore();

  Future<KelivoCoreCapabilities> getCapabilities() =>
      Isolate.run(_readCapabilities);

  Future<KelivoOpaqueRegistrationStart> startOpaqueRegistration(
    Uint8List password,
  ) async {
    _validateOpaquePassword(password);
    final result = await _runWithTransferredPassword(
      password,
      _opaqueRegistrationStart,
    );
    return KelivoOpaqueRegistrationStart(
      state: KelivoOpaqueRegistrationHandle._(result.handle),
      request: result.message,
    );
  }

  Future<Uint8List> finishOpaqueRegistration(
    KelivoOpaqueRegistrationHandle state, {
    required Uint8List password,
    required Uint8List response,
    required Uint8List accountId,
  }) {
    final opaqueValue = state._state.beginConsume();
    return _consumeOpaqueState(state._state, opaqueValue, () async {
      _validateOpaqueFinishInputs(
        password: password,
        response: response,
        expectedResponseSize: _opaqueRegistrationResponseSize,
        accountId: accountId,
      );
      final copiedResponse = Uint8List.fromList(response);
      final copiedAccountId = Uint8List.fromList(accountId);
      return _runWithTransferredPassword(
        password,
        (workerPassword) => _opaqueRegistrationFinish(
          opaqueValue,
          workerPassword,
          copiedResponse,
          copiedAccountId,
        ),
      );
    });
  }

  Future<void> cancelOpaqueRegistration(KelivoOpaqueRegistrationHandle state) =>
      _cancelOpaqueState(state._state);

  Future<KelivoOpaqueLoginStart> startOpaqueLogin(Uint8List password) async {
    _validateOpaquePassword(password);
    final result = await _runWithTransferredPassword(
      password,
      _opaqueLoginStart,
    );
    return KelivoOpaqueLoginStart(
      state: KelivoOpaqueLoginHandle._(result.handle),
      request: result.message,
    );
  }

  Future<Uint8List> finishOpaqueLogin(
    KelivoOpaqueLoginHandle state, {
    required Uint8List password,
    required Uint8List response,
    required Uint8List accountId,
  }) {
    final opaqueValue = state._state.beginConsume();
    return _consumeOpaqueState(state._state, opaqueValue, () async {
      _validateOpaqueFinishInputs(
        password: password,
        response: response,
        expectedResponseSize: _opaqueCredentialResponseSize,
        accountId: accountId,
      );
      final copiedResponse = Uint8List.fromList(response);
      final copiedAccountId = Uint8List.fromList(accountId);
      return _runWithTransferredPassword(
        password,
        (workerPassword) => _opaqueLoginFinish(
          opaqueValue,
          workerPassword,
          copiedResponse,
          copiedAccountId,
        ),
      );
    });
  }

  Future<void> cancelOpaqueLogin(KelivoOpaqueLoginHandle state) =>
      _cancelOpaqueState(state._state);

  Future<KelivoKeyHandle> createSlot(Uint8List slotId) {
    final copiedSlotId = Uint8List.fromList(slotId);
    return Isolate.run(() => _openKeySlot(copiedSlotId, create: true));
  }

  Future<KelivoKeyHandle> openSlot(Uint8List slotId) {
    final copiedSlotId = Uint8List.fromList(slotId);
    return Isolate.run(() => _openKeySlot(copiedSlotId, create: false));
  }

  Future<Uint8List> sealRecord(
    KelivoKeyHandle handle, {
    required Uint8List recordId,
    required int epoch,
    required Uint8List associatedData,
    required Uint8List plaintext,
  }) {
    final opaqueValue = handle._requireOpen();
    _validateRecordContext(
      recordId: recordId,
      epoch: epoch,
      associatedData: associatedData,
    );
    if (plaintext.length > _recordMaxPlaintextSize) {
      throw ArgumentError.value(
        plaintext.length,
        'plaintext',
        '记录明文不得超过 $_recordMaxPlaintextSize 字节',
      );
    }

    final copiedRecordId = Uint8List.fromList(recordId);
    final copiedAssociatedData = Uint8List.fromList(associatedData);
    final copiedPlaintext = Uint8List.fromList(plaintext);
    return Isolate.run(
      () => _sealRecord(
        opaqueValue,
        copiedRecordId,
        epoch,
        copiedAssociatedData,
        copiedPlaintext,
      ),
    );
  }

  Future<Uint8List> openRecord(
    KelivoKeyHandle handle, {
    required Uint8List recordId,
    required int epoch,
    required Uint8List associatedData,
    required Uint8List envelope,
  }) {
    final opaqueValue = handle._requireOpen();
    _validateRecordContext(
      recordId: recordId,
      epoch: epoch,
      associatedData: associatedData,
    );
    if (envelope.length > _recordMaxEnvelopeSize) {
      throw ArgumentError.value(
        envelope.length,
        'envelope',
        '记录信封不得超过 $_recordMaxEnvelopeSize 字节',
      );
    }

    final copiedRecordId = Uint8List.fromList(recordId);
    final copiedAssociatedData = Uint8List.fromList(associatedData);
    final copiedEnvelope = Uint8List.fromList(envelope);
    return Isolate.run(
      () => _openRecord(
        opaqueValue,
        copiedRecordId,
        epoch,
        copiedAssociatedData,
        copiedEnvelope,
      ),
    );
  }

  Future<void> close(KelivoKeyHandle handle) async {
    final opaqueValue = handle._beginClose();
    try {
      await Isolate.run(() {
        _throwOnError(
          operation: 'key_handle_close',
          statusCode: native.kelivo_key_handle_close(opaqueValue),
        );
      });
      handle._completeClose();
    } catch (_) {
      handle._cancelClose();
      rethrow;
    }
  }

  /// Drift 已把数据库 setup 放在工作 isolate；同步设键可让派生密钥始终
  /// 留在 Rust 与 SQLCipher 的原生调用栈，避免为跨 isolate 传参而复制密钥。
  void applySqlCipherKeySync({
    required Uint8List slotId,
    required Uint8List databaseId,
    required int epoch,
    required bool createSlotIfMissing,
    required ffi.Pointer<ffi.Void> database,
    required ffi.Pointer<ffi.NativeFunction<KelivoSqlCipherKeyNative>>
    keyCallback,
  }) {
    if (databaseId.length != _databaseIdLength) {
      throw ArgumentError.value(
        databaseId.length,
        'databaseId',
        '数据库标识必须为 $_databaseIdLength 字节',
      );
    }
    if (epoch <= 0 || epoch > _recordMaxEpoch) {
      throw ArgumentError.value(epoch, 'epoch', '密钥世代必须在正 63 位整数范围内');
    }
    if (database.address == 0) {
      throw ArgumentError.value(database, 'database', '数据库指针不得为空');
    }
    if (keyCallback.address == 0) {
      throw ArgumentError.value(keyCallback, 'keyCallback', '设键函数指针不得为空');
    }

    final copiedSlotId = Uint8List.fromList(slotId);
    final copiedDatabaseId = Uint8List.fromList(databaseId);
    final handle = createSlotIfMissing
        ? _openOrCreateKeySlot(copiedSlotId)
        : _openKeySlot(copiedSlotId, create: false);
    _runWithSynchronousKeyHandle(handle, (opaqueValue) {
      final databaseIdPointer = _copyToNative(copiedDatabaseId);
      try {
        _throwOnError(
          operation: 'sqlcipher_key_apply',
          statusCode: native.kelivo_sqlcipher_key_apply(
            opaqueValue,
            databaseIdPointer,
            copiedDatabaseId.length,
            epoch,
            database,
            keyCallback,
          ),
        );
      } finally {
        _clearAndFree(databaseIdPointer, copiedDatabaseId.length);
        copiedDatabaseId.fillRange(0, copiedDatabaseId.length, 0);
      }
    });
  }

  /// ATTACH 的预编译、密钥绑定、执行与清理必须保持在同一同步原生调用内。
  void attachSqlCipherDatabaseSync({
    required Uint8List slotId,
    required Uint8List databaseId,
    required int epoch,
    required String databasePath,
    required String databaseName,
    required ffi.Pointer<ffi.Void> database,
    required ffi.Pointer<ffi.NativeFunction<KelivoSqlitePrepareNative>>
    prepareCallback,
    required ffi.Pointer<ffi.NativeFunction<KelivoSqliteBindTextNative>>
    bindTextCallback,
    required ffi.Pointer<ffi.NativeFunction<KelivoSqliteBindBlobNative>>
    bindBlobCallback,
    required ffi.Pointer<ffi.NativeFunction<KelivoSqliteStepNative>>
    stepCallback,
    required ffi.Pointer<ffi.NativeFunction<KelivoSqliteFinalizeNative>>
    finalizeCallback,
  }) {
    if (databaseId.length != _databaseIdLength) {
      throw ArgumentError.value(
        databaseId.length,
        'databaseId',
        '数据库标识必须为 $_databaseIdLength 字节',
      );
    }
    if (epoch <= 0 || epoch > _recordMaxEpoch) {
      throw ArgumentError.value(epoch, 'epoch', '密钥世代必须在正 63 位整数范围内');
    }
    final databasePathBytes = _validateDatabasePath(databasePath);
    final databaseNameBytes = _validateDatabaseName(databaseName);
    if (database.address == 0) {
      throw ArgumentError.value(database, 'database', '数据库指针不得为空');
    }
    if (prepareCallback.address == 0 ||
        bindTextCallback.address == 0 ||
        bindBlobCallback.address == 0 ||
        stepCallback.address == 0 ||
        finalizeCallback.address == 0) {
      throw ArgumentError('SQLite 回调指针不得为空');
    }

    final copiedSlotId = Uint8List.fromList(slotId);
    final copiedDatabaseId = Uint8List.fromList(databaseId);
    final handle = _openKeySlot(copiedSlotId, create: false);
    _runWithSynchronousKeyHandle(handle, (opaqueValue) {
      final databaseIdPointer = _copyToNative(copiedDatabaseId);
      final databasePathPointer = _copyToNative(databasePathBytes);
      final databaseNamePointer = _copyToNative(databaseNameBytes);
      try {
        _throwOnError(
          operation: 'sqlcipher_database_attach',
          statusCode: native.kelivo_sqlcipher_database_attach(
            opaqueValue,
            databaseIdPointer,
            copiedDatabaseId.length,
            epoch,
            database,
            databasePathPointer,
            databasePathBytes.length,
            databaseNamePointer,
            databaseNameBytes.length,
            prepareCallback,
            bindTextCallback,
            bindBlobCallback,
            stepCallback,
            finalizeCallback,
          ),
        );
      } finally {
        _clearAndFree(databaseIdPointer, copiedDatabaseId.length);
        _clearAndFree(databasePathPointer, databasePathBytes.length);
        _clearAndFree(databaseNamePointer, databaseNameBytes.length);
        copiedDatabaseId.fillRange(0, copiedDatabaseId.length, 0);
      }
    });
  }
}

final class _OpaqueStartNativeResult {
  const _OpaqueStartNativeResult({required this.handle, required this.message});

  final int handle;
  final Uint8List message;
}

void _validateOpaquePassword(Uint8List password) {
  if (password.isEmpty || password.length > _opaqueMaxInputSize) {
    throw ArgumentError.value(
      password.length,
      'password',
      'OPAQUE 密码必须为 1 到 $_opaqueMaxInputSize 字节',
    );
  }
}

void _validateOpaqueFinishInputs({
  required Uint8List password,
  required Uint8List response,
  required int expectedResponseSize,
  required Uint8List accountId,
}) {
  _validateOpaquePassword(password);
  if (response.length != expectedResponseSize) {
    throw ArgumentError.value(
      response.length,
      'response',
      'OPAQUE 响应必须为 $expectedResponseSize 字节',
    );
  }
  if (accountId.length != _opaqueAccountIdSize ||
      accountId[6] & 0xf0 != 0x40 ||
      accountId[8] & 0xc0 != 0x80) {
    throw ArgumentError.value(
      accountId.length,
      'accountId',
      '账户标识必须为 RFC 4122 UUIDv4 原始 16 字节',
    );
  }
}

TransferableTypedData _transferPassword(Uint8List password) {
  final temporary = Uint8List.fromList(password);
  try {
    // 跨 isolate 使用可转移缓冲区，避免消息发送再产生一份无法主动清零的密码副本。
    return TransferableTypedData.fromList([temporary]);
  } finally {
    temporary.fillRange(0, temporary.length, 0);
  }
}

Future<T> _runWithTransferredPassword<T>(
  Uint8List password,
  T Function(Uint8List workerPassword) operation,
) async {
  final transferredPassword = _transferPassword(password);
  try {
    return await Isolate.run(() {
      final workerPassword = transferredPassword.materialize().asUint8List();
      try {
        return operation(workerPassword);
      } finally {
        workerPassword.fillRange(0, workerPassword.length, 0);
      }
    });
  } catch (error, stackTrace) {
    try {
      final unsentPassword = transferredPassword.materialize().asUint8List();
      unsentPassword.fillRange(0, unsentPassword.length, 0);
    } on ArgumentError {
      // 已转移时原 isolate 会拒绝再次 materialize，工作 isolate 负责清零。
    } on StateError {
      // 已转移时，工作 isolate 必定先 materialize，并由其 finally 负责清零。
    }
    Error.throwWithStackTrace(error, stackTrace);
  }
}

Future<T> _consumeOpaqueState<T>(
  _KelivoOpaqueStateHandle state,
  int opaqueValue,
  Future<T> Function() operation,
) async {
  try {
    return await operation();
  } catch (error, stackTrace) {
    try {
      _closeConsumedOpaqueState(opaqueValue);
    } catch (closeError, closeStackTrace) {
      Error.throwWithStackTrace(
        StateError('OPAQUE 操作失败且秘密状态销毁失败：$error；$closeError'),
        closeStackTrace,
      );
    }
    Error.throwWithStackTrace(error, stackTrace);
  } finally {
    state.completeConsume();
  }
}

Future<void> _cancelOpaqueState(_KelivoOpaqueStateHandle state) async {
  final opaqueValue = state.beginConsume();
  try {
    await Isolate.run(() {
      _throwOnError(
        operation: 'opaque_client_state_close',
        statusCode: native.kelivo_opaque_client_state_close(opaqueValue),
      );
    });
  } finally {
    state.completeConsume();
  }
}

void _closeConsumedOpaqueState(int opaqueValue) {
  final status = KelivoSecureCoreStatus.fromCode(
    native.kelivo_opaque_client_state_close(opaqueValue),
  );
  if (status == KelivoSecureCoreStatus.ok ||
      status == KelivoSecureCoreStatus.invalidOpaqueStateHandle) {
    return;
  }
  throw KelivoSecureCoreException(
    operation: 'opaque_client_state_close_after_failure',
    status: status,
  );
}

_OpaqueStartNativeResult _opaqueRegistrationStart(Uint8List password) =>
    _opaqueClientStart(password, registration: true);

_OpaqueStartNativeResult _opaqueLoginStart(Uint8List password) =>
    _opaqueClientStart(password, registration: false);

_OpaqueStartNativeResult _opaqueClientStart(
  Uint8List password, {
  required bool registration,
}) {
  final outputSize = registration
      ? _opaqueRegistrationRequestSize
      : _opaqueCredentialRequestSize;
  ffi.Pointer<ffi.Uint8>? passwordPointer;
  ffi.Pointer<ffi.Uint64>? outputHandle;
  ffi.Pointer<ffi.Size>? outputLength;
  ffi.Pointer<ffi.Uint8>? output;
  var preserveHandle = false;
  try {
    passwordPointer = _copyToNative(password);
    outputHandle = calloc<ffi.Uint64>();
    outputLength = calloc<ffi.Size>();
    output = calloc<ffi.Uint8>(outputSize);
    final statusCode = registration
        ? native.kelivo_opaque_client_registration_start(
            passwordPointer,
            password.length,
            outputHandle,
            output,
            outputSize,
            outputLength,
          )
        : native.kelivo_opaque_client_login_start(
            passwordPointer,
            password.length,
            outputHandle,
            output,
            outputSize,
            outputLength,
          );
    _throwOnError(
      operation: registration
          ? 'opaque_client_registration_start'
          : 'opaque_client_login_start',
      statusCode: statusCode,
    );
    if (outputHandle.value == _opaqueInvalidStateHandle) {
      throw StateError('OPAQUE 客户端开始操作返回了无效状态句柄');
    }
    _requireExactOutputLength(
      operation: registration
          ? 'opaque_client_registration_start'
          : 'opaque_client_login_start',
      expected: outputSize,
      actual: outputLength.value,
    );
    final result = _OpaqueStartNativeResult(
      handle: outputHandle.value,
      message: Uint8List.fromList(output.asTypedList(outputSize)),
    );
    preserveHandle = true;
    return result;
  } finally {
    final danglingHandle =
        !preserveHandle &&
            outputHandle != null &&
            outputHandle.value != _opaqueInvalidStateHandle
        ? outputHandle.value
        : null;
    final closeStatus = danglingHandle == null
        ? null
        : native.kelivo_opaque_client_state_close(danglingHandle);
    if (passwordPointer != null) {
      _clearAndFree(passwordPointer, password.length);
    }
    password.fillRange(0, password.length, 0);
    if (output != null) {
      _clearAndFree(output, outputSize);
    }
    if (outputHandle != null) {
      calloc.free(outputHandle);
    }
    if (outputLength != null) {
      calloc.free(outputLength);
    }
    if (closeStatus != null) {
      _throwOnError(
        operation: 'opaque_client_state_close_after_start_failure',
        statusCode: closeStatus,
      );
    }
  }
}

Uint8List _opaqueRegistrationFinish(
  int stateHandle,
  Uint8List password,
  Uint8List response,
  Uint8List accountId,
) => _opaqueClientFinish(
  stateHandle,
  password,
  response,
  accountId,
  registration: true,
);

Uint8List _opaqueLoginFinish(
  int stateHandle,
  Uint8List password,
  Uint8List response,
  Uint8List accountId,
) => _opaqueClientFinish(
  stateHandle,
  password,
  response,
  accountId,
  registration: false,
);

Uint8List _opaqueClientFinish(
  int stateHandle,
  Uint8List password,
  Uint8List response,
  Uint8List accountId, {
  required bool registration,
}) {
  final outputSize = registration
      ? _opaqueRegistrationUploadSize
      : _opaqueCredentialFinalizationSize;
  ffi.Pointer<ffi.Uint8>? passwordPointer;
  ffi.Pointer<ffi.Uint8>? responsePointer;
  ffi.Pointer<ffi.Uint8>? accountIdPointer;
  ffi.Pointer<ffi.Size>? outputLength;
  ffi.Pointer<ffi.Uint8>? output;
  try {
    passwordPointer = _copyToNative(password);
    responsePointer = _copyToNative(response);
    accountIdPointer = _copyToNative(accountId);
    outputLength = calloc<ffi.Size>();
    output = calloc<ffi.Uint8>(outputSize);
    final statusCode = registration
        ? native.kelivo_opaque_client_registration_finish(
            stateHandle,
            passwordPointer,
            password.length,
            responsePointer,
            response.length,
            accountIdPointer,
            accountId.length,
            output,
            outputSize,
            outputLength,
          )
        : native.kelivo_opaque_client_login_finish(
            stateHandle,
            passwordPointer,
            password.length,
            responsePointer,
            response.length,
            accountIdPointer,
            accountId.length,
            output,
            outputSize,
            outputLength,
          );
    _throwOnError(
      operation: registration
          ? 'opaque_client_registration_finish'
          : 'opaque_client_login_finish',
      statusCode: statusCode,
    );
    _requireExactOutputLength(
      operation: registration
          ? 'opaque_client_registration_finish'
          : 'opaque_client_login_finish',
      expected: outputSize,
      actual: outputLength.value,
    );
    return Uint8List.fromList(output.asTypedList(outputSize));
  } finally {
    if (passwordPointer != null) {
      _clearAndFree(passwordPointer, password.length);
    }
    if (responsePointer != null) {
      _clearAndFree(responsePointer, response.length);
    }
    if (accountIdPointer != null) {
      _clearAndFree(accountIdPointer, accountId.length);
    }
    if (output != null) {
      _clearAndFree(output, outputSize);
    }
    password.fillRange(0, password.length, 0);
    response.fillRange(0, response.length, 0);
    accountId.fillRange(0, accountId.length, 0);
    if (outputLength != null) {
      calloc.free(outputLength);
    }
  }
}

Uint8List _validateDatabasePath(String databasePath) {
  final bytes = utf8.encode(databasePath);
  if (bytes.isEmpty ||
      bytes.length > _databasePathMaxLength ||
      databasePath.contains('\u0000')) {
    throw ArgumentError.value(databasePath, 'databasePath', '数据库路径无效');
  }
  return Uint8List.fromList(bytes);
}

Uint8List _validateDatabaseName(String databaseName) {
  final bytes = utf8.encode(databaseName);
  final isIdentifier = RegExp(
    r'^[A-Za-z_][A-Za-z0-9_]*$',
  ).hasMatch(databaseName);
  final normalized = databaseName.toLowerCase();
  if (!isIdentifier ||
      bytes.isEmpty ||
      bytes.length > _databaseNameMaxLength ||
      normalized == 'main' ||
      normalized == 'temp') {
    throw ArgumentError.value(databaseName, 'databaseName', '命名数据库别名无效');
  }
  return Uint8List.fromList(bytes);
}

KelivoCoreCapabilities _readCapabilities() {
  final reportedAbiVersion = native.kelivo_core_abi_version();
  if (reportedAbiVersion != _expectedAbiVersion) {
    throw StateError(
      '安全核心 ABI 不匹配：期望 $_expectedAbiVersion，实际 $reportedAbiVersion',
    );
  }

  final expectedStructSize = ffi.sizeOf<native.KelivoCoreCapabilities>();
  final output = calloc<native.KelivoCoreCapabilities>();
  try {
    _throwOnError(
      operation: 'core_get_capabilities',
      statusCode: native.kelivo_core_get_capabilities(
        output,
        expectedStructSize,
      ),
    );

    final capabilities = output.ref;
    if (capabilities.struct_size != expectedStructSize) {
      throw StateError(
        '安全核心能力结构大小不匹配：'
        '期望 $expectedStructSize，实际 ${capabilities.struct_size}',
      );
    }
    if (capabilities.abi_version != _expectedAbiVersion) {
      throw StateError(
        '安全核心能力 ABI 不匹配：'
        '期望 $_expectedAbiVersion，实际 ${capabilities.abi_version}',
      );
    }
    if (capabilities.flags & ~_knownCapabilityFlags != 0) {
      throw StateError('安全核心返回了未知能力标志：${capabilities.flags}');
    }

    final backend = KelivoSecureStorageBackend.fromCode(
      capabilities.secure_storage_backend,
    );
    if (backend == KelivoSecureStorageBackend.none &&
        capabilities.flags & _secureStorageCapabilityFlags != 0) {
      throw StateError('安全核心在无安全存储后端时声明了密钥能力');
    }
    if (capabilities.flags & _recordEnvelopesCapability != 0 &&
        capabilities.flags & _keySlotsCapability == 0) {
      throw StateError('安全核心在不支持密钥槽位时声明了记录信封能力');
    }
    if (capabilities.flags & _sqlCipherKeyApplicationCapability != 0 &&
        (capabilities.flags & _keySlotsCapability == 0 ||
            capabilities.flags & _backgroundAccessCapability == 0)) {
      throw StateError('安全核心在缺少后台密钥槽位时声明了 SQLCipher 设键能力');
    }

    return KelivoCoreCapabilities(
      abiVersion: capabilities.abi_version,
      backend: backend,
      supportsKeySlots: capabilities.flags & _keySlotsCapability != 0,
      supportsBackgroundAccess:
          capabilities.flags & _backgroundAccessCapability != 0,
      supportsRecordEnvelopes:
          capabilities.flags & _recordEnvelopesCapability != 0,
      supportsSqlCipherKeyApplication:
          capabilities.flags & _sqlCipherKeyApplicationCapability != 0,
      supportsSqlCipherDatabaseAttach:
          capabilities.flags & _sqlCipherDatabaseAttachCapability != 0,
      supportsOpaqueClient: capabilities.flags & _opaqueClientCapability != 0,
    );
  } finally {
    calloc.free(output);
  }
}

KelivoKeyHandle _openOrCreateKeySlot(Uint8List slotId) {
  try {
    return _openKeySlot(slotId, create: true);
  } on KelivoSecureCoreException catch (error) {
    if (error.status != KelivoSecureCoreStatus.slotAlreadyExists) rethrow;
    return _openKeySlot(slotId, create: false);
  }
}

void _runWithSynchronousKeyHandle(
  KelivoKeyHandle handle,
  void Function(int opaqueValue) action,
) {
  final opaqueValue = handle._requireOpen();
  try {
    action(opaqueValue);
  } catch (error, stackTrace) {
    try {
      _throwOnError(
        operation: 'key_handle_close',
        statusCode: native.kelivo_key_handle_close(opaqueValue),
      );
      handle._completeClose();
    } catch (closeError, closeStackTrace) {
      Error.throwWithStackTrace(
        StateError('同步密钥操作失败且句柄关闭失败：$error；$closeError'),
        closeStackTrace,
      );
    }
    Error.throwWithStackTrace(error, stackTrace);
  }
  _throwOnError(
    operation: 'key_handle_close',
    statusCode: native.kelivo_key_handle_close(opaqueValue),
  );
  handle._completeClose();
}

KelivoKeyHandle _openKeySlot(Uint8List slotId, {required bool create}) {
  if (slotId.length != _keySlotIdLength) {
    throw ArgumentError.value(
      slotId.length,
      'slotId',
      '槽位标识必须为 $_keySlotIdLength 字节',
    );
  }

  final slotIdPointer = calloc<ffi.Uint8>(slotId.length);
  final output = calloc<ffi.Uint64>();
  try {
    slotIdPointer.asTypedList(slotId.length).setAll(0, slotId);
    final statusCode = create
        ? native.kelivo_key_slot_create(
            slotIdPointer,
            slotId.length,
            _keyPolicyVersion,
            output,
          )
        : native.kelivo_key_slot_open(
            slotIdPointer,
            slotId.length,
            _keyPolicyVersion,
            output,
          );
    _throwOnError(
      operation: create ? 'key_slot_create' : 'key_slot_open',
      statusCode: statusCode,
    );
    if (output.value == 0) {
      throw StateError('安全核心成功返回了无效密钥句柄');
    }
    return KelivoKeyHandle._(output.value);
  } finally {
    slotIdPointer.asTypedList(slotId.length).fillRange(0, slotId.length, 0);
    calloc.free(slotIdPointer);
    calloc.free(output);
  }
}

void _validateRecordContext({
  required Uint8List recordId,
  required int epoch,
  required Uint8List associatedData,
}) {
  if (recordId.length != _recordIdLength) {
    throw ArgumentError.value(
      recordId.length,
      'recordId',
      '记录标识必须为 $_recordIdLength 字节',
    );
  }
  if (epoch <= 0 || epoch > _recordMaxEpoch) {
    throw ArgumentError.value(epoch, 'epoch', '密钥世代必须在正 63 位整数范围内');
  }
  if (associatedData.length > _recordMaxAssociatedDataSize) {
    throw ArgumentError.value(
      associatedData.length,
      'associatedData',
      '关联数据不得超过 $_recordMaxAssociatedDataSize 字节',
    );
  }
}

Uint8List _sealRecord(
  int handle,
  Uint8List recordId,
  int epoch,
  Uint8List associatedData,
  Uint8List plaintext,
) {
  final recordIdPointer = _copyToNative(recordId);
  final associatedDataPointer = _copyToNative(associatedData);
  final plaintextPointer = _copyToNative(plaintext);
  final outputLength = calloc<ffi.Size>();
  try {
    final queryStatus = native.kelivo_record_seal(
      handle,
      recordIdPointer,
      recordId.length,
      epoch,
      associatedDataPointer,
      associatedData.length,
      plaintextPointer,
      plaintext.length,
      ffi.nullptr,
      0,
      outputLength,
    );
    final required = _readRequiredOutputLength(
      operation: 'record_seal_size',
      statusCode: queryStatus,
      outputLength: outputLength.value,
      allowEmpty: false,
      maxLength: _recordMaxEnvelopeSize,
    );
    final output = calloc<ffi.Uint8>(required);
    try {
      _throwOnError(
        operation: 'record_seal',
        statusCode: native.kelivo_record_seal(
          handle,
          recordIdPointer,
          recordId.length,
          epoch,
          associatedDataPointer,
          associatedData.length,
          plaintextPointer,
          plaintext.length,
          output,
          required,
          outputLength,
        ),
      );
      _requireExactOutputLength(
        operation: 'record_seal',
        expected: required,
        actual: outputLength.value,
      );
      return Uint8List.fromList(output.asTypedList(required));
    } finally {
      _clearAndFree(output, required);
    }
  } finally {
    _clearAndFree(recordIdPointer, recordId.length);
    _clearAndFree(associatedDataPointer, associatedData.length);
    _clearAndFree(plaintextPointer, plaintext.length);
    recordId.fillRange(0, recordId.length, 0);
    associatedData.fillRange(0, associatedData.length, 0);
    plaintext.fillRange(0, plaintext.length, 0);
    calloc.free(outputLength);
  }
}

Uint8List _openRecord(
  int handle,
  Uint8List recordId,
  int epoch,
  Uint8List associatedData,
  Uint8List envelope,
) {
  final recordIdPointer = _copyToNative(recordId);
  final associatedDataPointer = _copyToNative(associatedData);
  final envelopePointer = _copyToNative(envelope);
  final outputLength = calloc<ffi.Size>();
  try {
    final queryStatus = native.kelivo_record_open(
      handle,
      recordIdPointer,
      recordId.length,
      epoch,
      associatedDataPointer,
      associatedData.length,
      envelopePointer,
      envelope.length,
      ffi.nullptr,
      0,
      outputLength,
    );
    final required = _readRequiredOutputLength(
      operation: 'record_open_size',
      statusCode: queryStatus,
      outputLength: outputLength.value,
      allowEmpty: true,
      maxLength: _recordMaxPlaintextSize,
    );
    if (required == 0) return Uint8List(0);

    final output = calloc<ffi.Uint8>(required);
    try {
      _throwOnError(
        operation: 'record_open',
        statusCode: native.kelivo_record_open(
          handle,
          recordIdPointer,
          recordId.length,
          epoch,
          associatedDataPointer,
          associatedData.length,
          envelopePointer,
          envelope.length,
          output,
          required,
          outputLength,
        ),
      );
      _requireExactOutputLength(
        operation: 'record_open',
        expected: required,
        actual: outputLength.value,
      );
      return Uint8List.fromList(output.asTypedList(required));
    } finally {
      _clearAndFree(output, required);
    }
  } finally {
    _clearAndFree(recordIdPointer, recordId.length);
    _clearAndFree(associatedDataPointer, associatedData.length);
    _clearAndFree(envelopePointer, envelope.length);
    recordId.fillRange(0, recordId.length, 0);
    associatedData.fillRange(0, associatedData.length, 0);
    envelope.fillRange(0, envelope.length, 0);
    calloc.free(outputLength);
  }
}

ffi.Pointer<ffi.Uint8> _copyToNative(Uint8List bytes) {
  final pointer = calloc<ffi.Uint8>(bytes.isEmpty ? 1 : bytes.length);
  try {
    if (bytes.isNotEmpty) {
      pointer.asTypedList(bytes.length).setAll(0, bytes);
    }
    return pointer;
  } catch (_) {
    _clearAndFree(pointer, bytes.length);
    rethrow;
  }
}

void _clearAndFree(ffi.Pointer<ffi.Uint8> pointer, int length) {
  if (length > 0) {
    pointer.asTypedList(length).fillRange(0, length, 0);
  }
  calloc.free(pointer);
}

int _readRequiredOutputLength({
  required String operation,
  required int statusCode,
  required int outputLength,
  required bool allowEmpty,
  required int maxLength,
}) {
  final status = KelivoSecureCoreStatus.fromCode(statusCode);
  if (status == KelivoSecureCoreStatus.outputBufferTooSmall &&
      outputLength > 0 &&
      outputLength <= maxLength) {
    return outputLength;
  }
  if (allowEmpty && status == KelivoSecureCoreStatus.ok && outputLength == 0) {
    return 0;
  }
  if (status != KelivoSecureCoreStatus.ok &&
      status != KelivoSecureCoreStatus.outputBufferTooSmall) {
    throw KelivoSecureCoreException(operation: operation, status: status);
  }
  throw StateError('$operation 返回了无效输出长度：$outputLength');
}

void _requireExactOutputLength({
  required String operation,
  required int expected,
  required int actual,
}) {
  if (actual != expected) {
    throw StateError('$operation 输出长度不一致：期望 $expected，实际 $actual');
  }
}

void _throwOnError({required String operation, required int statusCode}) {
  final status = KelivoSecureCoreStatus.fromCode(statusCode);
  if (status == KelivoSecureCoreStatus.ok) return;
  throw KelivoSecureCoreException(operation: operation, status: status);
}
