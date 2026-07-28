part of '../kelivo_secure_core.dart';

const _attachmentIdLength = native.KELIVO_ATTACHMENT_ID_SIZE;
const _attachmentWrappedKeyLength = native.KELIVO_ATTACHMENT_WRAPPED_KEY_SIZE;
const _attachmentChunkPlaintextSize =
    native.KELIVO_ATTACHMENT_CHUNK_PLAINTEXT_SIZE;
const _attachmentChunkEnvelopeOverhead =
    native.KELIVO_ATTACHMENT_CHUNK_ENVELOPE_OVERHEAD;
const _attachmentMaxChunkCount = native.KELIVO_ATTACHMENT_MAX_CHUNK_COUNT;
const _attachmentMaxTotalPlaintextBytes =
    native.KELIVO_ATTACHMENT_MAX_TOTAL_PLAINTEXT_BYTES;
const _attachmentMaxChunkEnvelopeSize =
    native.KELIVO_ATTACHMENT_MAX_CHUNK_ENVELOPE_SIZE;

abstract final class KelivoAttachmentLimits {
  static const int chunkPlaintextBytes = _attachmentChunkPlaintextSize;
  static const int chunkEnvelopeOverheadBytes =
      _attachmentChunkEnvelopeOverhead;
  static const int maxChunkCount = _attachmentMaxChunkCount;
  static const int maxTotalPlaintextBytes = _attachmentMaxTotalPlaintextBytes;
  static const int maxChunkEnvelopeBytes = _attachmentMaxChunkEnvelopeSize;
}

final class KelivoAttachmentLayout {
  factory KelivoAttachmentLayout({required int totalPlaintextBytes}) {
    if (totalPlaintextBytes < 0 ||
        totalPlaintextBytes > _attachmentMaxTotalPlaintextBytes) {
      throw ArgumentError.value(
        totalPlaintextBytes,
        'totalPlaintextBytes',
        '附件总明文长度必须在 0 至 $_attachmentMaxTotalPlaintextBytes 字节之间',
      );
    }
    final chunkCount = totalPlaintextBytes == 0
        ? 1
        : (totalPlaintextBytes + _attachmentChunkPlaintextSize - 1) ~/
              _attachmentChunkPlaintextSize;
    if (chunkCount > _attachmentMaxChunkCount) {
      throw ArgumentError.value(chunkCount, 'chunkCount', '附件分块数量超过安全上限');
    }
    return KelivoAttachmentLayout._(
      totalPlaintextBytes,
      chunkCount,
      totalPlaintextBytes + chunkCount * _attachmentChunkEnvelopeOverhead,
    );
  }

  const KelivoAttachmentLayout._(
    this.totalPlaintextBytes,
    this.chunkCount,
    this.totalCiphertextBytes,
  );

  final int totalPlaintextBytes;
  final int chunkCount;
  final int totalCiphertextBytes;

  int plaintextLengthForChunk(int chunkIndex) {
    if (chunkIndex < 0 || chunkIndex >= chunkCount) {
      throw RangeError.range(chunkIndex, 0, chunkCount - 1, 'chunkIndex');
    }
    if (totalPlaintextBytes == 0) return 0;
    final offset = chunkIndex * _attachmentChunkPlaintextSize;
    return (totalPlaintextBytes - offset).clamp(
      0,
      _attachmentChunkPlaintextSize,
    );
  }
}

final class KelivoAttachmentContext {
  factory KelivoAttachmentContext({
    required Uint8List userId,
    required Uint8List attachmentId,
    required int keyEpoch,
  }) {
    _validateUuidV4(userId, 'userId');
    _validateUuidV4(attachmentId, 'attachmentId');
    _validatePositiveUint32(keyEpoch, 'keyEpoch');
    return KelivoAttachmentContext._(
      _immutableDeviceBytes(userId),
      _immutableDeviceBytes(attachmentId),
      keyEpoch,
    );
  }

  const KelivoAttachmentContext._(
    this.userId,
    this.attachmentId,
    this.keyEpoch,
  );

  final Uint8List userId;
  final Uint8List attachmentId;
  final int keyEpoch;
}

final class KelivoAttachmentUploadContext {
  factory KelivoAttachmentUploadContext({
    required KelivoAttachmentContext attachment,
    required Uint8List uploadId,
  }) {
    _validateUuidV4(uploadId, 'uploadId');
    return KelivoAttachmentUploadContext._(
      attachment,
      _immutableDeviceBytes(uploadId),
    );
  }

