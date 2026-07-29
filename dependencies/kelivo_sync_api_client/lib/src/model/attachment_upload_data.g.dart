// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attachment_upload_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const AttachmentUploadDataStatusEnum _$attachmentUploadDataStatusEnum_open =
    const AttachmentUploadDataStatusEnum._('open');

AttachmentUploadDataStatusEnum _$attachmentUploadDataStatusEnumValueOf(
  String name,
) {
  switch (name) {
    case 'open':
      return _$attachmentUploadDataStatusEnum_open;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<AttachmentUploadDataStatusEnum>
_$attachmentUploadDataStatusEnumValues =
    BuiltSet<AttachmentUploadDataStatusEnum>(
      const <AttachmentUploadDataStatusEnum>[
        _$attachmentUploadDataStatusEnum_open,
      ],
    );

Serializer<AttachmentUploadDataStatusEnum>
_$attachmentUploadDataStatusEnumSerializer =
    _$AttachmentUploadDataStatusEnumSerializer();

class _$AttachmentUploadDataStatusEnumSerializer
    implements PrimitiveSerializer<AttachmentUploadDataStatusEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'open': 'open',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'open': 'open',
  };

  @override
  final Iterable<Type> types = const <Type>[AttachmentUploadDataStatusEnum];
  @override
  final String wireName = 'AttachmentUploadDataStatusEnum';

  @override
  Object serialize(
    Serializers serializers,
    AttachmentUploadDataStatusEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  AttachmentUploadDataStatusEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => AttachmentUploadDataStatusEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$AttachmentUploadData extends AttachmentUploadData {
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
  final AttachmentUploadDataStatusEnum status;
  @override
  final DateTime createdAt;

  factory _$AttachmentUploadData([
    void Function(AttachmentUploadDataBuilder)? updates,
  ]) => (AttachmentUploadDataBuilder()..update(updates))._build();

  _$AttachmentUploadData._({
    required this.attachmentId,
    required this.uploadId,
    required this.chunkKeyEpoch,
    required this.manifestKeyEpoch,
    required this.manifestRevision,
    required this.chunkCount,
    required this.totalCiphertextBytes,
    required this.status,
    required this.createdAt,
  }) : super._();
  @override
  AttachmentUploadData rebuild(
    void Function(AttachmentUploadDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  AttachmentUploadDataBuilder toBuilder() =>
      AttachmentUploadDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AttachmentUploadData &&
        attachmentId == other.attachmentId &&
        uploadId == other.uploadId &&
        chunkKeyEpoch == other.chunkKeyEpoch &&
        manifestKeyEpoch == other.manifestKeyEpoch &&
        manifestRevision == other.manifestRevision &&
        chunkCount == other.chunkCount &&
        totalCiphertextBytes == other.totalCiphertextBytes &&
        status == other.status &&
        createdAt == other.createdAt;
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
    _$hash = $jc(_$hash, status.hashCode);
    _$hash = $jc(_$hash, createdAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'AttachmentUploadData')
          ..add('attachmentId', attachmentId)
          ..add('uploadId', uploadId)
          ..add('chunkKeyEpoch', chunkKeyEpoch)
          ..add('manifestKeyEpoch', manifestKeyEpoch)
          ..add('manifestRevision', manifestRevision)
          ..add('chunkCount', chunkCount)
          ..add('totalCiphertextBytes', totalCiphertextBytes)
          ..add('status', status)
          ..add('createdAt', createdAt))
        .toString();
  }
}

class AttachmentUploadDataBuilder
    implements Builder<AttachmentUploadData, AttachmentUploadDataBuilder> {
  _$AttachmentUploadData? _$v;

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

  AttachmentUploadDataStatusEnum? _status;
  AttachmentUploadDataStatusEnum? get status => _$this._status;
  set status(AttachmentUploadDataStatusEnum? status) => _$this._status = status;

  DateTime? _createdAt;
  DateTime? get createdAt => _$this._createdAt;
  set createdAt(DateTime? createdAt) => _$this._createdAt = createdAt;

  AttachmentUploadDataBuilder() {
    AttachmentUploadData._defaults(this);
  }

  AttachmentUploadDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _attachmentId = $v.attachmentId;
      _uploadId = $v.uploadId;
      _chunkKeyEpoch = $v.chunkKeyEpoch;
      _manifestKeyEpoch = $v.manifestKeyEpoch;
      _manifestRevision = $v.manifestRevision;
      _chunkCount = $v.chunkCount;
      _totalCiphertextBytes = $v.totalCiphertextBytes;
      _status = $v.status;
      _createdAt = $v.createdAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AttachmentUploadData other) {
    _$v = other as _$AttachmentUploadData;
  }

  @override
  void update(void Function(AttachmentUploadDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  AttachmentUploadData build() => _build();

  _$AttachmentUploadData _build() {
    final _$result =
        _$v ??
        _$AttachmentUploadData._(
          attachmentId: BuiltValueNullFieldError.checkNotNull(
            attachmentId,
            r'AttachmentUploadData',
            'attachmentId',
          ),
          uploadId: BuiltValueNullFieldError.checkNotNull(
            uploadId,
            r'AttachmentUploadData',
            'uploadId',
          ),
          chunkKeyEpoch: BuiltValueNullFieldError.checkNotNull(
            chunkKeyEpoch,
            r'AttachmentUploadData',
            'chunkKeyEpoch',
          ),
          manifestKeyEpoch: BuiltValueNullFieldError.checkNotNull(
            manifestKeyEpoch,
            r'AttachmentUploadData',
            'manifestKeyEpoch',
          ),
          manifestRevision: BuiltValueNullFieldError.checkNotNull(
            manifestRevision,
            r'AttachmentUploadData',
            'manifestRevision',
          ),
          chunkCount: BuiltValueNullFieldError.checkNotNull(
            chunkCount,
            r'AttachmentUploadData',
            'chunkCount',
          ),
          totalCiphertextBytes: BuiltValueNullFieldError.checkNotNull(
            totalCiphertextBytes,
            r'AttachmentUploadData',
            'totalCiphertextBytes',
          ),
          status: BuiltValueNullFieldError.checkNotNull(
            status,
            r'AttachmentUploadData',
            'status',
          ),
          createdAt: BuiltValueNullFieldError.checkNotNull(
            createdAt,
            r'AttachmentUploadData',
            'createdAt',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
