// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_rekey_source_attachment_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$DataRekeySourceAttachmentData extends DataRekeySourceAttachmentData {
  @override
  final String attachmentId;
  @override
  final String uploadId;
  @override
  final int chunkKeyEpoch;
  @override
  final int manifestKeyEpoch;
  @override
  final int manifestRevision;
  @override
  final int chunkCount;
  @override
  final int totalCiphertextBytes;
  @override
  final String manifestCiphertext;
  @override
  final int manifestCiphertextBytes;
  @override
  final String manifestCiphertextDigest;
  @override
  final BuiltList<DataRekeySourceAttachmentDataChunksInner> chunks;
  @override
  final DateTime committedAt;

  factory _$DataRekeySourceAttachmentData([
    void Function(DataRekeySourceAttachmentDataBuilder)? updates,
  ]) => (DataRekeySourceAttachmentDataBuilder()..update(updates))._build();

  _$DataRekeySourceAttachmentData._({
    required this.attachmentId,
    required this.uploadId,
    required this.chunkKeyEpoch,
    required this.manifestKeyEpoch,
    required this.manifestRevision,
    required this.chunkCount,
    required this.totalCiphertextBytes,
    required this.manifestCiphertext,
    required this.manifestCiphertextBytes,
    required this.manifestCiphertextDigest,
    required this.chunks,
    required this.committedAt,
  }) : super._();
  @override
  DataRekeySourceAttachmentData rebuild(
    void Function(DataRekeySourceAttachmentDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  DataRekeySourceAttachmentDataBuilder toBuilder() =>
      DataRekeySourceAttachmentDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DataRekeySourceAttachmentData &&
        attachmentId == other.attachmentId &&
        uploadId == other.uploadId &&
        chunkKeyEpoch == other.chunkKeyEpoch &&
        manifestKeyEpoch == other.manifestKeyEpoch &&
        manifestRevision == other.manifestRevision &&
        chunkCount == other.chunkCount &&
        totalCiphertextBytes == other.totalCiphertextBytes &&
        manifestCiphertext == other.manifestCiphertext &&
        manifestCiphertextBytes == other.manifestCiphertextBytes &&
        manifestCiphertextDigest == other.manifestCiphertextDigest &&
        chunks == other.chunks &&
        committedAt == other.committedAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, attachmentId.hashCode);
    _$hash = $jc(_$hash, uploadId.hashCode);
    _$hash = $jc(_$hash, chunkKeyEpoch.hashCode);
    _$hash = $jc(_$hash, manifestKeyEpoch.hashCode);
    _$hash = $jc(_$hash, manifestRevision.hashCode);
    _$hash = $jc(_$hash, chunkCount.hashCode);
    _$hash = $jc(_$hash, totalCiphertextBytes.hashCode);
    _$hash = $jc(_$hash, manifestCiphertext.hashCode);
    _$hash = $jc(_$hash, manifestCiphertextBytes.hashCode);
    _$hash = $jc(_$hash, manifestCiphertextDigest.hashCode);
    _$hash = $jc(_$hash, chunks.hashCode);
    _$hash = $jc(_$hash, committedAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'DataRekeySourceAttachmentData')
          ..add('attachmentId', attachmentId)
          ..add('uploadId', uploadId)
          ..add('chunkKeyEpoch', chunkKeyEpoch)
          ..add('manifestKeyEpoch', manifestKeyEpoch)
          ..add('manifestRevision', manifestRevision)
          ..add('chunkCount', chunkCount)
          ..add('totalCiphertextBytes', totalCiphertextBytes)
          ..add('manifestCiphertext', manifestCiphertext)
          ..add('manifestCiphertextBytes', manifestCiphertextBytes)
          ..add('manifestCiphertextDigest', manifestCiphertextDigest)
          ..add('chunks', chunks)
          ..add('committedAt', committedAt))
        .toString();
  }
}

