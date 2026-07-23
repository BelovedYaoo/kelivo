// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_put_mutation.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const SyncPutMutationOperationEnum _$syncPutMutationOperationEnum_put =
    const SyncPutMutationOperationEnum._('put');

SyncPutMutationOperationEnum _$syncPutMutationOperationEnumValueOf(
  String name,
) {
  switch (name) {
    case 'put':
      return _$syncPutMutationOperationEnum_put;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<SyncPutMutationOperationEnum>
_$syncPutMutationOperationEnumValues = BuiltSet<SyncPutMutationOperationEnum>(
  const <SyncPutMutationOperationEnum>[_$syncPutMutationOperationEnum_put],
);

Serializer<SyncPutMutationOperationEnum>
_$syncPutMutationOperationEnumSerializer =
    _$SyncPutMutationOperationEnumSerializer();

class _$SyncPutMutationOperationEnumSerializer
    implements PrimitiveSerializer<SyncPutMutationOperationEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'put': 'put',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'put': 'put',
  };

  @override
  final Iterable<Type> types = const <Type>[SyncPutMutationOperationEnum];
  @override
  final String wireName = 'SyncPutMutationOperationEnum';

  @override
  Object serialize(
    Serializers serializers,
    SyncPutMutationOperationEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  SyncPutMutationOperationEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => SyncPutMutationOperationEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$SyncPutMutation extends SyncPutMutation {
  @override
  final String mutationId;
  @override
  final String recordId;
  @override
  final int expectedRevision;
  @override
  final SyncPutMutationOperationEnum operation;
  @override
  final int envelopeVersion;
  @override
  final int keyEpoch;
  @override
  final String ciphertext;

  factory _$SyncPutMutation([void Function(SyncPutMutationBuilder)? updates]) =>
      (SyncPutMutationBuilder()..update(updates))._build();

  _$SyncPutMutation._({
    required this.mutationId,
    required this.recordId,
    required this.expectedRevision,
    required this.operation,
    required this.envelopeVersion,
    required this.keyEpoch,
    required this.ciphertext,
  }) : super._();
  @override
  SyncPutMutation rebuild(void Function(SyncPutMutationBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  SyncPutMutationBuilder toBuilder() => SyncPutMutationBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SyncPutMutation &&
        mutationId == other.mutationId &&
        recordId == other.recordId &&
        expectedRevision == other.expectedRevision &&
        operation == other.operation &&
        envelopeVersion == other.envelopeVersion &&
        keyEpoch == other.keyEpoch &&
        ciphertext == other.ciphertext;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, mutationId.hashCode);
    _$hash = $jc(_$hash, recordId.hashCode);
    _$hash = $jc(_$hash, expectedRevision.hashCode);
    _$hash = $jc(_$hash, operation.hashCode);
    _$hash = $jc(_$hash, envelopeVersion.hashCode);
    _$hash = $jc(_$hash, keyEpoch.hashCode);
    _$hash = $jc(_$hash, ciphertext.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'SyncPutMutation')
          ..add('mutationId', mutationId)
          ..add('recordId', recordId)
          ..add('expectedRevision', expectedRevision)
          ..add('operation', operation)
          ..add('envelopeVersion', envelopeVersion)
          ..add('keyEpoch', keyEpoch)
          ..add('ciphertext', ciphertext))
        .toString();
  }
}

class SyncPutMutationBuilder
    implements Builder<SyncPutMutation, SyncPutMutationBuilder> {
  _$SyncPutMutation? _$v;

  String? _mutationId;
  String? get mutationId => _$this._mutationId;
  set mutationId(String? mutationId) => _$this._mutationId = mutationId;

  String? _recordId;
  String? get recordId => _$this._recordId;
  set recordId(String? recordId) => _$this._recordId = recordId;

  int? _expectedRevision;
  int? get expectedRevision => _$this._expectedRevision;
  set expectedRevision(int? expectedRevision) =>
      _$this._expectedRevision = expectedRevision;

  SyncPutMutationOperationEnum? _operation;
  SyncPutMutationOperationEnum? get operation => _$this._operation;
  set operation(SyncPutMutationOperationEnum? operation) =>
      _$this._operation = operation;

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

  SyncPutMutationBuilder() {
    SyncPutMutation._defaults(this);
  }

  SyncPutMutationBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _mutationId = $v.mutationId;
      _recordId = $v.recordId;
      _expectedRevision = $v.expectedRevision;
      _operation = $v.operation;
      _envelopeVersion = $v.envelopeVersion;
      _keyEpoch = $v.keyEpoch;
      _ciphertext = $v.ciphertext;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SyncPutMutation other) {
    _$v = other as _$SyncPutMutation;
  }

  @override
  void update(void Function(SyncPutMutationBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SyncPutMutation build() => _build();

  _$SyncPutMutation _build() {
    final _$result =
        _$v ??
        _$SyncPutMutation._(
          mutationId: BuiltValueNullFieldError.checkNotNull(
            mutationId,
            r'SyncPutMutation',
            'mutationId',
          ),
          recordId: BuiltValueNullFieldError.checkNotNull(
            recordId,
            r'SyncPutMutation',
            'recordId',
          ),
          expectedRevision: BuiltValueNullFieldError.checkNotNull(
            expectedRevision,
            r'SyncPutMutation',
            'expectedRevision',
          ),
          operation: BuiltValueNullFieldError.checkNotNull(
            operation,
            r'SyncPutMutation',
            'operation',
          ),
          envelopeVersion: BuiltValueNullFieldError.checkNotNull(
            envelopeVersion,
            r'SyncPutMutation',
            'envelopeVersion',
          ),
          keyEpoch: BuiltValueNullFieldError.checkNotNull(
            keyEpoch,
            r'SyncPutMutation',
            'keyEpoch',
          ),
          ciphertext: BuiltValueNullFieldError.checkNotNull(
            ciphertext,
            r'SyncPutMutation',
            'ciphertext',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
