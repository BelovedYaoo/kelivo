// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_change.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const SyncChangeOperationEnum _$syncChangeOperationEnum_put =
    const SyncChangeOperationEnum._('put');

SyncChangeOperationEnum _$syncChangeOperationEnumValueOf(String name) {
  switch (name) {
    case 'put':
      return _$syncChangeOperationEnum_put;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<SyncChangeOperationEnum> _$syncChangeOperationEnumValues =
    BuiltSet<SyncChangeOperationEnum>(const <SyncChangeOperationEnum>[
      _$syncChangeOperationEnum_put,
    ]);

Serializer<SyncChangeOperationEnum> _$syncChangeOperationEnumSerializer =
    _$SyncChangeOperationEnumSerializer();

class _$SyncChangeOperationEnumSerializer
    implements PrimitiveSerializer<SyncChangeOperationEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'put': 'put',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'put': 'put',
  };

  @override
  final Iterable<Type> types = const <Type>[SyncChangeOperationEnum];
  @override
  final String wireName = 'SyncChangeOperationEnum';

  @override
  Object serialize(
    Serializers serializers,
    SyncChangeOperationEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  SyncChangeOperationEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => SyncChangeOperationEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$SyncChange extends SyncChange {
  @override
  final int changeSeq;
  @override
  final SyncChangeOperationEnum operation;
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

  factory _$SyncChange([void Function(SyncChangeBuilder)? updates]) =>
      (SyncChangeBuilder()..update(updates))._build();

  _$SyncChange._({
    required this.changeSeq,
    required this.operation,
    required this.recordId,
    required this.revision,
    required this.envelopeVersion,
    required this.keyEpoch,
    required this.ciphertext,
    required this.ciphertextBytes,
    required this.updatedAt,
    this.updatedByDeviceId,
  }) : super._();
  @override
  SyncChange rebuild(void Function(SyncChangeBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  SyncChangeBuilder toBuilder() => SyncChangeBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SyncChange &&
        changeSeq == other.changeSeq &&
        operation == other.operation &&
        recordId == other.recordId &&
        revision == other.revision &&
        envelopeVersion == other.envelopeVersion &&
        keyEpoch == other.keyEpoch &&
        ciphertext == other.ciphertext &&
        ciphertextBytes == other.ciphertextBytes &&
        updatedAt == other.updatedAt &&
        updatedByDeviceId == other.updatedByDeviceId;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, changeSeq.hashCode);
    _$hash = $jc(_$hash, operation.hashCode);
    _$hash = $jc(_$hash, recordId.hashCode);
    _$hash = $jc(_$hash, revision.hashCode);
    _$hash = $jc(_$hash, envelopeVersion.hashCode);
    _$hash = $jc(_$hash, keyEpoch.hashCode);
    _$hash = $jc(_$hash, ciphertext.hashCode);
    _$hash = $jc(_$hash, ciphertextBytes.hashCode);
    _$hash = $jc(_$hash, updatedAt.hashCode);
    _$hash = $jc(_$hash, updatedByDeviceId.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'SyncChange')
          ..add('changeSeq', changeSeq)
          ..add('operation', operation)
          ..add('recordId', recordId)
          ..add('revision', revision)
          ..add('envelopeVersion', envelopeVersion)
          ..add('keyEpoch', keyEpoch)
          ..add('ciphertext', ciphertext)
          ..add('ciphertextBytes', ciphertextBytes)
          ..add('updatedAt', updatedAt)
          ..add('updatedByDeviceId', updatedByDeviceId))
        .toString();
  }
}

class SyncChangeBuilder implements Builder<SyncChange, SyncChangeBuilder> {
  _$SyncChange? _$v;

  int? _changeSeq;
  int? get changeSeq => _$this._changeSeq;
  set changeSeq(int? changeSeq) => _$this._changeSeq = changeSeq;

  SyncChangeOperationEnum? _operation;
  SyncChangeOperationEnum? get operation => _$this._operation;
  set operation(SyncChangeOperationEnum? operation) =>
      _$this._operation = operation;

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

  SyncChangeBuilder() {
    SyncChange._defaults(this);
  }

  SyncChangeBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _changeSeq = $v.changeSeq;
      _operation = $v.operation;
      _recordId = $v.recordId;
      _revision = $v.revision;
      _envelopeVersion = $v.envelopeVersion;
      _keyEpoch = $v.keyEpoch;
      _ciphertext = $v.ciphertext;
      _ciphertextBytes = $v.ciphertextBytes;
      _updatedAt = $v.updatedAt;
      _updatedByDeviceId = $v.updatedByDeviceId;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SyncChange other) {
    _$v = other as _$SyncChange;
  }

  @override
  void update(void Function(SyncChangeBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SyncChange build() => _build();

  _$SyncChange _build() {
    final _$result =
        _$v ??
        _$SyncChange._(
          changeSeq: BuiltValueNullFieldError.checkNotNull(
            changeSeq,
            r'SyncChange',
            'changeSeq',
          ),
          operation: BuiltValueNullFieldError.checkNotNull(
            operation,
            r'SyncChange',
            'operation',
          ),
          recordId: BuiltValueNullFieldError.checkNotNull(
            recordId,
            r'SyncChange',
            'recordId',
          ),
          revision: BuiltValueNullFieldError.checkNotNull(
            revision,
            r'SyncChange',
            'revision',
          ),
          envelopeVersion: BuiltValueNullFieldError.checkNotNull(
            envelopeVersion,
            r'SyncChange',
            'envelopeVersion',
          ),
          keyEpoch: BuiltValueNullFieldError.checkNotNull(
            keyEpoch,
            r'SyncChange',
            'keyEpoch',
          ),
          ciphertext: BuiltValueNullFieldError.checkNotNull(
            ciphertext,
            r'SyncChange',
            'ciphertext',
          ),
          ciphertextBytes: BuiltValueNullFieldError.checkNotNull(
            ciphertextBytes,
            r'SyncChange',
            'ciphertextBytes',
          ),
          updatedAt: BuiltValueNullFieldError.checkNotNull(
            updatedAt,
            r'SyncChange',
            'updatedAt',
          ),
          updatedByDeviceId: updatedByDeviceId,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