  const KelivoAttachmentUploadContext._(this.attachment, this.uploadId);

  final KelivoAttachmentContext attachment;
  final Uint8List uploadId;
}

enum _AttachmentDataKeyPhase { open, busy, closing, closed }

final class _AttachmentDataKeyState {
  _AttachmentDataKeyState(this.value);

  final int value;
  _AttachmentDataKeyPhase phase = _AttachmentDataKeyPhase.open;

  int beginUse() {
    if (phase != _AttachmentDataKeyPhase.open) {
      throw StateError('附件数据密钥句柄已占用、正在关闭或已经关闭');
    }
    phase = _AttachmentDataKeyPhase.busy;
    return value;
  }

  void completeUse() {
    if (phase != _AttachmentDataKeyPhase.busy) {
      throw StateError('附件数据密钥句柄生命周期已失配');
    }
    phase = _AttachmentDataKeyPhase.open;
  }

  int? beginClose() {
    if (phase == _AttachmentDataKeyPhase.closed) return null;
    if (phase != _AttachmentDataKeyPhase.open) {
      throw StateError('附件数据密钥句柄正在操作或关闭');
    }
    phase = _AttachmentDataKeyPhase.closing;
    return value;
  }

  void completeClose() {
    phase = _AttachmentDataKeyPhase.closed;
  }

  void cancelClose() {
    if (phase == _AttachmentDataKeyPhase.closing) {
      phase = _AttachmentDataKeyPhase.open;
    }
  }
}

final class KelivoAttachmentDataKeyHandle {
  KelivoAttachmentDataKeyHandle._(int value)
    : _state = _AttachmentDataKeyState(value);

  final _AttachmentDataKeyState _state;

  @override
  String toString() => 'KelivoAttachmentDataKeyHandle(opaque)';
}

final class KelivoAttachmentDataKeyCreation {
  KelivoAttachmentDataKeyCreation._({
    required this.key,
    required this.attachmentId,
  });

  final KelivoAttachmentDataKeyHandle key;
  final Uint8List attachmentId;
}

extension KelivoAttachmentCrypto on KelivoSecureCore {
  Future<KelivoAttachmentDataKeyCreation> generateAttachmentDataKey() async {
    final generated = await Isolate.run(_generateAttachmentDataKey);
    return KelivoAttachmentDataKeyCreation._(
      key: KelivoAttachmentDataKeyHandle._(generated.handle),
      attachmentId: _immutableDeviceBytes(generated.attachmentId),
    );
  }

  Future<void> closeAttachmentDataKey(KelivoAttachmentDataKeyHandle key) async {
    final value = key._state.beginClose();
    if (value == null) return;
    try {
      await Isolate.run(
        () => _throwOnError(
          operation: 'attachment_data_key_handle_close',
          statusCode: native.kelivo_attachment_data_key_handle_close(value),
        ),
      );
      key._state.completeClose();
    } on KelivoSecureCoreException catch (error) {
      if (error.status ==
          KelivoSecureCoreStatus.invalidAttachmentDataKeyHandle) {
        key._state.completeClose();
      } else {
        key._state.cancelClose();
      }
      rethrow;
    } catch (_) {
      key._state.cancelClose();
      rethrow;
    }
  }

  Future<Uint8List> wrapAttachmentDataKey(
    KelivoAccountRootKeyHandle ark,
    KelivoAttachmentDataKeyHandle key, {
    required KelivoAttachmentContext context,
  }) async {
    final handles = _beginAttachmentHandlePair(ark._state, key._state);
    try {
      return await Isolate.run(
        () => _wrapAttachmentDataKey(
          handles.$1,
          handles.$2,
          Uint8List.fromList(context.userId),
          Uint8List.fromList(context.attachmentId),
          context.keyEpoch,
        ),
      );
    } finally {
      key._state.completeUse();
      ark._state.completeUse();
    }
  }

