// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_put_change.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const SyncPutChangeOperationEnum _$syncPutChangeOperationEnum_put =
    const SyncPutChangeOperationEnum._('put');

SyncPutChangeOperationEnum _$syncPutChangeOperationEnumValueOf(String name) {
  switch (name) {
    case 'put':
      return _$syncPutChangeOperationEnum_put;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<SyncPutChangeOperationEnum> _$syncPutChangeOperationEnumValues =
    BuiltSet<SyncPutChangeOperationEnum>(const <SyncPutChangeOperationEnum>[
      _$syncPutChangeOperationEnum_put,
    ]);

Serializer<SyncPutChangeOperationEnum> _$syncPutChangeOperationEnumSerializer =
    _$SyncPutChangeOperationEnumSerializer();

class _$SyncPutChangeOperationEnumSerializer
    implements PrimitiveSerializer<SyncPutChangeOperationEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'put': 'put',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'put': 'put',
  };

  @override
  final Iterable<Type> types = const <Type>[SyncPutChangeOperationEnum];
  @override
  final String wireName = 'SyncPutChangeOperationEnum';

  @override
  Object serialize(
    Serializers serializers,
    SyncPutChangeOperationEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  SyncPutChangeOperationEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => SyncPutChangeOperationEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$SyncPutChange extends SyncPutChange {
  @override
  final int changeSeq;
  @override
  final SyncPutChangeOperationEnum operation;
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
  final JsonObject? deletedAt;
  @override
  final DateTime updatedAt;
  @override
  final String? updatedByDeviceId;

  factory _$SyncPutChange([void Function(SyncPutChangeBuilder)? updates]) =>
      (SyncPutChangeBuilder()..update(updates))._build();

  _$SyncPutChange._({
    required this.changeSeq,
    required this.operation,
    required this.recordId,
    required this.revision,
    required this.envelopeVersion,
    required this.keyEpoch,
    required this.ciphertext,
    required this.ciphertextBytes,
    this.deletedAt,
    required this.updatedAt,
    this.updatedByDeviceId,
  }) : super._();
  @override
  SyncPutChange rebuild(void Function(SyncPutChangeBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  SyncPutChangeBuilder toBuilder() => SyncPutChangeBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SyncPutChange &&
        changeSeq == other.changeSeq &&
        operation == other.operation &&
        recordId == other.recordId &&
        revision == other.revision &&
        envelopeVersion == other.envelopeVersion &&
        keyEpoch == other.keyEpoch &&
        ciphertext == other.ciphertext &&
        ciphertextBytes == other.ciphertextBytes &&
        deletedAt == other.deletedAt &&
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
    _$hash = $jc(_$hash, deletedAt.hashCode);
    _$hash = $jc(_$hash, updatedAt.hashCode);
    _$hash = $jc(_$hash, updatedByDeviceId.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'SyncPutChange')
          ..add('changeSeq', changeSeq)
          ..add('operation', operation)
          ..add('recordId', recordId)
          ..add('revision', revision)
          ..add('envelopeVersion', envelopeVersion)
          ..add('keyEpoch', keyEpoch)
          ..add('ciphertext', ciphertext)
          ..add('ciphertextBytes', ciphertextBytes)
          ..add('deletedAt', deletedAt)
          ..add('updatedAt', updatedAt)
          ..add('updatedByDeviceId', updatedByDeviceId))
        .toString();
  }
}

class SyncPutChangeBuilder
    implements Builder<SyncPutChange, SyncPutChangeBuilder> {
  _$SyncPutChange? _$v;

  int? _changeSeq;
  int? get changeSeq => _$this._changeSeq;
  set changeSeq(int? changeSeq) => _$this._changeSeq = changeSeq;

  SyncPutChangeOperationEnum? _operation;
  SyncPutChangeOperationEnum? get operation => _$this._operation;
  set operation(SyncPutChangeOperationEnum? operation) =>
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

  JsonObject? _deletedAt;
  JsonObject? get deletedAt => _$this._deletedAt;
  set deletedAt(JsonObject? deletedAt) => _$this._deletedAt = deletedAt;

  DateTime? _updatedAt;
  DateTime? get updatedAt => _$this._updatedAt;
  set updatedAt(DateTime? updatedAt) => _$this._updatedAt = updatedAt;

  String? _updatedByDeviceId;
  String? get updatedByDeviceId => _$this._updatedByDeviceId;
  set updatedByDeviceId(String? updatedByDeviceId) =>
      _$this._updatedByDeviceId = updatedByDeviceId;

  SyncPutChangeBuilder() {
    SyncPutChange._defaults(this);
  }

  SyncPutChangeBuilder get _$this {
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
      _deletedAt = $v.deletedAt;
      _updatedAt = $v.updatedAt;
      _updatedByDeviceId = $v.updatedByDeviceId;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SyncPutChange other) {
    _$v = other as _$SyncPutChange;
  }

  @override
  void update(void Function(SyncPutChangeBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SyncPutChange build() => _build();

  _$SyncPutChange _build() {
    final _$result =
        _$v ??
        _$SyncPutChange._(
          changeSeq: BuiltValueNullFieldError.checkNotNull(
            changeSeq,
            r'SyncPutChange',
            'changeSeq',
          ),
          operation: BuiltValueNullFieldError.checkNotNull(
            operation,
            r'SyncPutChange',
            'operation',
          ),
          recordId: BuiltValueNullFieldError.checkNotNull(
            recordId,
            r'SyncPutChange',
            'recordId',
          ),
          revision: BuiltValueNullFieldError.checkNotNull(
            revision,
            r'SyncPutChange',
            'revision',
          ),
          envelopeVersion: BuiltValueNullFieldError.checkNotNull(
            envelopeVersion,
            r'SyncPutChange',
            'envelopeVersion',
          ),
          keyEpoch: BuiltValueNullFieldError.checkNotNull(
            keyEpoch,
            r'SyncPutChange',
            'keyEpoch',
          ),
          ciphertext: BuiltValueNullFieldError.checkNotNull(
            ciphertext,
            r'SyncPutChange',
            'ciphertext',
          ),
          ciphertextBytes: BuiltValueNullFieldError.checkNotNull(
            ciphertextBytes,
            r'SyncPutChange',
            'ciphertextBytes',
          ),
          deletedAt: deletedAt,
          updatedAt: BuiltValueNullFieldError.checkNotNull(
            updatedAt,
            r'SyncPutChange',
            'updatedAt',
          ),
          updatedByDeviceId: updatedByDeviceId,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
