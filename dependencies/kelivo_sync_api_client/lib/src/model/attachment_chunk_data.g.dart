// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attachment_chunk_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$AttachmentChunkData extends AttachmentChunkData {
  @override
  final String attachmentId;
  @override
  final String uploadId;
  @override
  final int keyEpoch;
  @override
  final int chunkIndex;
  @override
  final String ciphertext;
  @override
  final int ciphertextBytes;

  factory _$AttachmentChunkData([
    void Function(AttachmentChunkDataBuilder)? updates,
  ]) => (AttachmentChunkDataBuilder()..update(updates))._build();

  _$AttachmentChunkData._({
    required this.attachmentId,
    required this.uploadId,
    required this.keyEpoch,
    required this.chunkIndex,
    required this.ciphertext,
    required this.ciphertextBytes,
  }) : super._();
  @override
  AttachmentChunkData rebuild(
    void Function(AttachmentChunkDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  AttachmentChunkDataBuilder toBuilder() =>
      AttachmentChunkDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AttachmentChunkData &&
        attachmentId == other.attachmentId &&
        uploadId == other.uploadId &&
        keyEpoch == other.keyEpoch &&
        chunkIndex == other.chunkIndex &&
        ciphertext == other.ciphertext &&
        ciphertextBytes == other.ciphertextBytes;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, attachmentId.hashCode);
    _$hash = $jc(_$hash, uploadId.hashCode);
    _$hash = $jc(_$hash, keyEpoch.hashCode);
    _$hash = $jc(_$hash, chunkIndex.hashCode);
    _$hash = $jc(_$hash, ciphertext.hashCode);
    _$hash = $jc(_$hash, ciphertextBytes.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'AttachmentChunkData')
          ..add('attachmentId', attachmentId)
          ..add('uploadId', uploadId)
          ..add('keyEpoch', keyEpoch)
          ..add('chunkIndex', chunkIndex)
          ..add('ciphertext', ciphertext)
          ..add('ciphertextBytes', ciphertextBytes))
        .toString();
  }
}

class AttachmentChunkDataBuilder
    implements Builder<AttachmentChunkData, AttachmentChunkDataBuilder> {
  _$AttachmentChunkData? _$v;

  String? _attachmentId;
  String? get attachmentId => _$this._attachmentId;
  set attachmentId(String? attachmentId) => _$this._attachmentId = attachmentId;

  String? _uploadId;
  String? get uploadId => _$this._uploadId;
  set uploadId(String? uploadId) => _$this._uploadId = uploadId;

  int? _keyEpoch;
  int? get keyEpoch => _$this._keyEpoch;
  set keyEpoch(int? keyEpoch) => _$this._keyEpoch = keyEpoch;

  int? _chunkIndex;
  int? get chunkIndex => _$this._chunkIndex;
  set chunkIndex(int? chunkIndex) => _$this._chunkIndex = chunkIndex;

  String? _ciphertext;
  String? get ciphertext => _$this._ciphertext;
  set ciphertext(String? ciphertext) => _$this._ciphertext = ciphertext;

  int? _ciphertextBytes;
  int? get ciphertextBytes => _$this._ciphertextBytes;
  set ciphertextBytes(int? ciphertextBytes) =>
      _$this._ciphertextBytes = ciphertextBytes;

  AttachmentChunkDataBuilder() {
    AttachmentChunkData._defaults(this);
  }

  AttachmentChunkDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _attachmentId = $v.attachmentId;
      _uploadId = $v.uploadId;
      _keyEpoch = $v.keyEpoch;
      _chunkIndex = $v.chunkIndex;
      _ciphertext = $v.ciphertext;
      _ciphertextBytes = $v.ciphertextBytes;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AttachmentChunkData other) {
    _$v = other as _$AttachmentChunkData;
  }

  @override
  void update(void Function(AttachmentChunkDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  AttachmentChunkData build() => _build();

  _$AttachmentChunkData _build() {
    final _$result =
        _$v ??
        _$AttachmentChunkData._(
          attachmentId: BuiltValueNullFieldError.checkNotNull(
            attachmentId,
            r'AttachmentChunkData',
            'attachmentId',
          ),
          uploadId: BuiltValueNullFieldError.checkNotNull(
            uploadId,
            r'AttachmentChunkData',
            'uploadId',
          ),
          keyEpoch: BuiltValueNullFieldError.checkNotNull(
            keyEpoch,
            r'AttachmentChunkData',
            'keyEpoch',
          ),
          chunkIndex: BuiltValueNullFieldError.checkNotNull(
            chunkIndex,
            r'AttachmentChunkData',
            'chunkIndex',
          ),
          ciphertext: BuiltValueNullFieldError.checkNotNull(
            ciphertext,
            r'AttachmentChunkData',
            'ciphertext',
          ),
          ciphertextBytes: BuiltValueNullFieldError.checkNotNull(
            ciphertextBytes,
            r'AttachmentChunkData',
            'ciphertextBytes',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