  Future<KelivoAttachmentDataKeyHandle> unwrapAttachmentDataKey(
    KelivoAccountRootKeyHandle ark, {
    required KelivoAttachmentContext context,
    required Uint8List wrappedKey,
  }) async {
    if (wrappedKey.length > _attachmentWrappedKeyLength) {
      throw ArgumentError.value(
        wrappedKey.length,
        'wrappedKey',
        '附件包装密钥不得超过 $_attachmentWrappedKeyLength 字节',
      );
    }
    final arkValue = ark._state.beginUse();
    try {
      final handle = await Isolate.run(
        () => _unwrapAttachmentDataKey(
          arkValue,
          Uint8List.fromList(context.userId),
          Uint8List.fromList(context.attachmentId),
          context.keyEpoch,
          Uint8List.fromList(wrappedKey),
        ),
      );
      return KelivoAttachmentDataKeyHandle._(handle);
    } finally {
      ark._state.completeUse();
    }
  }

  Future<Uint8List> sealAttachmentChunk(
    KelivoAttachmentDataKeyHandle key, {
    required KelivoAttachmentUploadContext uploadContext,
    required KelivoAttachmentLayout layout,
    required int chunkIndex,
    required Uint8List plaintext,
  }) async {
    final expectedLength = layout.plaintextLengthForChunk(chunkIndex);
    if (plaintext.length != expectedLength) {
      throw ArgumentError.value(
        plaintext.length,
        'plaintext',
        '当前附件块明文长度应为 $expectedLength 字节',
      );
    }
    final value = key._state.beginUse();
    final context = uploadContext.attachment;
    try {
      return await Isolate.run(
        () => _sealAttachmentChunk(
          value,
          Uint8List.fromList(context.userId),
          Uint8List.fromList(context.attachmentId),
          Uint8List.fromList(uploadContext.uploadId),
          context.keyEpoch,
          chunkIndex,
          layout.chunkCount,
          layout.totalPlaintextBytes,
          Uint8List.fromList(plaintext),
        ),
      );
    } finally {
      key._state.completeUse();
    }
  }

  Future<Uint8List> openAttachmentChunk(
    KelivoAttachmentDataKeyHandle key, {
    required KelivoAttachmentUploadContext uploadContext,
    required KelivoAttachmentLayout layout,
    required int chunkIndex,
    required Uint8List envelope,
  }) async {
    final plaintextLength = layout.plaintextLengthForChunk(chunkIndex);
    if (envelope.length > _attachmentMaxChunkEnvelopeSize) {
      throw ArgumentError.value(
        envelope.length,
        'envelope',
        '附件块信封不得超过 $_attachmentMaxChunkEnvelopeSize 字节',
      );
    }
    final value = key._state.beginUse();
    final context = uploadContext.attachment;
    try {
      return await Isolate.run(
        () => _openAttachmentChunk(
          value,
          Uint8List.fromList(context.userId),
          Uint8List.fromList(context.attachmentId),
          Uint8List.fromList(uploadContext.uploadId),
          context.keyEpoch,
          chunkIndex,
          layout.chunkCount,
          layout.totalPlaintextBytes,
          plaintextLength,
          Uint8List.fromList(envelope),
        ),
      );
    } finally {
      key._state.completeUse();
    }
  }
}

final class _GeneratedAttachmentDataKey {
  const _GeneratedAttachmentDataKey({
    required this.handle,
    required this.attachmentId,
  });

  final int handle;
  final Uint8List attachmentId;
}

(int, int) _beginAttachmentHandlePair(
  _DeviceHandleState ark,
  _AttachmentDataKeyState key,
) {
  final arkValue = ark.beginUse();
  try {
    return (arkValue, key.beginUse());
  } catch (_) {
    ark.completeUse();
    rethrow;
  }
}

_GeneratedAttachmentDataKey _generateAttachmentDataKey() {
  final outputHandle = calloc<ffi.Uint64>();
  final outputId = calloc<ffi.Uint8>(_attachmentIdLength);
  final outputLength = calloc<ffi.Size>();
  var transferred = false;
  try {
    _throwOnError(
      operation: 'attachment_data_key_generate',
      statusCode: native.kelivo_attachment_data_key_generate(
        outputHandle,
        outputId,
        _attachmentIdLength,
        outputLength,
      ),
    );
    if (outputHandle.value == native.KELIVO_DEVICE_INVALID_HANDLE) {
      throw StateError('附件数据密钥生成成功但返回了无效句柄');
    }
    _requireExactOutputLength(
      operation: 'attachment_data_key_generate',
      expected: _attachmentIdLength,
      actual: outputLength.value,
    );
    final generated = _GeneratedAttachmentDataKey(
      handle: outputHandle.value,
      attachmentId: Uint8List.fromList(
        outputId.asTypedList(_attachmentIdLength),
      ),
    );
    transferred = true;
    return generated;
  } finally {
    if (!transferred &&
        outputHandle.value != native.KELIVO_DEVICE_INVALID_HANDLE) {
      native.kelivo_attachment_data_key_handle_close(outputHandle.value);
    }
    _clearAndFree(outputId, _attachmentIdLength);
    calloc.free(outputHandle);
    calloc.free(outputLength);
  }
}

