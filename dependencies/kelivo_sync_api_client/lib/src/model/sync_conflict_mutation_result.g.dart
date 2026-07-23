// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_conflict_mutation_result.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const SyncConflictMutationResultStatusEnum
_$syncConflictMutationResultStatusEnum_conflict =
    const SyncConflictMutationResultStatusEnum._('conflict');

SyncConflictMutationResultStatusEnum
_$syncConflictMutationResultStatusEnumValueOf(String name) {
  switch (name) {
    case 'conflict':
      return _$syncConflictMutationResultStatusEnum_conflict;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<SyncConflictMutationResultStatusEnum>
_$syncConflictMutationResultStatusEnumValues =
    BuiltSet<SyncConflictMutationResultStatusEnum>(
      const <SyncConflictMutationResultStatusEnum>[
        _$syncConflictMutationResultStatusEnum_conflict,
      ],
    );

Serializer<SyncConflictMutationResultStatusEnum>
_$syncConflictMutationResultStatusEnumSerializer =
    _$SyncConflictMutationResultStatusEnumSerializer();

class _$SyncConflictMutationResultStatusEnumSerializer
    implements PrimitiveSerializer<SyncConflictMutationResultStatusEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'conflict': 'conflict',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'conflict': 'conflict',
  };

  @override
  final Iterable<Type> types = const <Type>[
    SyncConflictMutationResultStatusEnum,
  ];
  @override
  final String wireName = 'SyncConflictMutationResultStatusEnum';

  @override
  Object serialize(
    Serializers serializers,
    SyncConflictMutationResultStatusEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  SyncConflictMutationResultStatusEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => SyncConflictMutationResultStatusEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$SyncConflictMutationResult extends SyncConflictMutationResult {
  @override
  final String mutationId;
  @override
  final SyncConflictMutationResultStatusEnum status;
  @override
  final int? currentRevision;

  factory _$SyncConflictMutationResult([
    void Function(SyncConflictMutationResultBuilder)? updates,
  ]) => (SyncConflictMutationResultBuilder()..update(updates))._build();

  _$SyncConflictMutationResult._({
    required this.mutationId,
    required this.status,
    this.currentRevision,
  }) : super._();
  @override
  SyncConflictMutationResult rebuild(
    void Function(SyncConflictMutationResultBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  SyncConflictMutationResultBuilder toBuilder() =>
      SyncConflictMutationResultBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SyncConflictMutationResult &&
        mutationId == other.mutationId &&
        status == other.status &&
        currentRevision == other.currentRevision;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, mutationId.hashCode);
    _$hash = $jc(_$hash, status.hashCode);
    _$hash = $jc(_$hash, currentRevision.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'SyncConflictMutationResult')
          ..add('mutationId', mutationId)
          ..add('status', status)
          ..add('currentRevision', currentRevision))
        .toString();
  }
}

class SyncConflictMutationResultBuilder
    implements
        Builder<SyncConflictMutationResult, SyncConflictMutationResultBuilder> {
  _$SyncConflictMutationResult? _$v;

  String? _mutationId;
  String? get mutationId => _$this._mutationId;
  set mutationId(String? mutationId) => _$this._mutationId = mutationId;

  SyncConflictMutationResultStatusEnum? _status;
  SyncConflictMutationResultStatusEnum? get status => _$this._status;
  set status(SyncConflictMutationResultStatusEnum? status) =>
      _$this._status = status;

  int? _currentRevision;
  int? get currentRevision => _$this._currentRevision;
  set currentRevision(int? currentRevision) =>
      _$this._currentRevision = currentRevision;

  SyncConflictMutationResultBuilder() {
    SyncConflictMutationResult._defaults(this);
  }

  SyncConflictMutationResultBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _mutationId = $v.mutationId;
      _status = $v.status;
      _currentRevision = $v.currentRevision;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SyncConflictMutationResult other) {
    _$v = other as _$SyncConflictMutationResult;
  }

  @override
  void update(void Function(SyncConflictMutationResultBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SyncConflictMutationResult build() => _build();

  _$SyncConflictMutationResult _build() {
    final _$result =
        _$v ??
        _$SyncConflictMutationResult._(
          mutationId: BuiltValueNullFieldError.checkNotNull(
            mutationId,
            r'SyncConflictMutationResult',
            'mutationId',
          ),
          status: BuiltValueNullFieldError.checkNotNull(
            status,
            r'SyncConflictMutationResult',
            'status',
          ),
          currentRevision: currentRevision,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
