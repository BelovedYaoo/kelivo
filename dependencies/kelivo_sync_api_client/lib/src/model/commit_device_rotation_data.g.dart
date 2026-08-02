// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'commit_device_rotation_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const CommitDeviceRotationDataResultEnum
_$commitDeviceRotationDataResultEnum_committed =
    const CommitDeviceRotationDataResultEnum._('committed');

CommitDeviceRotationDataResultEnum _$commitDeviceRotationDataResultEnumValueOf(
  String name,
) {
  switch (name) {
    case 'committed':
      return _$commitDeviceRotationDataResultEnum_committed;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<CommitDeviceRotationDataResultEnum>
_$commitDeviceRotationDataResultEnumValues =
    BuiltSet<CommitDeviceRotationDataResultEnum>(
      const <CommitDeviceRotationDataResultEnum>[
        _$commitDeviceRotationDataResultEnum_committed,
      ],
    );

const CommitDeviceRotationDataDataRekeyPhaseEnum
_$commitDeviceRotationDataDataRekeyPhaseEnum_rekeyPending =
    const CommitDeviceRotationDataDataRekeyPhaseEnum._('rekeyPending');

CommitDeviceRotationDataDataRekeyPhaseEnum
_$commitDeviceRotationDataDataRekeyPhaseEnumValueOf(String name) {
  switch (name) {
    case 'rekeyPending':
      return _$commitDeviceRotationDataDataRekeyPhaseEnum_rekeyPending;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<CommitDeviceRotationDataDataRekeyPhaseEnum>
_$commitDeviceRotationDataDataRekeyPhaseEnumValues =
    BuiltSet<CommitDeviceRotationDataDataRekeyPhaseEnum>(
      const <CommitDeviceRotationDataDataRekeyPhaseEnum>[
        _$commitDeviceRotationDataDataRekeyPhaseEnum_rekeyPending,
      ],
    );

Serializer<CommitDeviceRotationDataResultEnum>
_$commitDeviceRotationDataResultEnumSerializer =
    _$CommitDeviceRotationDataResultEnumSerializer();
Serializer<CommitDeviceRotationDataDataRekeyPhaseEnum>
_$commitDeviceRotationDataDataRekeyPhaseEnumSerializer =
    _$CommitDeviceRotationDataDataRekeyPhaseEnumSerializer();

class _$CommitDeviceRotationDataResultEnumSerializer
    implements PrimitiveSerializer<CommitDeviceRotationDataResultEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'committed': 'committed',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'committed': 'committed',
  };

  @override
  final Iterable<Type> types = const <Type>[CommitDeviceRotationDataResultEnum];
  @override
  final String wireName = 'CommitDeviceRotationDataResultEnum';

  @override
  Object serialize(
    Serializers serializers,
    CommitDeviceRotationDataResultEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  CommitDeviceRotationDataResultEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => CommitDeviceRotationDataResultEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$CommitDeviceRotationDataDataRekeyPhaseEnumSerializer
    implements PrimitiveSerializer<CommitDeviceRotationDataDataRekeyPhaseEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'rekeyPending': 'rekey-pending',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'rekey-pending': 'rekeyPending',
  };

  @override
  final Iterable<Type> types = const <Type>[
    CommitDeviceRotationDataDataRekeyPhaseEnum,
  ];
  @override
  final String wireName = 'CommitDeviceRotationDataDataRekeyPhaseEnum';

  @override
  Object serialize(
    Serializers serializers,
    CommitDeviceRotationDataDataRekeyPhaseEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  CommitDeviceRotationDataDataRekeyPhaseEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => CommitDeviceRotationDataDataRekeyPhaseEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$CommitDeviceRotationData extends CommitDeviceRotationData {
  @override
  final CommitDeviceRotationDataResultEnum result;
  @override
  final String operationId;
  @override
  final String revokedDeviceId;
  @override
  final String? selfRevocationMutationId;
  @override
  final String? selfRevocationIntentDigest;
  @override
  final int fromGeneration;
  @override
  final int generation;
  @override
  final int keyEpoch;
  @override
  final CommitDeviceRotationDataDataRekeyPhaseEnum dataRekeyPhase;
  @override
  final String membershipManifestDigest;
  @override
  final DateTime committedAt;

  factory _$CommitDeviceRotationData([
    void Function(CommitDeviceRotationDataBuilder)? updates,
  ]) => (CommitDeviceRotationDataBuilder()..update(updates))._build();

  _$CommitDeviceRotationData._({
    required this.result,
    required this.operationId,
    required this.revokedDeviceId,
    this.selfRevocationMutationId,
    this.selfRevocationIntentDigest,
    required this.fromGeneration,
    required this.generation,
    required this.keyEpoch,
    required this.dataRekeyPhase,
    required this.membershipManifestDigest,
    required this.committedAt,
  }) : super._();
  @override
  CommitDeviceRotationData rebuild(
    void Function(CommitDeviceRotationDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  CommitDeviceRotationDataBuilder toBuilder() =>
      CommitDeviceRotationDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is CommitDeviceRotationData &&
        result == other.result &&
        operationId == other.operationId &&
        revokedDeviceId == other.revokedDeviceId &&
        selfRevocationMutationId == other.selfRevocationMutationId &&
        selfRevocationIntentDigest == other.selfRevocationIntentDigest &&
        fromGeneration == other.fromGeneration &&
        generation == other.generation &&
        keyEpoch == other.keyEpoch &&
        dataRekeyPhase == other.dataRekeyPhase &&
        membershipManifestDigest == other.membershipManifestDigest &&
        committedAt == other.committedAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, result.hashCode);
    _$hash = $jc(_$hash, operationId.hashCode);
    _$hash = $jc(_$hash, revokedDeviceId.hashCode);
    _$hash = $jc(_$hash, selfRevocationMutationId.hashCode);
    _$hash = $jc(_$hash, selfRevocationIntentDigest.hashCode);
    _$hash = $jc(_$hash, fromGeneration.hashCode);
    _$hash = $jc(_$hash, generation.hashCode);
    _$hash = $jc(_$hash, keyEpoch.hashCode);
    _$hash = $jc(_$hash, dataRekeyPhase.hashCode);
    _$hash = $jc(_$hash, membershipManifestDigest.hashCode);
    _$hash = $jc(_$hash, committedAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'CommitDeviceRotationData')
          ..add('result', result)
          ..add('operationId', operationId)
          ..add('revokedDeviceId', revokedDeviceId)
          ..add('selfRevocationMutationId', selfRevocationMutationId)
          ..add('selfRevocationIntentDigest', selfRevocationIntentDigest)
          ..add('fromGeneration', fromGeneration)
          ..add('generation', generation)
          ..add('keyEpoch', keyEpoch)
          ..add('dataRekeyPhase', dataRekeyPhase)
          ..add('membershipManifestDigest', membershipManifestDigest)
          ..add('committedAt', committedAt))
        .toString();
  }
}

class CommitDeviceRotationDataBuilder
    implements
        Builder<CommitDeviceRotationData, CommitDeviceRotationDataBuilder> {
  _$CommitDeviceRotationData? _$v;

  CommitDeviceRotationDataResultEnum? _result;
  CommitDeviceRotationDataResultEnum? get result => _$this._result;
  set result(CommitDeviceRotationDataResultEnum? result) =>
      _$this._result = result;

  String? _operationId;
  String? get operationId => _$this._operationId;
  set operationId(String? operationId) => _$this._operationId = operationId;

  String? _revokedDeviceId;
  String? get revokedDeviceId => _$this._revokedDeviceId;
  set revokedDeviceId(String? revokedDeviceId) =>
      _$this._revokedDeviceId = revokedDeviceId;

  String? _selfRevocationMutationId;
  String? get selfRevocationMutationId => _$this._selfRevocationMutationId;
  set selfRevocationMutationId(String? selfRevocationMutationId) =>
      _$this._selfRevocationMutationId = selfRevocationMutationId;

  String? _selfRevocationIntentDigest;
  String? get selfRevocationIntentDigest => _$this._selfRevocationIntentDigest;
  set selfRevocationIntentDigest(String? selfRevocationIntentDigest) =>
      _$this._selfRevocationIntentDigest = selfRevocationIntentDigest;

  int? _fromGeneration;
  int? get fromGeneration => _$this._fromGeneration;
  set fromGeneration(int? fromGeneration) =>
      _$this._fromGeneration = fromGeneration;

  int? _generation;
  int? get generation => _$this._generation;
  set generation(int? generation) => _$this._generation = generation;

  int? _keyEpoch;
  int? get keyEpoch => _$this._keyEpoch;
  set keyEpoch(int? keyEpoch) => _$this._keyEpoch = keyEpoch;

  CommitDeviceRotationDataDataRekeyPhaseEnum? _dataRekeyPhase;
  CommitDeviceRotationDataDataRekeyPhaseEnum? get dataRekeyPhase =>
      _$this._dataRekeyPhase;
  set dataRekeyPhase(
    CommitDeviceRotationDataDataRekeyPhaseEnum? dataRekeyPhase,
  ) => _$this._dataRekeyPhase = dataRekeyPhase;

  String? _membershipManifestDigest;
  String? get membershipManifestDigest => _$this._membershipManifestDigest;
  set membershipManifestDigest(String? membershipManifestDigest) =>
      _$this._membershipManifestDigest = membershipManifestDigest;

  DateTime? _committedAt;
  DateTime? get committedAt => _$this._committedAt;
  set committedAt(DateTime? committedAt) => _$this._committedAt = committedAt;

  CommitDeviceRotationDataBuilder() {
    CommitDeviceRotationData._defaults(this);
  }

  CommitDeviceRotationDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _result = $v.result;
      _operationId = $v.operationId;
      _revokedDeviceId = $v.revokedDeviceId;
      _selfRevocationMutationId = $v.selfRevocationMutationId;
      _selfRevocationIntentDigest = $v.selfRevocationIntentDigest;
      _fromGeneration = $v.fromGeneration;
      _generation = $v.generation;
      _keyEpoch = $v.keyEpoch;
      _dataRekeyPhase = $v.dataRekeyPhase;
      _membershipManifestDigest = $v.membershipManifestDigest;
      _committedAt = $v.committedAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(CommitDeviceRotationData other) {
    _$v = other as _$CommitDeviceRotationData;
  }

  @override
  void update(void Function(CommitDeviceRotationDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  CommitDeviceRotationData build() => _build();

  _$CommitDeviceRotationData _build() {
    final _$result =
        _$v ??
        _$CommitDeviceRotationData._(
          result: BuiltValueNullFieldError.checkNotNull(
            result,
            r'CommitDeviceRotationData',
            'result',
          ),
          operationId: BuiltValueNullFieldError.checkNotNull(
            operationId,
            r'CommitDeviceRotationData',
            'operationId',
          ),
          revokedDeviceId: BuiltValueNullFieldError.checkNotNull(
            revokedDeviceId,
            r'CommitDeviceRotationData',
            'revokedDeviceId',
          ),
          selfRevocationMutationId: selfRevocationMutationId,
          selfRevocationIntentDigest: selfRevocationIntentDigest,
          fromGeneration: BuiltValueNullFieldError.checkNotNull(
            fromGeneration,
            r'CommitDeviceRotationData',
            'fromGeneration',
          ),
          generation: BuiltValueNullFieldError.checkNotNull(
            generation,
            r'CommitDeviceRotationData',
            'generation',
          ),
          keyEpoch: BuiltValueNullFieldError.checkNotNull(
            keyEpoch,
            r'CommitDeviceRotationData',
            'keyEpoch',
          ),
          dataRekeyPhase: BuiltValueNullFieldError.checkNotNull(
            dataRekeyPhase,
            r'CommitDeviceRotationData',
            'dataRekeyPhase',
          ),
          membershipManifestDigest: BuiltValueNullFieldError.checkNotNull(
            membershipManifestDigest,
            r'CommitDeviceRotationData',
            'membershipManifestDigest',
          ),
          committedAt: BuiltValueNullFieldError.checkNotNull(
            committedAt,
            r'CommitDeviceRotationData',
            'committedAt',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
