library;

import 'dart:ffi' as ffi;
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'kelivo_secure_core_bindings_generated.dart' as native;

const _expectedAbiVersion = 1;
const _keySlotIdLength = 16;
const _keyPolicyVersion = 1;
const _keySlotsCapability = 1 << 0;
const _backgroundAccessCapability = 1 << 1;
const _recordEnvelopesCapability = 1 << 2;
const _knownCapabilityFlags =
    _keySlotsCapability |
    _backgroundAccessCapability |
    _recordEnvelopesCapability;
const _recordIdLength = native.KELIVO_RECORD_ID_SIZE;
const _recordMaxAssociatedDataSize =
    native.KELIVO_RECORD_MAX_ASSOCIATED_DATA_SIZE;
const _recordMaxPlaintextSize = native.KELIVO_RECORD_MAX_PLAINTEXT_SIZE;
const _recordMaxEnvelopeSize = native.KELIVO_RECORD_MAX_ENVELOPE_SIZE;
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
  });

  final int abiVersion;
  final KelivoSecureStorageBackend backend;
  final bool supportsKeySlots;
  final bool supportsBackgroundAccess;
  final bool supportsRecordEnvelopes;
}

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
    if (backend == KelivoSecureStorageBackend.none && capabilities.flags != 0) {
      throw StateError('安全核心在无安全存储后端时声明了密钥能力');
    }
    if (capabilities.flags & _recordEnvelopesCapability != 0 &&
        capabilities.flags & _keySlotsCapability == 0) {
      throw StateError('安全核心在不支持密钥槽位时声明了记录信封能力');
    }

    return KelivoCoreCapabilities(
      abiVersion: capabilities.abi_version,
      backend: backend,
      supportsKeySlots: capabilities.flags & _keySlotsCapability != 0,
      supportsBackgroundAccess:
          capabilities.flags & _backgroundAccessCapability != 0,
      supportsRecordEnvelopes:
          capabilities.flags & _recordEnvelopesCapability != 0,
    );
  } finally {
    calloc.free(output);
  }
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
  if (bytes.isNotEmpty) {
    pointer.asTypedList(bytes.length).setAll(0, bytes);
  }
  return pointer;
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
