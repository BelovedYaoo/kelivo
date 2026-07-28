import 'dart:async';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:kelivo_secure_core/kelivo_secure_core.dart';
import 'package:uuid/uuid.dart';

import '../workspace/device_state_blob_store.dart';
import 'cloud_sync_types.dart';
import 'e2ee_account_key_lease.dart';
import 'e2ee_account_record_cipher.dart';
import 'e2ee_attachment_manifest.dart';

abstract interface class E2eeAttachmentCrypto {
  int get keyEpoch;

  Future<E2eeSealedAttachmentManifest> sealManifest({
    required E2eeAttachmentDescriptor descriptor,
    required String uploadId,
  });

  Future<E2eeAttachmentManifest> openManifest({
    required String attachmentId,
    required String uploadId,
    required int keyEpoch,
    required Uint8List ciphertext,
  });

  Future<Uint8List> sealChunk({
    required E2eeAttachmentDescriptor descriptor,
    required String uploadId,
    required int chunkIndex,
    required Uint8List plaintext,
  });

  Future<Uint8List> openChunk({
    required E2eeAttachmentDescriptor descriptor,
    required String uploadId,
    required int chunkIndex,
    required Uint8List ciphertext,
  });

  Future<void> close();
}

final class E2eeAttachmentCryptoSession implements E2eeAttachmentCrypto {
  E2eeAttachmentCryptoSession._({
    required this._secureCore,
    required this._manifestCipher,
    required this._chunkAccountRootKey,
    required Uint8List userId,
    required this.keyEpoch,
  }) : _userId = Uint8List.fromList(userId).asUnmodifiableView();

  final KelivoSecureCore _secureCore;
  final E2eeAttachmentManifestCipher _manifestCipher;
  final KelivoAccountRootKeyHandle _chunkAccountRootKey;
  final Uint8List _userId;
  @override
  final int keyEpoch;
  final List<KelivoAttachmentDataKeyHandle> _retainedDataKeys =
      <KelivoAttachmentDataKeyHandle>[];

  Future<void> _operationTail = Future<void>.value();
  bool _acceptingOperations = true;
  bool _closed = false;
  bool _manifestCipherClosed = false;
  bool _chunkAccountRootKeyClosed = false;
  Future<void>? _closeFuture;

