// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_delete_mutation.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const SyncDeleteMutationOperationEnum _$syncDeleteMutationOperationEnum_delete =
    const SyncDeleteMutationOperationEnum._('delete');

SyncDeleteMutationOperationEnum _$syncDeleteMutationOperationEnumValueOf(
  String name,
) {
  switch (name) {
    case 'delete':
      return _$syncDeleteMutationOperationEnum_delete;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<SyncDeleteMutationOperationEnum>
_$syncDeleteMutationOperationEnumValues =
    BuiltSet<SyncDeleteMutationOperationEnum>(
      const <SyncDeleteMutationOperationEnum>[
        _$syncDeleteMutationOperationEnum_delete,
      ],
    );

Serializer<SyncDeleteMutationOperationEnum>
_$syncDeleteMutationOperationEnumSerializer =
    _$SyncDeleteMutationOperationEnumSerializer();

class _$SyncDeleteMutationOperationEnumSerializer
    implements PrimitiveSerializer<SyncDeleteMutationOperationEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'delete': 'delete',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'delete': 'delete',
  };

  @override
  final Iterable<Type> types = const <Type>[SyncDeleteMutationOperationEnum];
  @override
  final String wireName = 'SyncDeleteMutationOperationEnum';

  @override
  Object serialize(
    Serializers serializers,
    SyncDeleteMutationOperationEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  SyncDeleteMutationOperationEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => SyncDeleteMutationOperationEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$SyncDeleteMutation extends SyncDeleteMutation {
  @override
  final String mutationId;
  @override
  final String recordId;
  @override
  final int expectedRevision;
  @override
  final SyncDeleteMutationOperationEnum operation;

  factory _$SyncDeleteMutation([
    void Function(SyncDeleteMutationBuilder)? updates,
  ]) => (SyncDeleteMutationBuilder()..update(updates))._build();

  _$SyncDeleteMutation._({
    required this.mutationId,
    required this.recordId,
    required this.expectedRevision,
    required this.operation,
  }) : super._();
  @override
  SyncDeleteMutation rebuild(
    void Function(SyncDeleteMutationBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  SyncDeleteMutationBuilder toBuilder() =>
      SyncDeleteMutationBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SyncDeleteMutation &&
        mutationId == other.mutationId &&
        recordId == other.recordId &&
        expectedRevision == other.expectedRevision &&
        operation == other.operation;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, mutationId.hashCode);
    _$hash = $jc(_$hash, recordId.hashCode);
    _$hash = $jc(_$hash, expectedRevision.hashCode);
    _$hash = $jc(_$hash, operation.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'SyncDeleteMutation')
          ..add('mutationId', mutationId)
          ..add('recordId', recordId)
          ..add('expectedRevision', expectedRevision)
          ..add('operation', operation))
        .toString();
  }
}

class SyncDeleteMutationBuilder
    implements Builder<SyncDeleteMutation, SyncDeleteMutationBuilder> {
  _$SyncDeleteMutation? _$v;

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

  SyncDeleteMutationOperationEnum? _operation;
  SyncDeleteMutationOperationEnum? get operation => _$this._operation;
  set operation(SyncDeleteMutationOperationEnum? operation) =>
      _$this._operation = operation;

  SyncDeleteMutationBuilder() {
    SyncDeleteMutation._defaults(this);
  }

  SyncDeleteMutationBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _mutationId = $v.mutationId;
      _recordId = $v.recordId;
      _expectedRevision = $v.expectedRevision;
      _operation = $v.operation;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SyncDeleteMutation other) {
    _$v = other as _$SyncDeleteMutation;
  }

  @override
  void update(void Function(SyncDeleteMutationBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SyncDeleteMutation build() => _build();

  _$SyncDeleteMutation _build() {
    final _$result =
        _$v ??
        _$SyncDeleteMutation._(
          mutationId: BuiltValueNullFieldError.checkNotNull(
            mutationId,
            r'SyncDeleteMutation',
            'mutationId',
          ),
          recordId: BuiltValueNullFieldError.checkNotNull(
            recordId,
            r'SyncDeleteMutation',
            'recordId',
          ),
          expectedRevision: BuiltValueNullFieldError.checkNotNull(
            expectedRevision,
            r'SyncDeleteMutation',
            'expectedRevision',
          ),
          operation: BuiltValueNullFieldError.checkNotNull(
            operation,
            r'SyncDeleteMutation',
            'operation',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
