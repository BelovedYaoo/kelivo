// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attachment_info.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$AttachmentInfo extends AttachmentInfo {
  @override
  final String id;
  @override
  final String blobId;
  @override
  final String entityType;
  @override
  final String entityId;
  @override
  final String fileName;
  @override
  final String mimeType;
  @override
  final int sizeBytes;
  @override
  final String sha256;
  @override
  final DateTime createdAt;

  factory _$AttachmentInfo([void Function(AttachmentInfoBuilder)? updates]) =>
      (AttachmentInfoBuilder()..update(updates))._build();

  _$AttachmentInfo._({
    required this.id,
    required this.blobId,
    required this.entityType,
    required this.entityId,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.sha256,
    required this.createdAt,
  }) : super._();
  @override
  AttachmentInfo rebuild(void Function(AttachmentInfoBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  AttachmentInfoBuilder toBuilder() => AttachmentInfoBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AttachmentInfo &&
        id == other.id &&
        blobId == other.blobId &&
        entityType == other.entityType &&
        entityId == other.entityId &&
        fileName == other.fileName &&
        mimeType == other.mimeType &&
        sizeBytes == other.sizeBytes &&
        sha256 == other.sha256 &&
        createdAt == other.createdAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jc(_$hash, blobId.hashCode);
    _$hash = $jc(_$hash, entityType.hashCode);
    _$hash = $jc(_$hash, entityId.hashCode);
    _$hash = $jc(_$hash, fileName.hashCode);
    _$hash = $jc(_$hash, mimeType.hashCode);
    _$hash = $jc(_$hash, sizeBytes.hashCode);
    _$hash = $jc(_$hash, sha256.hashCode);
    _$hash = $jc(_$hash, createdAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'AttachmentInfo')
          ..add('id', id)
          ..add('blobId', blobId)
          ..add('entityType', entityType)
          ..add('entityId', entityId)
          ..add('fileName', fileName)
          ..add('mimeType', mimeType)
          ..add('sizeBytes', sizeBytes)
          ..add('sha256', sha256)
          ..add('createdAt', createdAt))
        .toString();
  }
}

class AttachmentInfoBuilder
    implements Builder<AttachmentInfo, AttachmentInfoBuilder> {
  _$AttachmentInfo? _$v;

  String? _id;
  String? get id => _$this._id;
  set id(String? id) => _$this._id = id;

  String? _blobId;
  String? get blobId => _$this._blobId;
  set blobId(String? blobId) => _$this._blobId = blobId;

  String? _entityType;
  String? get entityType => _$this._entityType;
  set entityType(String? entityType) => _$this._entityType = entityType;

  String? _entityId;
  String? get entityId => _$this._entityId;
  set entityId(String? entityId) => _$this._entityId = entityId;

  String? _fileName;
  String? get fileName => _$this._fileName;
  set fileName(String? fileName) => _$this._fileName = fileName;

  String? _mimeType;
  String? get mimeType => _$this._mimeType;
  set mimeType(String? mimeType) => _$this._mimeType = mimeType;

  int? _sizeBytes;
  int? get sizeBytes => _$this._sizeBytes;
  set sizeBytes(int? sizeBytes) => _$this._sizeBytes = sizeBytes;

  String? _sha256;
  String? get sha256 => _$this._sha256;
  set sha256(String? sha256) => _$this._sha256 = sha256;

  DateTime? _createdAt;
  DateTime? get createdAt => _$this._createdAt;
  set createdAt(DateTime? createdAt) => _$this._createdAt = createdAt;

  AttachmentInfoBuilder() {
    AttachmentInfo._defaults(this);
  }

  AttachmentInfoBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _id = $v.id;
      _blobId = $v.blobId;
      _entityType = $v.entityType;
      _entityId = $v.entityId;
      _fileName = $v.fileName;
      _mimeType = $v.mimeType;
      _sizeBytes = $v.sizeBytes;
      _sha256 = $v.sha256;
      _createdAt = $v.createdAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AttachmentInfo other) {
    _$v = other as _$AttachmentInfo;
  }

  @override
  void update(void Function(AttachmentInfoBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  AttachmentInfo build() => _build();

  _$AttachmentInfo _build() {
    final _$result =
        _$v ??
        _$AttachmentInfo._(
          id: BuiltValueNullFieldError.checkNotNull(
            id,
            r'AttachmentInfo',
            'id',
          ),
          blobId: BuiltValueNullFieldError.checkNotNull(
            blobId,
            r'AttachmentInfo',
            'blobId',
          ),
          entityType: BuiltValueNullFieldError.checkNotNull(
            entityType,
            r'AttachmentInfo',
            'entityType',
          ),
          entityId: BuiltValueNullFieldError.checkNotNull(
            entityId,
            r'AttachmentInfo',
            'entityId',
          ),
          fileName: BuiltValueNullFieldError.checkNotNull(
            fileName,
            r'AttachmentInfo',
            'fileName',
          ),
          mimeType: BuiltValueNullFieldError.checkNotNull(
            mimeType,
            r'AttachmentInfo',
            'mimeType',
          ),
          sizeBytes: BuiltValueNullFieldError.checkNotNull(
            sizeBytes,
            r'AttachmentInfo',
            'sizeBytes',
          ),
          sha256: BuiltValueNullFieldError.checkNotNull(
            sha256,
            r'AttachmentInfo',
            'sha256',
          ),
          createdAt: BuiltValueNullFieldError.checkNotNull(
            createdAt,
            r'AttachmentInfo',
            'createdAt',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
