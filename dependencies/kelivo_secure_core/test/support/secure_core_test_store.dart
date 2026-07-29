import 'dart:ffi' as ffi;

import 'package:ffi/ffi.dart';

const _testStoreRequested = bool.fromEnvironment(
  'KELIVO_SECURE_CORE_TEST_STORE',
);
const _nativeAssetId =
    'package:kelivo_secure_core/kelivo_secure_core_bindings_generated.dart';

@ffi.Native<ffi.Int32 Function(ffi.Pointer<ffi.Uint64>)>(
  symbol: 'kelivo_test_key_slot_store_open',
  assetId: _nativeAssetId,
)
external int _openNativeTestStore(ffi.Pointer<ffi.Uint64> outScope);

@ffi.Native<ffi.Int32 Function(ffi.Uint64)>(
  symbol: 'kelivo_test_key_slot_store_close',
  assetId: _nativeAssetId,
)
external int _closeNativeTestStore(int scope);

final class SecureCoreTestStoreScope {
  SecureCoreTestStoreScope._(this._scope);

  final int _scope;
  bool _closed = false;

  static SecureCoreTestStoreScope open() {
    if (!_testStoreRequested) {
      throw StateError('安全核心槽测试必须通过显式测试入口运行');
    }
    final outScope = calloc<ffi.Uint64>();
    try {
      final status = _openNativeTestStore(outScope);
      if (status != 0 || outScope.value == 0) {
        throw StateError('安全核心测试存储开启失败，状态码：$status');
      }
      return SecureCoreTestStoreScope._(outScope.value);
    } finally {
      calloc.free(outScope);
    }
  }

  void close() {
    if (_closed) {
      return;
    }
    final status = _closeNativeTestStore(_scope);
    if (status != 0) {
      throw StateError('安全核心测试存储关闭失败，状态码：$status');
    }
    _closed = true;
  }
}
