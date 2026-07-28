// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attachment_committed_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const AttachmentCommittedDataStatusEnum
_$attachmentCommittedDataStatusEnum_committed =
    const AttachmentCommittedDataStatusEnum._('committed');

AttachmentCommittedDataStatusEnum _$attachmentCommittedDataStatusEnumValueOf(
  String name,
) {
  switch (name) {
    case 'committed':
      return _$attachmentCommittedDataStatusEnum_committed;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<AttachmentCommittedDataStatusEnum>
_$attachmentCommittedDataStatusEnumValues =
    BuiltSet<AttachmentCommittedDataStatusEnum>(
      const <AttachmentCommittedDataStatusEnum>[
        _$attachmentCommittedDataStatusEnum_committed,
      ],
    );

Serializer<AttachmentCommittedDataStatusEnum>
_$attachmentCommittedDataStatusEnumSerializer =
    _$AttachmentCommittedDataStatusEnumSerializer();

class _$AttachmentCommittedDataStatusEnumSerializer
    implements PrimitiveSerializer<AttachmentCommittedDataStatusEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'committed': 'committed',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'committed': 'committed',
  };

  @override
  final Iterable<Type> types = const <Type>[AttachmentCommittedDataStatusEnum];
  @override
  final String wireName = 'AttachmentCommittedDataStatusEnum';

  @override
  Object serialize(
    Serializers serializers,
    AttachmentCommittedDataStatusEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  AttachmentCommittedDataStatusEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => AttachmentCommittedDataStatusEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$AttachmentCommittedData extends AttachmentCommittedData {
  @override
  final String attachmentId;
  @override
  final String uploadId;
  @override
  final int keyEpoch;
  @override
  final AttachmentCommittedDataStatusEnum status;
  @override
  final DateTime committedAt;

  factory _$AttachmentCommittedData([
    void Function(AttachmentCommittedDataBuilder)? updates,
  ]) => (AttachmentCommittedDataBuilder()..update(updates))._build();

  _$AttachmentCommittedData._({
    required this.attachmentId,
    required this.uploadId,
    required this.keyEpoch,
    required this.status,
    required this.committedAt,
  }) : super._();
  @override
  AttachmentCommittedData rebuild(
    void Function(AttachmentCommittedDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  AttachmentCommittedDataBuilder toBuilder() =>
      AttachmentCommittedDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AttachmentCommittedData &&
        attachmentId == other.attachmentId &&
        uploadId == other.uploadId &&
        keyEpoch == other.keyEpoch &&
        status == other.status &&
        committedAt == other.committedAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, attachmentId.hashCode);
    _$hash = $jc(_$hash, uploadId.hashCode);
    _$hash = $jc(_$hash, keyEpoch.hashCode);
    _$hash = $jc(_$hash, status.hashCode);
    _$hash = $jc(_$hash, committedAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'AttachmentCommittedData')
          ..add('attachmentId', attachmentId)
          ..add('uploadId', uploadId)
          ..add('keyEpoch', keyEpoch)
          ..add('status', status)
          ..add('committedAt', committedAt))
        .toString();
  }
}

class AttachmentCommittedDataBuilder
    implements
        Builder<AttachmentCommittedData, AttachmentCommittedDataBuilder> {
  _$AttachmentCommittedData? _$v;

  String? _attachmentId;
  String? get attachmentId => _$this._attachmentId;
  set attachmentId(String? attachmentId) => _$this._attachmentId = attachmentId;

  String? _uploadId;
  String? get uploadId => _$this._uploadId;
  set uploadId(String? uploadId) => _$this._uploadId = uploadId;

  int? _keyEpoch;
  int? get keyEpoch => _$this._keyEpoch;
  set keyEpoch(int? keyEpoch) => _$this._keyEpoch = keyEpoch;

  AttachmentCommittedDataStatusEnum? _status;
  AttachmentCommittedDataStatusEnum? get status => _$this._status;
  set status(AttachmentCommittedDataStatusEnum? status) =>
      _$this._status = status;

  DateTime? _committedAt;
  DateTime? get committedAt => _$this._committedAt;
  set committedAt(DateTime? committedAt) => _$this._committedAt = committedAt;

  AttachmentCommittedDataBuilder() {
    AttachmentCommittedData._defaults(this);
  }

  AttachmentCommittedDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _attachmentId = $v.attachmentId;
      _uploadId = $v.uploadId;
      _keyEpoch = $v.keyEpoch;
      _status = $v.status;
      _committedAt = $v.committedAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AttachmentCommittedData other) {
    _$v = other as _$AttachmentCommittedData;
  }

  @override
  void update(void Function(AttachmentCommittedDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  AttachmentCommittedData build() => _build();

  _$AttachmentCommittedData _build() {
    final _$result =
        _$v ??
        _$AttachmentCommittedData._(
          attachmentId: BuiltValueNullFieldError.checkNotNull(
            attachmentId,
            r'AttachmentCommittedData',
            'attachmentId',
          ),
          uploadId: BuiltValueNullFieldError.checkNotNull(
            uploadId,
            r'AttachmentCommittedData',
            'uploadId',
          ),
          keyEpoch: BuiltValueNullFieldError.checkNotNull(
            keyEpoch,
            r'AttachmentCommittedData',
            'keyEpoch',
          ),
          status: BuiltValueNullFieldError.checkNotNull(
            status,
            r'AttachmentCommittedData',
            'status',
          ),
          committedAt: BuiltValueNullFieldError.checkNotNull(
            committedAt,
            r'AttachmentCommittedData',
            'committedAt',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
