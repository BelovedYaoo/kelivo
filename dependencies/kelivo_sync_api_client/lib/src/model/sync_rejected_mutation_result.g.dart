// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_rejected_mutation_result.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const SyncRejectedMutationResultStatusEnum
_$syncRejectedMutationResultStatusEnum_rejected =
    const SyncRejectedMutationResultStatusEnum._('rejected');

SyncRejectedMutationResultStatusEnum
_$syncRejectedMutationResultStatusEnumValueOf(String name) {
  switch (name) {
    case 'rejected':
      return _$syncRejectedMutationResultStatusEnum_rejected;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<SyncRejectedMutationResultStatusEnum>
_$syncRejectedMutationResultStatusEnumValues =
    BuiltSet<SyncRejectedMutationResultStatusEnum>(
      const <SyncRejectedMutationResultStatusEnum>[
        _$syncRejectedMutationResultStatusEnum_rejected,
      ],
    );

Serializer<SyncRejectedMutationResultStatusEnum>
_$syncRejectedMutationResultStatusEnumSerializer =
    _$SyncRejectedMutationResultStatusEnumSerializer();

class _$SyncRejectedMutationResultStatusEnumSerializer
    implements PrimitiveSerializer<SyncRejectedMutationResultStatusEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'rejected': 'rejected',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'rejected': 'rejected',
  };

  @override
  final Iterable<Type> types = const <Type>[
    SyncRejectedMutationResultStatusEnum,
  ];
  @override
  final String wireName = 'SyncRejectedMutationResultStatusEnum';

  @override
  Object serialize(
    Serializers serializers,
    SyncRejectedMutationResultStatusEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  SyncRejectedMutationResultStatusEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => SyncRejectedMutationResultStatusEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$SyncRejectedMutationResult extends SyncRejectedMutationResult {
  @override
  final String mutationId;
  @override
  final SyncRejectedMutationResultStatusEnum status;
  @override
  final String errorCode;
  @override
  final BuiltMap<String, JsonObject?>? params;

  factory _$SyncRejectedMutationResult([
    void Function(SyncRejectedMutationResultBuilder)? updates,
  ]) => (SyncRejectedMutationResultBuilder()..update(updates))._build();

  _$SyncRejectedMutationResult._({
    required this.mutationId,
    required this.status,
    required this.errorCode,
    this.params,
  }) : super._();
  @override
  SyncRejectedMutationResult rebuild(
    void Function(SyncRejectedMutationResultBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  SyncRejectedMutationResultBuilder toBuilder() =>
      SyncRejectedMutationResultBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SyncRejectedMutationResult &&
        mutationId == other.mutationId &&
        status == other.status &&
        errorCode == other.errorCode &&
        params == other.params;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, mutationId.hashCode);
    _$hash = $jc(_$hash, status.hashCode);
    _$hash = $jc(_$hash, errorCode.hashCode);
    _$hash = $jc(_$hash, params.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'SyncRejectedMutationResult')
          ..add('mutationId', mutationId)
          ..add('status', status)
          ..add('errorCode', errorCode)
          ..add('params', params))
        .toString();
  }
}

class SyncRejectedMutationResultBuilder
    implements
        Builder<SyncRejectedMutationResult, SyncRejectedMutationResultBuilder> {
  _$SyncRejectedMutationResult? _$v;

  String? _mutationId;
  String? get mutationId => _$this._mutationId;
  set mutationId(String? mutationId) => _$this._mutationId = mutationId;

  SyncRejectedMutationResultStatusEnum? _status;
  SyncRejectedMutationResultStatusEnum? get status => _$this._status;
  set status(SyncRejectedMutationResultStatusEnum? status) =>
      _$this._status = status;

  String? _errorCode;
  String? get errorCode => _$this._errorCode;
  set errorCode(String? errorCode) => _$this._errorCode = errorCode;

  MapBuilder<String, JsonObject?>? _params;
  MapBuilder<String, JsonObject?> get params =>
      _$this._params ??= MapBuilder<String, JsonObject?>();
  set params(MapBuilder<String, JsonObject?>? params) =>
      _$this._params = params;

  SyncRejectedMutationResultBuilder() {
    SyncRejectedMutationResult._defaults(this);
  }

  SyncRejectedMutationResultBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _mutationId = $v.mutationId;
      _status = $v.status;
      _errorCode = $v.errorCode;
      _params = $v.params?.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SyncRejectedMutationResult other) {
    _$v = other as _$SyncRejectedMutationResult;
  }

  @override
  void update(void Function(SyncRejectedMutationResultBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SyncRejectedMutationResult build() => _build();

  _$SyncRejectedMutationResult _build() {
    _$SyncRejectedMutationResult _$result;
    try {
      _$result =
          _$v ??
          _$SyncRejectedMutationResult._(
            mutationId: BuiltValueNullFieldError.checkNotNull(
              mutationId,
              r'SyncRejectedMutationResult',
              'mutationId',
            ),
            status: BuiltValueNullFieldError.checkNotNull(
              status,
              r'SyncRejectedMutationResult',
              'status',
            ),
            errorCode: BuiltValueNullFieldError.checkNotNull(
              errorCode,
              r'SyncRejectedMutationResult',
              'errorCode',
            ),
            params: _params?.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'params';
        _params?.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'SyncRejectedMutationResult',
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
