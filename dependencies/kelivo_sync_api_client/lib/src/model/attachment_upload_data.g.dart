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
  final int keyEpoch;
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
    required this.keyEpoch,
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
        keyEpoch == other.keyEpoch &&
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
    _$hash = $jc(_$hash, keyEpoch.hashCode);
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
          ..add('keyEpoch', keyEpoch)
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

  int? _keyEpoch;
  int? get keyEpoch => _$this._keyEpoch;
  set keyEpoch(int? keyEpoch) => _$this._keyEpoch = keyEpoch;

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
      _keyEpoch = $v.keyEpoch;
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
          keyEpoch: BuiltValueNullFieldError.checkNotNull(
            keyEpoch,
            r'AttachmentUploadData',
            'keyEpoch',
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
