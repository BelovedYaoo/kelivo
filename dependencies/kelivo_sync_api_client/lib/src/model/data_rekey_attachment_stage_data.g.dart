// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_rekey_attachment_stage_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const DataRekeyAttachmentStageDataResultEnum
_$dataRekeyAttachmentStageDataResultEnum_staged =
    const DataRekeyAttachmentStageDataResultEnum._('staged');

DataRekeyAttachmentStageDataResultEnum
_$dataRekeyAttachmentStageDataResultEnumValueOf(String name) {
  switch (name) {
    case 'staged':
      return _$dataRekeyAttachmentStageDataResultEnum_staged;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<DataRekeyAttachmentStageDataResultEnum>
_$dataRekeyAttachmentStageDataResultEnumValues =
    BuiltSet<DataRekeyAttachmentStageDataResultEnum>(
      const <DataRekeyAttachmentStageDataResultEnum>[
        _$dataRekeyAttachmentStageDataResultEnum_staged,
      ],
    );

Serializer<DataRekeyAttachmentStageDataResultEnum>
_$dataRekeyAttachmentStageDataResultEnumSerializer =
    _$DataRekeyAttachmentStageDataResultEnumSerializer();

class _$DataRekeyAttachmentStageDataResultEnumSerializer
    implements PrimitiveSerializer<DataRekeyAttachmentStageDataResultEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'staged': 'staged',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'staged': 'staged',
  };

  @override
  final Iterable<Type> types = const <Type>[
    DataRekeyAttachmentStageDataResultEnum,
  ];
  @override
  final String wireName = 'DataRekeyAttachmentStageDataResultEnum';

  @override
  Object serialize(
    Serializers serializers,
    DataRekeyAttachmentStageDataResultEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  DataRekeyAttachmentStageDataResultEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => DataRekeyAttachmentStageDataResultEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$DataRekeyAttachmentStageData extends DataRekeyAttachmentStageData {
  @override
  final DataRekeyAttachmentStageDataResultEnum result;
  @override
  final String operationId;
  @override
  final String mutationId;
  @override
  final String attachmentId;
  @override
  final String uploadId;
  @override
  final int manifestRevision;
  @override
  final int leaseVersion;

  factory _$DataRekeyAttachmentStageData([
    void Function(DataRekeyAttachmentStageDataBuilder)? updates,
  ]) => (DataRekeyAttachmentStageDataBuilder()..update(updates))._build();

  _$DataRekeyAttachmentStageData._({
    required this.result,
    required this.operationId,
    required this.mutationId,
    required this.attachmentId,
    required this.uploadId,
    required this.manifestRevision,
    required this.leaseVersion,
  }) : super._();
  @override
  DataRekeyAttachmentStageData rebuild(
    void Function(DataRekeyAttachmentStageDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  DataRekeyAttachmentStageDataBuilder toBuilder() =>
      DataRekeyAttachmentStageDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DataRekeyAttachmentStageData &&
        result == other.result &&
        operationId == other.operationId &&
        mutationId == other.mutationId &&
        attachmentId == other.attachmentId &&
        uploadId == other.uploadId &&
        manifestRevision == other.manifestRevision &&
        leaseVersion == other.leaseVersion;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, result.hashCode);
    _$hash = $jc(_$hash, operationId.hashCode);
    _$hash = $jc(_$hash, mutationId.hashCode);
    _$hash = $jc(_$hash, attachmentId.hashCode);
    _$hash = $jc(_$hash, uploadId.hashCode);
    _$hash = $jc(_$hash, manifestRevision.hashCode);
    _$hash = $jc(_$hash, leaseVersion.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'DataRekeyAttachmentStageData')
          ..add('result', result)
          ..add('operationId', operationId)
          ..add('mutationId', mutationId)
          ..add('attachmentId', attachmentId)
          ..add('uploadId', uploadId)
          ..add('manifestRevision', manifestRevision)
          ..add('leaseVersion', leaseVersion))
        .toString();
  }
}

class DataRekeyAttachmentStageDataBuilder
    implements
        Builder<
          DataRekeyAttachmentStageData,
          DataRekeyAttachmentStageDataBuilder
        > {
  _$DataRekeyAttachmentStageData? _$v;

  DataRekeyAttachmentStageDataResultEnum? _result;
  DataRekeyAttachmentStageDataResultEnum? get result => _$this._result;
  set result(DataRekeyAttachmentStageDataResultEnum? result) =>
      _$this._result = result;

  String? _operationId;
  String? get operationId => _$this._operationId;
  set operationId(String? operationId) => _$this._operationId = operationId;

  String? _mutationId;
  String? get mutationId => _$this._mutationId;
  set mutationId(String? mutationId) => _$this._mutationId = mutationId;

  String? _attachmentId;
  String? get attachmentId => _$this._attachmentId;
  set attachmentId(String? attachmentId) => _$this._attachmentId = attachmentId;

  String? _uploadId;
  String? get uploadId => _$this._uploadId;
  set uploadId(String? uploadId) => _$this._uploadId = uploadId;

  int? _manifestRevision;
  int? get manifestRevision => _$this._manifestRevision;
  set manifestRevision(int? manifestRevision) =>
      _$this._manifestRevision = manifestRevision;

  int? _leaseVersion;
  int? get leaseVersion => _$this._leaseVersion;
  set leaseVersion(int? leaseVersion) => _$this._leaseVersion = leaseVersion;

  DataRekeyAttachmentStageDataBuilder() {
    DataRekeyAttachmentStageData._defaults(this);
  }

  DataRekeyAttachmentStageDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _result = $v.result;
      _operationId = $v.operationId;
      _mutationId = $v.mutationId;
      _attachmentId = $v.attachmentId;
      _uploadId = $v.uploadId;
      _manifestRevision = $v.manifestRevision;
      _leaseVersion = $v.leaseVersion;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DataRekeyAttachmentStageData other) {
    _$v = other as _$DataRekeyAttachmentStageData;
  }

  @override
  void update(void Function(DataRekeyAttachmentStageDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DataRekeyAttachmentStageData build() => _build();

  _$DataRekeyAttachmentStageData _build() {
    final _$result =
        _$v ??
        _$DataRekeyAttachmentStageData._(
          result: BuiltValueNullFieldError.checkNotNull(
            result,
            r'DataRekeyAttachmentStageData',
            'result',
          ),
          operationId: BuiltValueNullFieldError.checkNotNull(
            operationId,
            r'DataRekeyAttachmentStageData',
            'operationId',
          ),
          mutationId: BuiltValueNullFieldError.checkNotNull(
            mutationId,
            r'DataRekeyAttachmentStageData',
            'mutationId',
          ),
          attachmentId: BuiltValueNullFieldError.checkNotNull(
            attachmentId,
            r'DataRekeyAttachmentStageData',
            'attachmentId',
          ),
          uploadId: BuiltValueNullFieldError.checkNotNull(
            uploadId,
            r'DataRekeyAttachmentStageData',
            'uploadId',
          ),
          manifestRevision: BuiltValueNullFieldError.checkNotNull(
            manifestRevision,
            r'DataRekeyAttachmentStageData',
            'manifestRevision',
          ),
          leaseVersion: BuiltValueNullFieldError.checkNotNull(
            leaseVersion,
            r'DataRekeyAttachmentStageData',
            'leaseVersion',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