class DataRekeySourceAttachmentDataBuilder
    implements
        Builder<
          DataRekeySourceAttachmentData,
          DataRekeySourceAttachmentDataBuilder
        > {
  _$DataRekeySourceAttachmentData? _$v;

  String? _attachmentId;
  String? get attachmentId => _$this._attachmentId;
  set attachmentId(String? attachmentId) => _$this._attachmentId = attachmentId;

  String? _uploadId;
  String? get uploadId => _$this._uploadId;
  set uploadId(String? uploadId) => _$this._uploadId = uploadId;

  int? _chunkKeyEpoch;
  int? get chunkKeyEpoch => _$this._chunkKeyEpoch;
  set chunkKeyEpoch(int? chunkKeyEpoch) =>
      _$this._chunkKeyEpoch = chunkKeyEpoch;

  int? _manifestKeyEpoch;
  int? get manifestKeyEpoch => _$this._manifestKeyEpoch;
  set manifestKeyEpoch(int? manifestKeyEpoch) =>
      _$this._manifestKeyEpoch = manifestKeyEpoch;

  int? _manifestRevision;
  int? get manifestRevision => _$this._manifestRevision;
  set manifestRevision(int? manifestRevision) =>
      _$this._manifestRevision = manifestRevision;

  int? _chunkCount;
  int? get chunkCount => _$this._chunkCount;
  set chunkCount(int? chunkCount) => _$this._chunkCount = chunkCount;

  int? _totalCiphertextBytes;
  int? get totalCiphertextBytes => _$this._totalCiphertextBytes;
  set totalCiphertextBytes(int? totalCiphertextBytes) =>
      _$this._totalCiphertextBytes = totalCiphertextBytes;

  String? _manifestCiphertext;
  String? get manifestCiphertext => _$this._manifestCiphertext;
  set manifestCiphertext(String? manifestCiphertext) =>
      _$this._manifestCiphertext = manifestCiphertext;

  int? _manifestCiphertextBytes;
  int? get manifestCiphertextBytes => _$this._manifestCiphertextBytes;
  set manifestCiphertextBytes(int? manifestCiphertextBytes) =>
      _$this._manifestCiphertextBytes = manifestCiphertextBytes;

  String? _manifestCiphertextDigest;
  String? get manifestCiphertextDigest => _$this._manifestCiphertextDigest;
  set manifestCiphertextDigest(String? manifestCiphertextDigest) =>
      _$this._manifestCiphertextDigest = manifestCiphertextDigest;

  ListBuilder<DataRekeySourceAttachmentDataChunksInner>? _chunks;
  ListBuilder<DataRekeySourceAttachmentDataChunksInner> get chunks =>
      _$this._chunks ??=
          ListBuilder<DataRekeySourceAttachmentDataChunksInner>();
  set chunks(ListBuilder<DataRekeySourceAttachmentDataChunksInner>? chunks) =>
      _$this._chunks = chunks;

  DateTime? _committedAt;
  DateTime? get committedAt => _$this._committedAt;
  set committedAt(DateTime? committedAt) => _$this._committedAt = committedAt;

  DataRekeySourceAttachmentDataBuilder() {
    DataRekeySourceAttachmentData._defaults(this);
  }

  DataRekeySourceAttachmentDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _attachmentId = $v.attachmentId;
      _uploadId = $v.uploadId;
      _chunkKeyEpoch = $v.chunkKeyEpoch;
      _manifestKeyEpoch = $v.manifestKeyEpoch;
      _manifestRevision = $v.manifestRevision;
      _chunkCount = $v.chunkCount;
      _totalCiphertextBytes = $v.totalCiphertextBytes;
      _manifestCiphertext = $v.manifestCiphertext;
      _manifestCiphertextBytes = $v.manifestCiphertextBytes;
      _manifestCiphertextDigest = $v.manifestCiphertextDigest;
      _chunks = $v.chunks.toBuilder();
      _committedAt = $v.committedAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DataRekeySourceAttachmentData other) {
    _$v = other as _$DataRekeySourceAttachmentData;
  }

  @override
  void update(void Function(DataRekeySourceAttachmentDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DataRekeySourceAttachmentData build() => _build();

  _$DataRekeySourceAttachmentData _build() {
    _$DataRekeySourceAttachmentData _$result;
    try {
      _$result =
          _$v ??
          _$DataRekeySourceAttachmentData._(
            attachmentId: BuiltValueNullFieldError.checkNotNull(
              attachmentId,
              r'DataRekeySourceAttachmentData',
              'attachmentId',
            ),
            uploadId: BuiltValueNullFieldError.checkNotNull(
              uploadId,
              r'DataRekeySourceAttachmentData',
              'uploadId',
            ),
            chunkKeyEpoch: BuiltValueNullFieldError.checkNotNull(
              chunkKeyEpoch,
              r'DataRekeySourceAttachmentData',
              'chunkKeyEpoch',
            ),
            manifestKeyEpoch: BuiltValueNullFieldError.checkNotNull(
              manifestKeyEpoch,
              r'DataRekeySourceAttachmentData',
              'manifestKeyEpoch',
            ),
            manifestRevision: BuiltValueNullFieldError.checkNotNull(
              manifestRevision,
              r'DataRekeySourceAttachmentData',
              'manifestRevision',
            ),
            chunkCount: BuiltValueNullFieldError.checkNotNull(
              chunkCount,
              r'DataRekeySourceAttachmentData',
              'chunkCount',
            ),
            totalCiphertextBytes: BuiltValueNullFieldError.checkNotNull(
              totalCiphertextBytes,
              r'DataRekeySourceAttachmentData',
              'totalCiphertextBytes',
            ),
            manifestCiphertext: BuiltValueNullFieldError.checkNotNull(
              manifestCiphertext,
              r'DataRekeySourceAttachmentData',
              'manifestCiphertext',
            ),
            manifestCiphertextBytes: BuiltValueNullFieldError.checkNotNull(
              manifestCiphertextBytes,
              r'DataRekeySourceAttachmentData',
              'manifestCiphertextBytes',
            ),
            manifestCiphertextDigest: BuiltValueNullFieldError.checkNotNull(
              manifestCiphertextDigest,
              r'DataRekeySourceAttachmentData',
              'manifestCiphertextDigest',
            ),
            chunks: chunks.build(),
            committedAt: BuiltValueNullFieldError.checkNotNull(
              committedAt,
              r'DataRekeySourceAttachmentData',
              'committedAt',
            ),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'chunks';
        chunks.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'DataRekeySourceAttachmentData',
          _$failedField,
          e.toString(),
        );
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
