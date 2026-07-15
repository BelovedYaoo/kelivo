// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_retry_mutation_result.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const SyncRetryMutationResultStatusEnum
_$syncRetryMutationResultStatusEnum_retry =
    const SyncRetryMutationResultStatusEnum._('retry');

SyncRetryMutationResultStatusEnum _$syncRetryMutationResultStatusEnumValueOf(
  String name,
) {
  switch (name) {
    case 'retry':
      return _$syncRetryMutationResultStatusEnum_retry;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<SyncRetryMutationResultStatusEnum>
_$syncRetryMutationResultStatusEnumValues =
    BuiltSet<SyncRetryMutationResultStatusEnum>(
      const <SyncRetryMutationResultStatusEnum>[
        _$syncRetryMutationResultStatusEnum_retry,
      ],
    );

Serializer<SyncRetryMutationResultStatusEnum>
_$syncRetryMutationResultStatusEnumSerializer =
    _$SyncRetryMutationResultStatusEnumSerializer();

class _$SyncRetryMutationResultStatusEnumSerializer
    implements PrimitiveSerializer<SyncRetryMutationResultStatusEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'retry': 'retry',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'retry': 'retry',
  };

  @override
  final Iterable<Type> types = const <Type>[SyncRetryMutationResultStatusEnum];
  @override
  final String wireName = 'SyncRetryMutationResultStatusEnum';

  @override
  Object serialize(
    Serializers serializers,
    SyncRetryMutationResultStatusEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  SyncRetryMutationResultStatusEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => SyncRetryMutationResultStatusEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$SyncRetryMutationResult extends SyncRetryMutationResult {
  @override
  final String mutationId;
  @override
  final SyncRetryMutationResultStatusEnum status;
  @override
  final bool retryable;

  factory _$SyncRetryMutationResult([
    void Function(SyncRetryMutationResultBuilder)? updates,
  ]) => (SyncRetryMutationResultBuilder()..update(updates))._build();

  _$SyncRetryMutationResult._({
    required this.mutationId,
    required this.status,
    required this.retryable,
  }) : super._();
  @override
  SyncRetryMutationResult rebuild(
    void Function(SyncRetryMutationResultBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  SyncRetryMutationResultBuilder toBuilder() =>
      SyncRetryMutationResultBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SyncRetryMutationResult &&
        mutationId == other.mutationId &&
        status == other.status &&
        retryable == other.retryable;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, mutationId.hashCode);
    _$hash = $jc(_$hash, status.hashCode);
    _$hash = $jc(_$hash, retryable.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'SyncRetryMutationResult')
          ..add('mutationId', mutationId)
          ..add('status', status)
          ..add('retryable', retryable))
        .toString();
  }
}

class SyncRetryMutationResultBuilder
    implements
        Builder<SyncRetryMutationResult, SyncRetryMutationResultBuilder> {
  _$SyncRetryMutationResult? _$v;

  String? _mutationId;
  String? get mutationId => _$this._mutationId;
  set mutationId(String? mutationId) => _$this._mutationId = mutationId;

  SyncRetryMutationResultStatusEnum? _status;
  SyncRetryMutationResultStatusEnum? get status => _$this._status;
  set status(SyncRetryMutationResultStatusEnum? status) =>
      _$this._status = status;

  bool? _retryable;
  bool? get retryable => _$this._retryable;
  set retryable(bool? retryable) => _$this._retryable = retryable;

  SyncRetryMutationResultBuilder() {
    SyncRetryMutationResult._defaults(this);
  }

  SyncRetryMutationResultBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _mutationId = $v.mutationId;
      _status = $v.status;
      _retryable = $v.retryable;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SyncRetryMutationResult other) {
    _$v = other as _$SyncRetryMutationResult;
  }

  @override
  void update(void Function(SyncRetryMutationResultBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SyncRetryMutationResult build() => _build();

  _$SyncRetryMutationResult _build() {
    final _$result =
        _$v ??
        _$SyncRetryMutationResult._(
          mutationId: BuiltValueNullFieldError.checkNotNull(
            mutationId,
            r'SyncRetryMutationResult',
            'mutationId',
          ),
          status: BuiltValueNullFieldError.checkNotNull(
            status,
            r'SyncRetryMutationResult',
            'status',
          ),
          retryable: BuiltValueNullFieldError.checkNotNull(
            retryable,
            r'SyncRetryMutationResult',
            'retryable',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
