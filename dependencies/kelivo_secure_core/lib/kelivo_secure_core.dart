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
const _knownCapabilityFlags = _keySlotsCapability | _backgroundAccessCapability;

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
  });

  final int abiVersion;
  final KelivoSecureStorageBackend backend;
  final bool supportsKeySlots;
  final bool supportsBackgroundAccess;
}

final class KelivoKeyHandle {
  KelivoKeyHandle._(this._value);

  final int _value;
  _KelivoKeyHandleState _state = _KelivoKeyHandleState.open;

  int _beginClose() {
    if (_state != _KelivoKeyHandleState.open) {
      throw StateError('密钥句柄已关闭或正在关闭');
    }
    _state = _KelivoKeyHandleState.closing;
    return _value;
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

    return KelivoCoreCapabilities(
      abiVersion: capabilities.abi_version,
      backend: backend,
      supportsKeySlots: capabilities.flags & _keySlotsCapability != 0,
      supportsBackgroundAccess:
          capabilities.flags & _backgroundAccessCapability != 0,
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

void _throwOnError({required String operation, required int statusCode}) {
  final status = KelivoSecureCoreStatus.fromCode(statusCode);
  if (status == KelivoSecureCoreStatus.ok) return;
  throw KelivoSecureCoreException(operation: operation, status: status);
}
