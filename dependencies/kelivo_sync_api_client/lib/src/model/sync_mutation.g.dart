// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_mutation.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const SyncMutationOperationEnum _$syncMutationOperationEnum_put =
    const SyncMutationOperationEnum._('put');

SyncMutationOperationEnum _$syncMutationOperationEnumValueOf(String name) {
  switch (name) {
    case 'put':
      return _$syncMutationOperationEnum_put;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<SyncMutationOperationEnum> _$syncMutationOperationEnumValues =
    BuiltSet<SyncMutationOperationEnum>(const <SyncMutationOperationEnum>[
      _$syncMutationOperationEnum_put,
    ]);

Serializer<SyncMutationOperationEnum> _$syncMutationOperationEnumSerializer =
    _$SyncMutationOperationEnumSerializer();

class _$SyncMutationOperationEnumSerializer
    implements PrimitiveSerializer<SyncMutationOperationEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'put': 'put',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'put': 'put',
  };

  @override
  final Iterable<Type> types = const <Type>[SyncMutationOperationEnum];
  @override
  final String wireName = 'SyncMutationOperationEnum';

  @override
  Object serialize(
    Serializers serializers,
    SyncMutationOperationEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  SyncMutationOperationEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => SyncMutationOperationEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$SyncMutation extends SyncMutation {
  @override
  final String mutationId;
  @override
  final String recordId;
  @override
  final int expectedRevision;
  @override
  final SyncMutationOperationEnum operation;
  @override
  final int envelopeVersion;
  @override
  final int keyEpoch;
  @override
  final String ciphertext;

  factory _$SyncMutation([void Function(SyncMutationBuilder)? updates]) =>
      (SyncMutationBuilder()..update(updates))._build();

  _$SyncMutation._({
    required this.mutationId,
    required this.recordId,
    required this.expectedRevision,
    required this.operation,
    required this.envelopeVersion,
    required this.keyEpoch,
    required this.ciphertext,
  }) : super._();
  @override
  SyncMutation rebuild(void Function(SyncMutationBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  SyncMutationBuilder toBuilder() => SyncMutationBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SyncMutation &&
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
    return (newBuiltValueToStringHelper(r'SyncMutation')
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

class SyncMutationBuilder
    implements Builder<SyncMutation, SyncMutationBuilder> {
  _$SyncMutation? _$v;

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

  SyncMutationOperationEnum? _operation;
  SyncMutationOperationEnum? get operation => _$this._operation;
  set operation(SyncMutationOperationEnum? operation) =>
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

  SyncMutationBuilder() {
    SyncMutation._defaults(this);
  }

  SyncMutationBuilder get _$this {
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
  void replace(SyncMutation other) {
    _$v = other as _$SyncMutation;
  }

  @override
  void update(void Function(SyncMutationBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SyncMutation build() => _build();

  _$SyncMutation _build() {
    final _$result =
        _$v ??
        _$SyncMutation._(
          mutationId: BuiltValueNullFieldError.checkNotNull(
            mutationId,
            r'SyncMutation',
            'mutationId',
          ),
          recordId: BuiltValueNullFieldError.checkNotNull(
            recordId,
            r'SyncMutation',
            'recordId',
          ),
          expectedRevision: BuiltValueNullFieldError.checkNotNull(
            expectedRevision,
            r'SyncMutation',
            'expectedRevision',
          ),
          operation: BuiltValueNullFieldError.checkNotNull(
            operation,
            r'SyncMutation',
            'operation',
          ),
          envelopeVersion: BuiltValueNullFieldError.checkNotNull(
            envelopeVersion,
            r'SyncMutation',
            'envelopeVersion',
          ),
          keyEpoch: BuiltValueNullFieldError.checkNotNull(
            keyEpoch,
            r'SyncMutation',
            'keyEpoch',
          ),
          ciphertext: BuiltValueNullFieldError.checkNotNull(
            ciphertext,
            r'SyncMutation',
            'ciphertext',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