Uint8List _wrapAttachmentDataKey(
  int arkHandle,
  int dataKeyHandle,
  Uint8List userId,
  Uint8List attachmentId,
  int keyEpoch,
) {
  final userIdPointer = _copyToNative(userId);
  final attachmentIdPointer = _copyToNative(attachmentId);
  final output = calloc<ffi.Uint8>(_attachmentWrappedKeyLength);
  final outputLength = calloc<ffi.Size>();
  try {
    _throwOnError(
      operation: 'attachment_data_key_wrap',
      statusCode: native.kelivo_attachment_data_key_wrap(
        arkHandle,
        dataKeyHandle,
        userIdPointer,
        userId.length,
        attachmentIdPointer,
        attachmentId.length,
        keyEpoch,
        output,
        _attachmentWrappedKeyLength,
        outputLength,
      ),
    );
    _requireExactOutputLength(
      operation: 'attachment_data_key_wrap',
      expected: _attachmentWrappedKeyLength,
      actual: outputLength.value,
    );
    return Uint8List.fromList(output.asTypedList(_attachmentWrappedKeyLength));
  } finally {
    _clearAndFree(userIdPointer, userId.length);
    _clearAndFree(attachmentIdPointer, attachmentId.length);
    _clearAndFree(output, _attachmentWrappedKeyLength);
    userId.fillRange(0, userId.length, 0);
    attachmentId.fillRange(0, attachmentId.length, 0);
    calloc.free(outputLength);
  }
}

int _unwrapAttachmentDataKey(
  int arkHandle,
  Uint8List userId,
  Uint8List attachmentId,
  int keyEpoch,
  Uint8List wrappedKey,
) {
  final userIdPointer = _copyToNative(userId);
  final attachmentIdPointer = _copyToNative(attachmentId);
  final wrappedKeyPointer = _copyToNative(wrappedKey);
  final outputHandle = calloc<ffi.Uint64>();
  var transferred = false;
  try {
    _throwOnError(
      operation: 'attachment_data_key_unwrap',
      statusCode: native.kelivo_attachment_data_key_unwrap(
        arkHandle,
        userIdPointer,
        userId.length,
        attachmentIdPointer,
        attachmentId.length,
        keyEpoch,
        wrappedKeyPointer,
        wrappedKey.length,
        outputHandle,
      ),
    );
    if (outputHandle.value == native.KELIVO_DEVICE_INVALID_HANDLE) {
      throw StateError('附件数据密钥解包成功但返回了无效句柄');
    }
    transferred = true;
    return outputHandle.value;
  } finally {
    if (!transferred &&
        outputHandle.value != native.KELIVO_DEVICE_INVALID_HANDLE) {
      native.kelivo_attachment_data_key_handle_close(outputHandle.value);
    }
    _clearAndFree(userIdPointer, userId.length);
    _clearAndFree(attachmentIdPointer, attachmentId.length);
    _clearAndFree(wrappedKeyPointer, wrappedKey.length);
    userId.fillRange(0, userId.length, 0);
    attachmentId.fillRange(0, attachmentId.length, 0);
    wrappedKey.fillRange(0, wrappedKey.length, 0);
    calloc.free(outputHandle);
  }
}

