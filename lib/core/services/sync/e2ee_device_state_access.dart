import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:kelivo_secure_core/kelivo_secure_core.dart';

import '../workspace/device_state_blob_store.dart';
import 'cloud_sync_types.dart';

final class E2eeOpenedDeviceStateHandles {
  const E2eeOpenedDeviceStateHandles({
    required this.key,
    required this.identity,
    required this.ark,
    required this.binding,
  });

  final KelivoKeyHandle key;
  final KelivoDeviceIdentityHandle identity;
  final KelivoAccountRootKeyHandle? ark;
  final KelivoDeviceStateBinding binding;
}

final class E2eeDeviceStateAccess {
  factory E2eeDeviceStateAccess({
    required String baseUrl,
    required DeviceStateBlobStore deviceStateStore,
    required KelivoSecureCore secureCore,
  }) {
    return E2eeDeviceStateAccess._(
      normalizeCloudSyncBaseUrl(baseUrl),
      deviceStateStore,
      secureCore,
    );
  }

  E2eeDeviceStateAccess._(
    this._baseUrl,
    this._deviceStateStore,
    this._secureCore,
  );

  static const _slotDomain = 'kelivo.e2ee.device-state.slot.v1';

  final String _baseUrl;
  final DeviceStateBlobStore _deviceStateStore;
  final KelivoSecureCore _secureCore;

  Future<E2eeOpenedDeviceStateHandles?> openExisting(
    String normalizedLoginName,
  ) async {
    final stateBlob = await _deviceStateStore.read(
      normalizedBaseUrl: _baseUrl,
      normalizedLoginName: normalizedLoginName,
    );
    if (stateBlob == null) return null;

    KelivoKeyHandle? key;
    try {
      key = await _secureCore.openSlot(
        deriveSlotId(
          normalizedBaseUrl: _baseUrl,
          normalizedLoginName: normalizedLoginName,
        ),
      );
      final opened = await _secureCore.openDeviceState(
        key,
        stateBlob: stateBlob,
      );
      return E2eeOpenedDeviceStateHandles(
        key: key,
        identity: opened.identity,
        ark: opened.ark,
        binding: opened.binding,
      );
    } catch (error, stackTrace) {
      if (key != null) {
        try {
          await _secureCore.close(key);
        } catch (cleanupError, cleanupStackTrace) {
          developer.log(
            'E2EE 设备状态打开失败后的密钥槽清理失败',
            name: 'Kelivo.E2eeDeviceStateAccess',
            error: cleanupError,
            stackTrace: cleanupStackTrace,
          );
        }
      }
      Error.throwWithStackTrace(error, stackTrace);
    } finally {
      stateBlob.fillRange(0, stateBlob.length, 0);
    }
  }

  Future<KelivoKeyHandle> openOrCreateSlot(String normalizedLoginName) async {
    final slotId = deriveSlotId(
      normalizedBaseUrl: _baseUrl,
      normalizedLoginName: normalizedLoginName,
    );
    try {
      return await _secureCore.createSlot(slotId);
    } on KelivoSecureCoreException catch (error) {
      if (error.status != KelivoSecureCoreStatus.slotAlreadyExists) rethrow;
      return _secureCore.openSlot(slotId);
    }
  }

  static Uint8List deriveSlotId({
    required String normalizedBaseUrl,
    required String normalizedLoginName,
  }) {
    final digest = sha256.convert(
      utf8.encode(
        '$_slotDomain\u0000$normalizedBaseUrl\u0000$normalizedLoginName',
      ),
    );
    return Uint8List.fromList(digest.bytes.sublist(0, 16));
  }
}
