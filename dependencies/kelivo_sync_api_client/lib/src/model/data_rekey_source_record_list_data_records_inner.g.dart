// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_rekey_source_record_list_data_records_inner.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const DataRekeySourceRecordListDataRecordsInnerKindEnum
_$dataRekeySourceRecordListDataRecordsInnerKindEnum_put =
    const DataRekeySourceRecordListDataRecordsInnerKindEnum._('put');

DataRekeySourceRecordListDataRecordsInnerKindEnum
_$dataRekeySourceRecordListDataRecordsInnerKindEnumValueOf(String name) {
  switch (name) {
    case 'put':
      return _$dataRekeySourceRecordListDataRecordsInnerKindEnum_put;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<DataRekeySourceRecordListDataRecordsInnerKindEnum>
_$dataRekeySourceRecordListDataRecordsInnerKindEnumValues =
    BuiltSet<DataRekeySourceRecordListDataRecordsInnerKindEnum>(
      const <DataRekeySourceRecordListDataRecordsInnerKindEnum>[
        _$dataRekeySourceRecordListDataRecordsInnerKindEnum_put,
      ],
    );

Serializer<DataRekeySourceRecordListDataRecordsInnerKindEnum>
_$dataRekeySourceRecordListDataRecordsInnerKindEnumSerializer =
    _$DataRekeySourceRecordListDataRecordsInnerKindEnumSerializer();

class _$DataRekeySourceRecordListDataRecordsInnerKindEnumSerializer
    implements
        PrimitiveSerializer<DataRekeySourceRecordListDataRecordsInnerKindEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'put': 'put',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'put': 'put',
  };

  @override
  final Iterable<Type> types = const <Type>[
    DataRekeySourceRecordListDataRecordsInnerKindEnum,
  ];
  @override
  final String wireName = 'DataRekeySourceRecordListDataRecordsInnerKindEnum';

  @override
  Object serialize(
    Serializers serializers,
    DataRekeySourceRecordListDataRecordsInnerKindEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  DataRekeySourceRecordListDataRecordsInnerKindEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => DataRekeySourceRecordListDataRecordsInnerKindEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$DataRekeySourceRecordListDataRecordsInner
    extends DataRekeySourceRecordListDataRecordsInner {
  @override
  final String recordId;
  @override
  final int revision;
  @override
  final int envelopeVersion;
  @override
  final int keyEpoch;
  @override
  final String ciphertext;
  @override
  final int ciphertextBytes;
  @override
  final DateTime updatedAt;
  @override
  final String? updatedByDeviceId;
  @override
  final int lastChangeSeq;
  @override
  final DataRekeySourceRecordListDataRecordsInnerKindEnum kind;
  @override
  final String ciphertextDigest;

  factory _$DataRekeySourceRecordListDataRecordsInner([
    void Function(DataRekeySourceRecordListDataRecordsInnerBuilder)? updates,
  ]) => (DataRekeySourceRecordListDataRecordsInnerBuilder()..update(updates))
      ._build();

  _$DataRekeySourceRecordListDataRecordsInner._({
    required this.recordId,
    required this.revision,
    required this.envelopeVersion,
    required this.keyEpoch,
    required this.ciphertext,
    required this.ciphertextBytes,
    required this.updatedAt,
    this.updatedByDeviceId,
    required this.lastChangeSeq,
    required this.kind,
    required this.ciphertextDigest,
  }) : super._();
  @override
  DataRekeySourceRecordListDataRecordsInner rebuild(
    void Function(DataRekeySourceRecordListDataRecordsInnerBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  DataRekeySourceRecordListDataRecordsInnerBuilder toBuilder() =>
      DataRekeySourceRecordListDataRecordsInnerBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DataRekeySourceRecordListDataRecordsInner &&
        recordId == other.recordId &&
        revision == other.revision &&
        envelopeVersion == other.envelopeVersion &&
        keyEpoch == other.keyEpoch &&
        ciphertext == other.ciphertext &&
        ciphertextBytes == other.ciphertextBytes &&
        updatedAt == other.updatedAt &&
        updatedByDeviceId == other.updatedByDeviceId &&
        lastChangeSeq == other.lastChangeSeq &&
        kind == other.kind &&
        ciphertextDigest == other.ciphertextDigest;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, recordId.hashCode);
    _$hash = $jc(_$hash, revision.hashCode);
    _$hash = $jc(_$hash, envelopeVersion.hashCode);
    _$hash = $jc(_$hash, keyEpoch.hashCode);
    _$hash = $jc(_$hash, ciphertext.hashCode);
    _$hash = $jc(_$hash, ciphertextBytes.hashCode);
    _$hash = $jc(_$hash, updatedAt.hashCode);
    _$hash = $jc(_$hash, updatedByDeviceId.hashCode);
    _$hash = $jc(_$hash, lastChangeSeq.hashCode);
    _$hash = $jc(_$hash, kind.hashCode);
    _$hash = $jc(_$hash, ciphertextDigest.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(
            r'DataRekeySourceRecordListDataRecordsInner',
          )
          ..add('recordId', recordId)
          ..add('revision', revision)
          ..add('envelopeVersion', envelopeVersion)
          ..add('keyEpoch', keyEpoch)
          ..add('ciphertext', ciphertext)
          ..add('ciphertextBytes', ciphertextBytes)
          ..add('updatedAt', updatedAt)
          ..add('updatedByDeviceId', updatedByDeviceId)
          ..add('lastChangeSeq', lastChangeSeq)
          ..add('kind', kind)
          ..add('ciphertextDigest', ciphertextDigest))
        .toString();
  }
}

class DataRekeySourceRecordListDataRecordsInnerBuilder
    implements
        Builder<
          DataRekeySourceRecordListDataRecordsInner,
          DataRekeySourceRecordListDataRecordsInnerBuilder
        > {
  _$DataRekeySourceRecordListDataRecordsInner? _$v;

  String? _recordId;
  String? get recordId => _$this._recordId;
  set recordId(String? recordId) => _$this._recordId = recordId;

  int? _revision;
  int? get revision => _$this._revision;
  set revision(int? revision) => _$this._revision = revision;

  int? _envelopeVersion;
  int? get envelopeVersion => _$this._envelopeVersion;
  set envelopeVersion(int? envelopeVersion) =>
      _$this._envelopeVersion = envelopeVersion;

  int? _keyEpoch;
  int? get keyEpoch => _$this._keyEpoch;
  set keyEpoch(int? keyEpoch) => _$this._keyEpoch = keyEpoch;

  String? _ciphertext;
  String? get ciphertext => _$this._ciphertext;
  set ciphertext(String? ciphertext) => _$this._ciphertext = ciphertext;

  int? _ciphertextBytes;
  int? get ciphertextBytes => _$this._ciphertextBytes;
  set ciphertextBytes(int? ciphertextBytes) =>
      _$this._ciphertextBytes = ciphertextBytes;

  DateTime? _updatedAt;
  DateTime? get updatedAt => _$this._updatedAt;
  set updatedAt(DateTime? updatedAt) => _$this._updatedAt = updatedAt;

  String? _updatedByDeviceId;
  String? get updatedByDeviceId => _$this._updatedByDeviceId;
  set updatedByDeviceId(String? updatedByDeviceId) =>
      _$this._updatedByDeviceId = updatedByDeviceId;

  int? _lastChangeSeq;
  int? get lastChangeSeq => _$this._lastChangeSeq;
  set lastChangeSeq(int? lastChangeSeq) =>
      _$this._lastChangeSeq = lastChangeSeq;

  DataRekeySourceRecordListDataRecordsInnerKindEnum? _kind;
  DataRekeySourceRecordListDataRecordsInnerKindEnum? get kind => _$this._kind;
  set kind(DataRekeySourceRecordListDataRecordsInnerKindEnum? kind) =>
      _$this._kind = kind;

  String? _ciphertextDigest;
  String? get ciphertextDigest => _$this._ciphertextDigest;
  set ciphertextDigest(String? ciphertextDigest) =>
      _$this._ciphertextDigest = ciphertextDigest;

  DataRekeySourceRecordListDataRecordsInnerBuilder() {
    DataRekeySourceRecordListDataRecordsInner._defaults(this);
  }

  DataRekeySourceRecordListDataRecordsInnerBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _recordId = $v.recordId;
      _revision = $v.revision;
      _envelopeVersion = $v.envelopeVersion;
      _keyEpoch = $v.keyEpoch;
      _ciphertext = $v.ciphertext;
      _ciphertextBytes = $v.ciphertextBytes;
      _updatedAt = $v.updatedAt;
      _updatedByDeviceId = $v.updatedByDeviceId;
      _lastChangeSeq = $v.lastChangeSeq;
      _kind = $v.kind;
      _ciphertextDigest = $v.ciphertextDigest;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DataRekeySourceRecordListDataRecordsInner other) {
    _$v = other as _$DataRekeySourceRecordListDataRecordsInner;
  }

  @override
  void update(
    void Function(DataRekeySourceRecordListDataRecordsInnerBuilder)? updates,
  ) {
    if (updates != null) updates(this);
  }

  @override
  DataRekeySourceRecordListDataRecordsInner build() => _build();

  _$DataRekeySourceRecordListDataRecordsInner _build() {
    final _$result =
        _$v ??
        _$DataRekeySourceRecordListDataRecordsInner._(
          recordId: BuiltValueNullFieldError.checkNotNull(
            recordId,
            r'DataRekeySourceRecordListDataRecordsInner',
            'recordId',
          ),
          revision: BuiltValueNullFieldError.checkNotNull(
            revision,
            r'DataRekeySourceRecordListDataRecordsInner',
            'revision',
          ),
          envelopeVersion: BuiltValueNullFieldError.checkNotNull(
            envelopeVersion,
            r'DataRekeySourceRecordListDataRecordsInner',
            'envelopeVersion',
          ),
          keyEpoch: BuiltValueNullFieldError.checkNotNull(
            keyEpoch,
            r'DataRekeySourceRecordListDataRecordsInner',
            'keyEpoch',
          ),
          ciphertext: BuiltValueNullFieldError.checkNotNull(
            ciphertext,
            r'DataRekeySourceRecordListDataRecordsInner',
            'ciphertext',
          ),
          ciphertextBytes: BuiltValueNullFieldError.checkNotNull(
            ciphertextBytes,
            r'DataRekeySourceRecordListDataRecordsInner',
            'ciphertextBytes',
          ),
          updatedAt: BuiltValueNullFieldError.checkNotNull(
            updatedAt,
            r'DataRekeySourceRecordListDataRecordsInner',
            'updatedAt',
          ),
          updatedByDeviceId: updatedByDeviceId,
          lastChangeSeq: BuiltValueNullFieldError.checkNotNull(
            lastChangeSeq,
            r'DataRekeySourceRecordListDataRecordsInner',
            'lastChangeSeq',
          ),
          kind: BuiltValueNullFieldError.checkNotNull(
            kind,
            r'DataRekeySourceRecordListDataRecordsInner',
            'kind',
          ),
          ciphertextDigest: BuiltValueNullFieldError.checkNotNull(
            ciphertextDigest,
            r'DataRekeySourceRecordListDataRecordsInner',
            'ciphertextDigest',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
