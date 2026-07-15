// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_applied_mutation_result.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const SyncAppliedMutationResultStatusEnum
_$syncAppliedMutationResultStatusEnum_applied =
    const SyncAppliedMutationResultStatusEnum._('applied');

SyncAppliedMutationResultStatusEnum
_$syncAppliedMutationResultStatusEnumValueOf(String name) {
  switch (name) {
    case 'applied':
      return _$syncAppliedMutationResultStatusEnum_applied;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<SyncAppliedMutationResultStatusEnum>
_$syncAppliedMutationResultStatusEnumValues =
    BuiltSet<SyncAppliedMutationResultStatusEnum>(
      const <SyncAppliedMutationResultStatusEnum>[
        _$syncAppliedMutationResultStatusEnum_applied,
      ],
    );

Serializer<SyncAppliedMutationResultStatusEnum>
_$syncAppliedMutationResultStatusEnumSerializer =
    _$SyncAppliedMutationResultStatusEnumSerializer();

class _$SyncAppliedMutationResultStatusEnumSerializer
    implements PrimitiveSerializer<SyncAppliedMutationResultStatusEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'applied': 'applied',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'applied': 'applied',
  };

  @override
  final Iterable<Type> types = const <Type>[
    SyncAppliedMutationResultStatusEnum,
  ];
  @override
  final String wireName = 'SyncAppliedMutationResultStatusEnum';

  @override
  Object serialize(
    Serializers serializers,
    SyncAppliedMutationResultStatusEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  SyncAppliedMutationResultStatusEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => SyncAppliedMutationResultStatusEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$SyncAppliedMutationResult extends SyncAppliedMutationResult {
  @override
  final String mutationId;
  @override
  final SyncAppliedMutationResultStatusEnum status;
  @override
  final int revision;
  @override
  final int changeSeq;

  factory _$SyncAppliedMutationResult([
    void Function(SyncAppliedMutationResultBuilder)? updates,
  ]) => (SyncAppliedMutationResultBuilder()..update(updates))._build();

  _$SyncAppliedMutationResult._({
    required this.mutationId,
    required this.status,
    required this.revision,
    required this.changeSeq,
  }) : super._();
  @override
  SyncAppliedMutationResult rebuild(
    void Function(SyncAppliedMutationResultBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  SyncAppliedMutationResultBuilder toBuilder() =>
      SyncAppliedMutationResultBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SyncAppliedMutationResult &&
        mutationId == other.mutationId &&
        status == other.status &&
        revision == other.revision &&
        changeSeq == other.changeSeq;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, mutationId.hashCode);
    _$hash = $jc(_$hash, status.hashCode);
    _$hash = $jc(_$hash, revision.hashCode);
    _$hash = $jc(_$hash, changeSeq.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'SyncAppliedMutationResult')
          ..add('mutationId', mutationId)
          ..add('status', status)
          ..add('revision', revision)
          ..add('changeSeq', changeSeq))
        .toString();
  }
}

class SyncAppliedMutationResultBuilder
    implements
        Builder<SyncAppliedMutationResult, SyncAppliedMutationResultBuilder> {
  _$SyncAppliedMutationResult? _$v;

  String? _mutationId;
  String? get mutationId => _$this._mutationId;
  set mutationId(String? mutationId) => _$this._mutationId = mutationId;

  SyncAppliedMutationResultStatusEnum? _status;
  SyncAppliedMutationResultStatusEnum? get status => _$this._status;
  set status(SyncAppliedMutationResultStatusEnum? status) =>
      _$this._status = status;

  int? _revision;
  int? get revision => _$this._revision;
  set revision(int? revision) => _$this._revision = revision;

  int? _changeSeq;
  int? get changeSeq => _$this._changeSeq;
  set changeSeq(int? changeSeq) => _$this._changeSeq = changeSeq;

  SyncAppliedMutationResultBuilder() {
    SyncAppliedMutationResult._defaults(this);
  }

  SyncAppliedMutationResultBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _mutationId = $v.mutationId;
      _status = $v.status;
      _revision = $v.revision;
      _changeSeq = $v.changeSeq;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SyncAppliedMutationResult other) {
    _$v = other as _$SyncAppliedMutationResult;
  }

  @override
  void update(void Function(SyncAppliedMutationResultBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SyncAppliedMutationResult build() => _build();

  _$SyncAppliedMutationResult _build() {
    final _$result =
        _$v ??
        _$SyncAppliedMutationResult._(
          mutationId: BuiltValueNullFieldError.checkNotNull(
            mutationId,
            r'SyncAppliedMutationResult',
            'mutationId',
          ),
          status: BuiltValueNullFieldError.checkNotNull(
            status,
            r'SyncAppliedMutationResult',
            'status',
          ),
          revision: BuiltValueNullFieldError.checkNotNull(
            revision,
            r'SyncAppliedMutationResult',
            'revision',
          ),
          changeSeq: BuiltValueNullFieldError.checkNotNull(
            changeSeq,
            r'SyncAppliedMutationResult',
            'changeSeq',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
