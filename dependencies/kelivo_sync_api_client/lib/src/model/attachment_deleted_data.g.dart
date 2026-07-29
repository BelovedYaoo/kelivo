// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attachment_deleted_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const AttachmentDeletedDataStatusEnum
_$attachmentDeletedDataStatusEnum_deleted =
    const AttachmentDeletedDataStatusEnum._('deleted');

AttachmentDeletedDataStatusEnum _$attachmentDeletedDataStatusEnumValueOf(
  String name,
) {
  switch (name) {
    case 'deleted':
      return _$attachmentDeletedDataStatusEnum_deleted;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<AttachmentDeletedDataStatusEnum>
_$attachmentDeletedDataStatusEnumValues =
    BuiltSet<AttachmentDeletedDataStatusEnum>(
      const <AttachmentDeletedDataStatusEnum>[
        _$attachmentDeletedDataStatusEnum_deleted,
      ],
    );

Serializer<AttachmentDeletedDataStatusEnum>
_$attachmentDeletedDataStatusEnumSerializer =
    _$AttachmentDeletedDataStatusEnumSerializer();

class _$AttachmentDeletedDataStatusEnumSerializer
    implements PrimitiveSerializer<AttachmentDeletedDataStatusEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'deleted': 'deleted',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'deleted': 'deleted',
  };

  @override
  final Iterable<Type> types = const <Type>[AttachmentDeletedDataStatusEnum];
  @override
  final String wireName = 'AttachmentDeletedDataStatusEnum';

  @override
  Object serialize(
    Serializers serializers,
    AttachmentDeletedDataStatusEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  AttachmentDeletedDataStatusEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => AttachmentDeletedDataStatusEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$AttachmentDeletedData extends AttachmentDeletedData {
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
  final AttachmentDeletedDataStatusEnum status;
  @override
  final DateTime deletedAt;

  factory _$AttachmentDeletedData([
    void Function(AttachmentDeletedDataBuilder)? updates,
  ]) => (AttachmentDeletedDataBuilder()..update(updates))._build();

  _$AttachmentDeletedData._({
    required this.attachmentId,
    required this.uploadId,
    required this.chunkKeyEpoch,
    required this.manifestKeyEpoch,
    required this.manifestRevision,
    required this.status,
    required this.deletedAt,
  }) : super._();
  @override
  AttachmentDeletedData rebuild(
    void Function(AttachmentDeletedDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  AttachmentDeletedDataBuilder toBuilder() =>
      AttachmentDeletedDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AttachmentDeletedData &&
        attachmentId == other.attachmentId &&
        uploadId == other.uploadId &&
        chunkKeyEpoch == other.chunkKeyEpoch &&
        manifestKeyEpoch == other.manifestKeyEpoch &&
        manifestRevision == other.manifestRevision &&
        status == other.status &&
        deletedAt == other.deletedAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, attachmentId.hashCode);
    _$hash = $jc(_$hash, uploadId.hashCode);
    _$hash = $jc(_$hash, chunkKeyEpoch.hashCode);
    _$hash = $jc(_$hash, manifestKeyEpoch.hashCode);
    _$hash = $jc(_$hash, manifestRevision.hashCode);
    _$hash = $jc(_$hash, status.hashCode);
    _$hash = $jc(_$hash, deletedAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'AttachmentDeletedData')
          ..add('attachmentId', attachmentId)
          ..add('uploadId', uploadId)
          ..add('chunkKeyEpoch', chunkKeyEpoch)
          ..add('manifestKeyEpoch', manifestKeyEpoch)
          ..add('manifestRevision', manifestRevision)
          ..add('status', status)
          ..add('deletedAt', deletedAt))
        .toString();
  }
}

class AttachmentDeletedDataBuilder
    implements Builder<AttachmentDeletedData, AttachmentDeletedDataBuilder> {
  _$AttachmentDeletedData? _$v;

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

  AttachmentDeletedDataStatusEnum? _status;
  AttachmentDeletedDataStatusEnum? get status => _$this._status;
  set status(AttachmentDeletedDataStatusEnum? status) =>
      _$this._status = status;

  DateTime? _deletedAt;
  DateTime? get deletedAt => _$this._deletedAt;
  set deletedAt(DateTime? deletedAt) => _$this._deletedAt = deletedAt;

  AttachmentDeletedDataBuilder() {
    AttachmentDeletedData._defaults(this);
  }

  AttachmentDeletedDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _attachmentId = $v.attachmentId;
      _uploadId = $v.uploadId;
      _chunkKeyEpoch = $v.chunkKeyEpoch;
      _manifestKeyEpoch = $v.manifestKeyEpoch;
      _manifestRevision = $v.manifestRevision;
      _status = $v.status;
      _deletedAt = $v.deletedAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AttachmentDeletedData other) {
    _$v = other as _$AttachmentDeletedData;
  }

  @override
  void update(void Function(AttachmentDeletedDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  AttachmentDeletedData build() => _build();

  _$AttachmentDeletedData _build() {
    final _$result =
        _$v ??
        _$AttachmentDeletedData._(
          attachmentId: BuiltValueNullFieldError.checkNotNull(
            attachmentId,
            r'AttachmentDeletedData',
            'attachmentId',
          ),
          uploadId: BuiltValueNullFieldError.checkNotNull(
            uploadId,
            r'AttachmentDeletedData',
            'uploadId',
          ),
          chunkKeyEpoch: BuiltValueNullFieldError.checkNotNull(
            chunkKeyEpoch,
            r'AttachmentDeletedData',
            'chunkKeyEpoch',
          ),
          manifestKeyEpoch: BuiltValueNullFieldError.checkNotNull(
            manifestKeyEpoch,
            r'AttachmentDeletedData',
            'manifestKeyEpoch',
          ),
          manifestRevision: BuiltValueNullFieldError.checkNotNull(
            manifestRevision,
            r'AttachmentDeletedData',
            'manifestRevision',
          ),
          status: BuiltValueNullFieldError.checkNotNull(
            status,
            r'AttachmentDeletedData',
            'status',
          ),
          deletedAt: BuiltValueNullFieldError.checkNotNull(
            deletedAt,
            r'AttachmentDeletedData',
            'deletedAt',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
