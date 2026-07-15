// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_upsert_change.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const SyncUpsertChangeOperationEnum _$syncUpsertChangeOperationEnum_upsert =
    const SyncUpsertChangeOperationEnum._('upsert');

SyncUpsertChangeOperationEnum _$syncUpsertChangeOperationEnumValueOf(
  String name,
) {
  switch (name) {
    case 'upsert':
      return _$syncUpsertChangeOperationEnum_upsert;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<SyncUpsertChangeOperationEnum>
_$syncUpsertChangeOperationEnumValues = BuiltSet<SyncUpsertChangeOperationEnum>(
  const <SyncUpsertChangeOperationEnum>[_$syncUpsertChangeOperationEnum_upsert],
);

Serializer<SyncUpsertChangeOperationEnum>
_$syncUpsertChangeOperationEnumSerializer =
    _$SyncUpsertChangeOperationEnumSerializer();

class _$SyncUpsertChangeOperationEnumSerializer
    implements PrimitiveSerializer<SyncUpsertChangeOperationEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'upsert': 'upsert',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'upsert': 'upsert',
  };

  @override
  final Iterable<Type> types = const <Type>[SyncUpsertChangeOperationEnum];
  @override
  final String wireName = 'SyncUpsertChangeOperationEnum';

  @override
  Object serialize(
    Serializers serializers,
    SyncUpsertChangeOperationEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  SyncUpsertChangeOperationEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => SyncUpsertChangeOperationEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$SyncUpsertChange extends SyncUpsertChange {
  @override
  final int changeSeq;
  @override
  final SyncUpsertChangeOperationEnum operation;
  @override
  final SyncRecord record;

  factory _$SyncUpsertChange([
    void Function(SyncUpsertChangeBuilder)? updates,
  ]) => (SyncUpsertChangeBuilder()..update(updates))._build();

  _$SyncUpsertChange._({
    required this.changeSeq,
    required this.operation,
    required this.record,
  }) : super._();
  @override
  SyncUpsertChange rebuild(void Function(SyncUpsertChangeBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  SyncUpsertChangeBuilder toBuilder() =>
      SyncUpsertChangeBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SyncUpsertChange &&
        changeSeq == other.changeSeq &&
        operation == other.operation &&
        record == other.record;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, changeSeq.hashCode);
    _$hash = $jc(_$hash, operation.hashCode);
    _$hash = $jc(_$hash, record.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'SyncUpsertChange')
          ..add('changeSeq', changeSeq)
          ..add('operation', operation)
          ..add('record', record))
        .toString();
  }
}

class SyncUpsertChangeBuilder
    implements Builder<SyncUpsertChange, SyncUpsertChangeBuilder> {
  _$SyncUpsertChange? _$v;

  int? _changeSeq;
  int? get changeSeq => _$this._changeSeq;
  set changeSeq(int? changeSeq) => _$this._changeSeq = changeSeq;

  SyncUpsertChangeOperationEnum? _operation;
  SyncUpsertChangeOperationEnum? get operation => _$this._operation;
  set operation(SyncUpsertChangeOperationEnum? operation) =>
      _$this._operation = operation;

  SyncRecordBuilder? _record;
  SyncRecordBuilder get record => _$this._record ??= SyncRecordBuilder();
  set record(SyncRecordBuilder? record) => _$this._record = record;

  SyncUpsertChangeBuilder() {
    SyncUpsertChange._defaults(this);
  }

  SyncUpsertChangeBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _changeSeq = $v.changeSeq;
      _operation = $v.operation;
      _record = $v.record.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SyncUpsertChange other) {
    _$v = other as _$SyncUpsertChange;
  }

  @override
  void update(void Function(SyncUpsertChangeBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SyncUpsertChange build() => _build();

  _$SyncUpsertChange _build() {
    _$SyncUpsertChange _$result;
    try {
      _$result =
          _$v ??
          _$SyncUpsertChange._(
            changeSeq: BuiltValueNullFieldError.checkNotNull(
              changeSeq,
              r'SyncUpsertChange',
              'changeSeq',
            ),
            operation: BuiltValueNullFieldError.checkNotNull(
              operation,
              r'SyncUpsertChange',
              'operation',
            ),
            record: record.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'record';
        record.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'SyncUpsertChange',
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
