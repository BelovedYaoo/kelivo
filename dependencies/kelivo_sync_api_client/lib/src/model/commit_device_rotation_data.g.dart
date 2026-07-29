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

Serializer<CommitDeviceRotationDataResultEnum>
_$commitDeviceRotationDataResultEnumSerializer =
    _$CommitDeviceRotationDataResultEnumSerializer();

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

class _$CommitDeviceRotationData extends CommitDeviceRotationData {
  @override
  final CommitDeviceRotationDataResultEnum result;
  @override
  final String operationId;
  @override
  final String revokedDeviceId;
  @override
  final int fromGeneration;
  @override
  final int generation;
  @override
  final int keyEpoch;
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
    required this.fromGeneration,
    required this.generation,
    required this.keyEpoch,
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
        fromGeneration == other.fromGeneration &&
        generation == other.generation &&
        keyEpoch == other.keyEpoch &&
        membershipManifestDigest == other.membershipManifestDigest &&
        committedAt == other.committedAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, result.hashCode);
    _$hash = $jc(_$hash, operationId.hashCode);
    _$hash = $jc(_$hash, revokedDeviceId.hashCode);
    _$hash = $jc(_$hash, fromGeneration.hashCode);
    _$hash = $jc(_$hash, generation.hashCode);
    _$hash = $jc(_$hash, keyEpoch.hashCode);
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
          ..add('fromGeneration', fromGeneration)
          ..add('generation', generation)
          ..add('keyEpoch', keyEpoch)
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
      _fromGeneration = $v.fromGeneration;
      _generation = $v.generation;
      _keyEpoch = $v.keyEpoch;
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