Uint8List _sealAttachmentChunk(
  int dataKeyHandle,
  Uint8List userId,
  Uint8List attachmentId,
  Uint8List uploadId,
  int keyEpoch,
  int chunkIndex,
  int chunkCount,
  int totalPlaintextBytes,
  Uint8List plaintext,
) {
  final userIdPointer = _copyToNative(userId);
  final attachmentIdPointer = _copyToNative(attachmentId);
  final uploadIdPointer = _copyToNative(uploadId);
  final plaintextPointer = _copyToNative(plaintext);
  final outputLength = calloc<ffi.Size>();

  int seal(ffi.Pointer<ffi.Uint8> output, int capacity) =>
      native.kelivo_attachment_chunk_seal(
        dataKeyHandle,
        userIdPointer,
        userId.length,
        attachmentIdPointer,
        attachmentId.length,
        uploadIdPointer,
        uploadId.length,
        keyEpoch,
        chunkIndex,
        chunkCount,
        totalPlaintextBytes,
        plaintextPointer,
        plaintext.length,
        output,
        capacity,
        outputLength,
      );

  try {
    final required = _readRequiredOutputLength(
      operation: 'attachment_chunk_seal_size',
      statusCode: seal(ffi.nullptr, 0),
      outputLength: outputLength.value,
      allowEmpty: false,
      maxLength: _attachmentMaxChunkEnvelopeSize,
    );
    final output = calloc<ffi.Uint8>(required);
    try {
      _throwOnError(
        operation: 'attachment_chunk_seal',
        statusCode: seal(output, required),
      );
      _requireExactOutputLength(
        operation: 'attachment_chunk_seal',
        expected: required,
        actual: outputLength.value,
      );
      return Uint8List.fromList(output.asTypedList(required));
    } finally {
      _clearAndFree(output, required);
    }
  } finally {
    _clearAndFree(userIdPointer, userId.length);
    _clearAndFree(attachmentIdPointer, attachmentId.length);
    _clearAndFree(uploadIdPointer, uploadId.length);
    _clearAndFree(plaintextPointer, plaintext.length);
    userId.fillRange(0, userId.length, 0);
    attachmentId.fillRange(0, attachmentId.length, 0);
    uploadId.fillRange(0, uploadId.length, 0);
    plaintext.fillRange(0, plaintext.length, 0);
    calloc.free(outputLength);
  }
}

Uint8List _openAttachmentChunk(
  int dataKeyHandle,
  Uint8List userId,
  Uint8List attachmentId,
  Uint8List uploadId,
  int keyEpoch,
  int chunkIndex,
  int chunkCount,
  int totalPlaintextBytes,
  int plaintextLength,
  Uint8List envelope,
) {
  final userIdPointer = _copyToNative(userId);
  final attachmentIdPointer = _copyToNative(attachmentId);
  final uploadIdPointer = _copyToNative(uploadId);
  final envelopePointer = _copyToNative(envelope);
  final outputLength = calloc<ffi.Size>();

  int open(ffi.Pointer<ffi.Uint8> output, int capacity) =>
      native.kelivo_attachment_chunk_open(
        dataKeyHandle,
        userIdPointer,
        userId.length,
        attachmentIdPointer,
        attachmentId.length,
        uploadIdPointer,
        uploadId.length,
        keyEpoch,
        chunkIndex,
        chunkCount,
        totalPlaintextBytes,
        plaintextLength,
        envelopePointer,
        envelope.length,
        output,
        capacity,
        outputLength,
      );

  try {
    final required = _readRequiredOutputLength(
      operation: 'attachment_chunk_open_size',
      statusCode: open(ffi.nullptr, 0),
      outputLength: outputLength.value,
      allowEmpty: true,
      maxLength: _attachmentChunkPlaintextSize,
    );
    if (required == 0) return Uint8List(0);
    final output = calloc<ffi.Uint8>(required);
    try {
      _throwOnError(
        operation: 'attachment_chunk_open',
        statusCode: open(output, required),
      );
      _requireExactOutputLength(
        operation: 'attachment_chunk_open',
        expected: required,
        actual: outputLength.value,
      );
      return Uint8List.fromList(output.asTypedList(required));
    } finally {
      _clearAndFree(output, required);
    }
  } finally {
    _clearAndFree(userIdPointer, userId.length);
    _clearAndFree(attachmentIdPointer, attachmentId.length);
    _clearAndFree(uploadIdPointer, uploadId.length);
    _clearAndFree(envelopePointer, envelope.length);
    userId.fillRange(0, userId.length, 0);
    attachmentId.fillRange(0, attachmentId.length, 0);
    uploadId.fillRange(0, uploadId.length, 0);
    envelope.fillRange(0, envelope.length, 0);
    calloc.free(outputLength);
  }
}