  static Future<E2eeAttachmentCryptoSession> open({
    required CloudSyncAccountSession session,
    required DeviceStateBlobStore deviceStateStore,
    required KelivoSecureCore secureCore,
  }) async {
    E2eeAccountKeyLease? manifestLease;
    E2eeAccountKeyLease? chunkLease;
    KelivoAccountRootKeyHandle? manifestArk;
    KelivoAccountRootKeyHandle? chunkArk;
    E2eeAttachmentManifestCipher? manifestCipher;
    try {
      // 两次独立打开让记录加密与附件分块永远不共享同一个可变原生句柄。
      manifestLease = await E2eeAccountKeyLease.open(
        session: session,
        deviceStateStore: deviceStateStore,
        secureCore: secureCore,
      );
      chunkLease = await E2eeAccountKeyLease.open(
        session: session,
        deviceStateStore: deviceStateStore,
        secureCore: secureCore,
      );

      manifestArk = manifestLease.takeAccountRootKeyOwnership();
      final recordCipher = E2eeAccountRecordCipher.takeOwnership(
        secureCore: secureCore,
        accountRootKey: manifestArk,
        userId: session.userId,
        currentKeyEpoch: session.keyEpoch,
      );
      manifestArk = null;
      manifestCipher = E2eeAttachmentManifestCipher.takeOwnership(recordCipher);

      chunkArk = chunkLease.takeAccountRootKeyOwnership();
      final opened = E2eeAttachmentCryptoSession._(
        secureCore: secureCore,
        manifestCipher: manifestCipher,
        chunkAccountRootKey: chunkArk,
        userId: _canonicalUuidBytes(session.userId, 'userId'),
        keyEpoch: session.keyEpoch,
      );
      manifestCipher = null;
      chunkArk = null;
      await manifestLease.close();
      await chunkLease.close();
      return opened;
    } catch (error, stackTrace) {
      await _cleanupOpenFailure(
        secureCore: secureCore,
        manifestLease: manifestLease,
        chunkLease: chunkLease,
        manifestArk: manifestArk,
        chunkArk: chunkArk,
        manifestCipher: manifestCipher,
      );
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  @override
  Future<E2eeSealedAttachmentManifest> sealManifest({
    required E2eeAttachmentDescriptor descriptor,
    required String uploadId,
  }) {
    return _runWhileOpen(() {
      _requireCurrentDescriptorEpoch(descriptor);
      return _manifestCipher.seal(
        E2eeAttachmentManifest.fromDescriptor(
          descriptor: descriptor,
          uploadId: uploadId,
        ),
      );
    });
  }

  @override
  Future<E2eeAttachmentManifest> openManifest({
    required String attachmentId,
    required String uploadId,
    required int keyEpoch,
    required Uint8List ciphertext,
  }) {
    return _runWhileOpen(() {
      if (keyEpoch <= 0 || keyEpoch > this.keyEpoch) {
        throw const FormatException('附件清单密钥世代晚于密码会话或无效');
      }
      return _manifestCipher.open(
        attachmentId: attachmentId,
        uploadId: uploadId,
        keyEpoch: keyEpoch,
        ciphertext: ciphertext,
      );
    });
  }

  @override
  Future<Uint8List> sealChunk({
    required E2eeAttachmentDescriptor descriptor,
    required String uploadId,
    required int chunkIndex,
    required Uint8List plaintext,
  }) {
    return _runWhileOpen(() async {
      return _withDataKey(
        descriptor: descriptor,
        uploadId: uploadId,
        allowHistoricalEpoch: false,
        operation: (dataKey, context, layout) {
          return _secureCore.sealAttachmentChunk(
            dataKey,
            uploadContext: context,
            layout: layout,
            chunkIndex: chunkIndex,
            plaintext: plaintext,
          );
        },
      );
    });
  }

  @override
  Future<Uint8List> openChunk({
    required E2eeAttachmentDescriptor descriptor,
    required String uploadId,
    required int chunkIndex,
    required Uint8List ciphertext,
  }) {
    return _runWhileOpen(() async {
      return _withDataKey(
        descriptor: descriptor,
        uploadId: uploadId,
        allowHistoricalEpoch: true,
        operation: (dataKey, context, layout) {
          return _secureCore.openAttachmentChunk(
            dataKey,
            uploadContext: context,
            layout: layout,
            chunkIndex: chunkIndex,
            envelope: ciphertext,
          );
        },
      );
    });
  }

  @override
  Future<void> close() {
    if (_closed) return Future<void>.value();
    final active = _closeFuture;
    if (active != null) return active;
    _acceptingOperations = false;
    late final Future<void> closing;
    closing = () async {
      try {
        await _closeAfterOperations();
        _closed = true;
      } finally {
        if (identical(_closeFuture, closing)) _closeFuture = null;
      }
    }();
    _closeFuture = closing;
    return closing;
  }

  Future<T> _runWhileOpen<T>(Future<T> Function() operation) {
    if (!_acceptingOperations) {
      return Future<T>.error(StateError('E2EE 附件密码会话已经关闭'));
    }
    final previous = _operationTail;
    final completed = Completer<void>();
    _operationTail = completed.future;
    return () async {
      await previous;
      try {
        return await operation();
      } finally {
        completed.complete();
      }
    }();
  }

  KelivoAttachmentUploadContext _uploadContext(
    E2eeAttachmentDescriptor descriptor,
    String uploadId,
    bool allowHistoricalEpoch,
  ) {
    if (allowHistoricalEpoch) {
      _requireReadableDescriptorEpoch(descriptor);
    } else {
      _requireCurrentDescriptorEpoch(descriptor);
    }
    return KelivoAttachmentUploadContext(
      attachment: KelivoAttachmentContext(
        userId: _userId,
        attachmentId: _canonicalUuidBytes(
          descriptor.attachmentId,
          'attachmentId',
        ),
        keyEpoch: descriptor.keyEpoch,
      ),
      uploadId: _canonicalUuidBytes(uploadId, 'uploadId'),
    );
  }

  void _requireCurrentDescriptorEpoch(E2eeAttachmentDescriptor descriptor) {
    if (descriptor.keyEpoch != keyEpoch) {
      throw const FormatException('附件描述密钥世代与密码会话不一致');
    }
  }

  void _requireReadableDescriptorEpoch(E2eeAttachmentDescriptor descriptor) {
    if (descriptor.keyEpoch > keyEpoch) {
      throw const FormatException('附件描述密钥世代晚于密码会话');
    }
  }

  Future<T> _withDataKey<T>({
    required E2eeAttachmentDescriptor descriptor,
    required String uploadId,
    required bool allowHistoricalEpoch,
    required Future<T> Function(
      KelivoAttachmentDataKeyHandle dataKey,
      KelivoAttachmentUploadContext context,
      KelivoAttachmentLayout layout,
    )
    operation,
  }) async {
    await _closeRetainedDataKeys();
    final context = _uploadContext(descriptor, uploadId, allowHistoricalEpoch);
    final layout = KelivoAttachmentLayout(
      totalPlaintextBytes: descriptor.totalPlaintextBytes,
    );
    final dataKey = await _secureCore.unwrapAttachmentDataKey(
      _chunkAccountRootKey,
      context: context.attachment,
      wrappedKey: descriptor.wrappedDataKey,
    );
    try {
      final result = await operation(dataKey, context, layout);
      try {
        await _closeDataKeyOrRetain(dataKey);
      } catch (_) {
        // 清理失败会取消本次结果，结果字节不能继续滞留在失去所有权的异步帧中。
        if (result is Uint8List) result.fillRange(0, result.length, 0);
        rethrow;
      }
      return result;
    } catch (error, stackTrace) {
      if (!_retainedDataKeys.contains(dataKey)) {
        try {
          await _closeDataKeyOrRetain(dataKey);
        } catch (cleanupError, cleanupStackTrace) {
          developer.log(
            'E2EE 附件密码操作失败后的数据密钥清理失败',
            name: 'Kelivo.E2eeAttachmentCryptoSession',
            error: cleanupError,
            stackTrace: cleanupStackTrace,
          );
        }
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> _closeDataKeyOrRetain(
    KelivoAttachmentDataKeyHandle dataKey,
  ) async {
    try {
      await _secureCore.closeAttachmentDataKey(dataKey);
      _retainedDataKeys.remove(dataKey);
    } catch (_) {
      if (!_retainedDataKeys.contains(dataKey)) {
        _retainedDataKeys.add(dataKey);
      }
      rethrow;
    }
  }

  Future<void> _closeRetainedDataKeys() async {
    Object? firstError;
    StackTrace? firstStackTrace;
    for (final dataKey in List<KelivoAttachmentDataKeyHandle>.of(
      _retainedDataKeys,
    )) {
      try {
        await _closeDataKeyOrRetain(dataKey);
      } catch (error, stackTrace) {
        if (firstError == null) {
          firstError = error;
          firstStackTrace = stackTrace;
        } else {
          developer.log(
            'E2EE 附件密码会话关闭时的后续数据密钥清理失败',
            name: 'Kelivo.E2eeAttachmentCryptoSession',
            error: error,
            stackTrace: stackTrace,
          );
        }
      }
    }
    if (firstError != null && firstStackTrace != null) {
      Error.throwWithStackTrace(firstError, firstStackTrace);
    }
  }

  Future<void> _closeAfterOperations() async {
    await _operationTail;
    Object? firstError;
    StackTrace? firstStackTrace;
    final cleanup = <Future<void> Function()>[
      _closeRetainedDataKeys,
      _closeManifestCipher,
      _closeChunkAccountRootKey,
    ];
    for (final action in cleanup) {
      try {
        await action();
      } catch (error, stackTrace) {
        if (firstError == null) {
          firstError = error;
          firstStackTrace = stackTrace;
        } else {
          developer.log(
            'E2EE 附件密码会话关闭时的后续资源清理失败',
            name: 'Kelivo.E2eeAttachmentCryptoSession',
            error: error,
            stackTrace: stackTrace,
          );
        }
      }
    }
    if (firstError != null && firstStackTrace != null) {
      Error.throwWithStackTrace(firstError, firstStackTrace);
    }
  }

  Future<void> _closeManifestCipher() async {
    if (_manifestCipherClosed) return;
    await _manifestCipher.close();
    _manifestCipherClosed = true;
  }

  Future<void> _closeChunkAccountRootKey() async {
    if (_chunkAccountRootKeyClosed) return;
    await _secureCore.closeAccountRootKey(_chunkAccountRootKey);
    _chunkAccountRootKeyClosed = true;
  }
}

Future<void> _cleanupOpenFailure({
  required KelivoSecureCore secureCore,
  required E2eeAccountKeyLease? manifestLease,
  required E2eeAccountKeyLease? chunkLease,
  required KelivoAccountRootKeyHandle? manifestArk,
  required KelivoAccountRootKeyHandle? chunkArk,
  required E2eeAttachmentManifestCipher? manifestCipher,
}) async {
  final cleanup = <Future<void> Function()>[
    if (manifestCipher != null) manifestCipher.close,
    if (manifestArk != null) () => secureCore.closeAccountRootKey(manifestArk),
    if (chunkArk != null) () => secureCore.closeAccountRootKey(chunkArk),
    if (manifestLease != null) manifestLease.close,
    if (chunkLease != null) chunkLease.close,
  ];
  for (final action in cleanup) {
    try {
      await action();
    } catch (error, stackTrace) {
      developer.log(
        'E2EE 附件密码会话打开失败后的资源清理失败',
        name: 'Kelivo.E2eeAttachmentCryptoSession',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}

Uint8List _canonicalUuidBytes(String value, String field) {
  try {
    final bytes = Uint8List.fromList(Uuid.parseAsByteList(value));
    if (bytes.length != 16 ||
        (bytes[6] & 0xf0) != 0x40 ||
        (bytes[8] & 0xc0) != 0x80 ||
        Uuid.unparse(bytes) != value) {
      throw FormatException('$field 必须为规范小写 UUID v4');
    }
    return bytes;
  } on FormatException {
    throw FormatException('$field 必须为规范小写 UUID v4');
  }
}
