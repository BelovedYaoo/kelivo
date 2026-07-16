// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_field_conflict_mutation_result.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const SyncFieldConflictMutationResultStatusEnum
_$syncFieldConflictMutationResultStatusEnum_conflict =
    const SyncFieldConflictMutationResultStatusEnum._('conflict');

SyncFieldConflictMutationResultStatusEnum
_$syncFieldConflictMutationResultStatusEnumValueOf(String name) {
  switch (name) {
    case 'conflict':
      return _$syncFieldConflictMutationResultStatusEnum_conflict;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<SyncFieldConflictMutationResultStatusEnum>
_$syncFieldConflictMutationResultStatusEnumValues =
    BuiltSet<SyncFieldConflictMutationResultStatusEnum>(
      const <SyncFieldConflictMutationResultStatusEnum>[
        _$syncFieldConflictMutationResultStatusEnum_conflict,
      ],
    );

const SyncFieldConflictMutationResultReasonEnum
_$syncFieldConflictMutationResultReasonEnum_fieldConflict =
    const SyncFieldConflictMutationResultReasonEnum._('fieldConflict');

SyncFieldConflictMutationResultReasonEnum
_$syncFieldConflictMutationResultReasonEnumValueOf(String name) {
  switch (name) {
    case 'fieldConflict':
      return _$syncFieldConflictMutationResultReasonEnum_fieldConflict;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<SyncFieldConflictMutationResultReasonEnum>
_$syncFieldConflictMutationResultReasonEnumValues =
    BuiltSet<SyncFieldConflictMutationResultReasonEnum>(
      const <SyncFieldConflictMutationResultReasonEnum>[
        _$syncFieldConflictMutationResultReasonEnum_fieldConflict,
      ],
    );

Serializer<SyncFieldConflictMutationResultStatusEnum>
_$syncFieldConflictMutationResultStatusEnumSerializer =
    _$SyncFieldConflictMutationResultStatusEnumSerializer();
Serializer<SyncFieldConflictMutationResultReasonEnum>
_$syncFieldConflictMutationResultReasonEnumSerializer =
    _$SyncFieldConflictMutationResultReasonEnumSerializer();

class _$SyncFieldConflictMutationResultStatusEnumSerializer
    implements PrimitiveSerializer<SyncFieldConflictMutationResultStatusEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'conflict': 'conflict',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'conflict': 'conflict',
  };

  @override
  final Iterable<Type> types = const <Type>[
    SyncFieldConflictMutationResultStatusEnum,
  ];
  @override
  final String wireName = 'SyncFieldConflictMutationResultStatusEnum';

  @override
  Object serialize(
    Serializers serializers,
    SyncFieldConflictMutationResultStatusEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  SyncFieldConflictMutationResultStatusEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => SyncFieldConflictMutationResultStatusEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$SyncFieldConflictMutationResultReasonEnumSerializer
    implements PrimitiveSerializer<SyncFieldConflictMutationResultReasonEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'fieldConflict': 'field-conflict',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'field-conflict': 'fieldConflict',
  };

  @override
  final Iterable<Type> types = const <Type>[
    SyncFieldConflictMutationResultReasonEnum,
  ];
  @override
  final String wireName = 'SyncFieldConflictMutationResultReasonEnum';

  @override
  Object serialize(
    Serializers serializers,
    SyncFieldConflictMutationResultReasonEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  SyncFieldConflictMutationResultReasonEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => SyncFieldConflictMutationResultReasonEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$SyncFieldConflictMutationResult
    extends SyncFieldConflictMutationResult {
  @override
  final String mutationId;
  @override
  final SyncFieldConflictMutationResultStatusEnum status;
  @override
  final int currentRevision;
  @override
  final SyncFieldConflictMutationResultReasonEnum reason;
  @override
  final String conflictId;
  @override
  final BuiltList<String> conflictingPaths;
  @override
  final int? changeSeq;

  factory _$SyncFieldConflictMutationResult([
    void Function(SyncFieldConflictMutationResultBuilder)? updates,
  ]) => (SyncFieldConflictMutationResultBuilder()..update(updates))._build();

  _$SyncFieldConflictMutationResult._({
    required this.mutationId,
    required this.status,
    required this.currentRevision,
    required this.reason,
    required this.conflictId,
    required this.conflictingPaths,
    this.changeSeq,
  }) : super._();
  @override
  SyncFieldConflictMutationResult rebuild(
    void Function(SyncFieldConflictMutationResultBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  SyncFieldConflictMutationResultBuilder toBuilder() =>
      SyncFieldConflictMutationResultBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SyncFieldConflictMutationResult &&
        mutationId == other.mutationId &&
        status == other.status &&
        currentRevision == other.currentRevision &&
        reason == other.reason &&
        conflictId == other.conflictId &&
        conflictingPaths == other.conflictingPaths &&
        changeSeq == other.changeSeq;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, mutationId.hashCode);
    _$hash = $jc(_$hash, status.hashCode);
    _$hash = $jc(_$hash, currentRevision.hashCode);
    _$hash = $jc(_$hash, reason.hashCode);
    _$hash = $jc(_$hash, conflictId.hashCode);
    _$hash = $jc(_$hash, conflictingPaths.hashCode);
    _$hash = $jc(_$hash, changeSeq.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'SyncFieldConflictMutationResult')
          ..add('mutationId', mutationId)
          ..add('status', status)
          ..add('currentRevision', currentRevision)
          ..add('reason', reason)
          ..add('conflictId', conflictId)
          ..add('conflictingPaths', conflictingPaths)
          ..add('changeSeq', changeSeq))
        .toString();
  }
}

class SyncFieldConflictMutationResultBuilder
    implements
        Builder<
          SyncFieldConflictMutationResult,
          SyncFieldConflictMutationResultBuilder
        > {
  _$SyncFieldConflictMutationResult? _$v;

  String? _mutationId;
  String? get mutationId => _$this._mutationId;
  set mutationId(String? mutationId) => _$this._mutationId = mutationId;

  SyncFieldConflictMutationResultStatusEnum? _status;
  SyncFieldConflictMutationResultStatusEnum? get status => _$this._status;
  set status(SyncFieldConflictMutationResultStatusEnum? status) =>
      _$this._status = status;

  int? _currentRevision;
  int? get currentRevision => _$this._currentRevision;
  set currentRevision(int? currentRevision) =>
      _$this._currentRevision = currentRevision;

  SyncFieldConflictMutationResultReasonEnum? _reason;
  SyncFieldConflictMutationResultReasonEnum? get reason => _$this._reason;
  set reason(SyncFieldConflictMutationResultReasonEnum? reason) =>
      _$this._reason = reason;

  String? _conflictId;
  String? get conflictId => _$this._conflictId;
  set conflictId(String? conflictId) => _$this._conflictId = conflictId;

  ListBuilder<String>? _conflictingPaths;
  ListBuilder<String> get conflictingPaths =>
      _$this._conflictingPaths ??= ListBuilder<String>();
  set conflictingPaths(ListBuilder<String>? conflictingPaths) =>
      _$this._conflictingPaths = conflictingPaths;

  int? _changeSeq;
  int? get changeSeq => _$this._changeSeq;
  set changeSeq(int? changeSeq) => _$this._changeSeq = changeSeq;

  SyncFieldConflictMutationResultBuilder() {
    SyncFieldConflictMutationResult._defaults(this);
  }

  SyncFieldConflictMutationResultBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _mutationId = $v.mutationId;
      _status = $v.status;
      _currentRevision = $v.currentRevision;
      _reason = $v.reason;
      _conflictId = $v.conflictId;
      _conflictingPaths = $v.conflictingPaths.toBuilder();
      _changeSeq = $v.changeSeq;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SyncFieldConflictMutationResult other) {
    _$v = other as _$SyncFieldConflictMutationResult;
  }

  @override
  void update(void Function(SyncFieldConflictMutationResultBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SyncFieldConflictMutationResult build() => _build();

  _$SyncFieldConflictMutationResult _build() {
    _$SyncFieldConflictMutationResult _$result;
    try {
      _$result =
          _$v ??
          _$SyncFieldConflictMutationResult._(
            mutationId: BuiltValueNullFieldError.checkNotNull(
              mutationId,
              r'SyncFieldConflictMutationResult',
              'mutationId',
            ),
            status: BuiltValueNullFieldError.checkNotNull(
              status,
              r'SyncFieldConflictMutationResult',
              'status',
            ),
            currentRevision: BuiltValueNullFieldError.checkNotNull(
              currentRevision,
              r'SyncFieldConflictMutationResult',
              'currentRevision',
            ),
            reason: BuiltValueNullFieldError.checkNotNull(
              reason,
              r'SyncFieldConflictMutationResult',
              'reason',
            ),
            conflictId: BuiltValueNullFieldError.checkNotNull(
              conflictId,
              r'SyncFieldConflictMutationResult',
              'conflictId',
            ),
            conflictingPaths: conflictingPaths.build(),
            changeSeq: changeSeq,
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'conflictingPaths';
        conflictingPaths.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'SyncFieldConflictMutationResult',
          _$failedField,
          e.toString(),
        );
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
