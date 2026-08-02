// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'self_revocation_status_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const SelfRevocationStatusDataStatusEnum
_$selfRevocationStatusDataStatusEnum_superseded =
    const SelfRevocationStatusDataStatusEnum._('superseded');

SelfRevocationStatusDataStatusEnum _$selfRevocationStatusDataStatusEnumValueOf(
  String name,
) {
  switch (name) {
    case 'superseded':
      return _$selfRevocationStatusDataStatusEnum_superseded;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<SelfRevocationStatusDataStatusEnum>
_$selfRevocationStatusDataStatusEnumValues =
    BuiltSet<SelfRevocationStatusDataStatusEnum>(
      const <SelfRevocationStatusDataStatusEnum>[
        _$selfRevocationStatusDataStatusEnum_superseded,
      ],
    );

Serializer<SelfRevocationStatusDataStatusEnum>
_$selfRevocationStatusDataStatusEnumSerializer =
    _$SelfRevocationStatusDataStatusEnumSerializer();

class _$SelfRevocationStatusDataStatusEnumSerializer
    implements PrimitiveSerializer<SelfRevocationStatusDataStatusEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'superseded': 'superseded',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'superseded': 'superseded',
  };

  @override
  final Iterable<Type> types = const <Type>[SelfRevocationStatusDataStatusEnum];
  @override
  final String wireName = 'SelfRevocationStatusDataStatusEnum';

  @override
  Object serialize(
    Serializers serializers,
    SelfRevocationStatusDataStatusEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  SelfRevocationStatusDataStatusEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => SelfRevocationStatusDataStatusEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$SelfRevocationStatusData extends SelfRevocationStatusData {
  @override
  final OneOf oneOf;

  factory _$SelfRevocationStatusData([
    void Function(SelfRevocationStatusDataBuilder)? updates,
  ]) => (SelfRevocationStatusDataBuilder()..update(updates))._build();

  _$SelfRevocationStatusData._({required this.oneOf}) : super._();
  @override
  SelfRevocationStatusData rebuild(
    void Function(SelfRevocationStatusDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  SelfRevocationStatusDataBuilder toBuilder() =>
      SelfRevocationStatusDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SelfRevocationStatusData && oneOf == other.oneOf;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, oneOf.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(
      r'SelfRevocationStatusData',
    )..add('oneOf', oneOf)).toString();
  }
}

class SelfRevocationStatusDataBuilder
    implements
        Builder<SelfRevocationStatusData, SelfRevocationStatusDataBuilder> {
  _$SelfRevocationStatusData? _$v;

  OneOf? _oneOf;
  OneOf? get oneOf => _$this._oneOf;
  set oneOf(OneOf? oneOf) => _$this._oneOf = oneOf;

  SelfRevocationStatusDataBuilder() {
    SelfRevocationStatusData._defaults(this);
  }

  SelfRevocationStatusDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _oneOf = $v.oneOf;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SelfRevocationStatusData other) {
    _$v = other as _$SelfRevocationStatusData;
  }

  @override
  void update(void Function(SelfRevocationStatusDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SelfRevocationStatusData build() => _build();

  _$SelfRevocationStatusData _build() {
    final _$result =
        _$v ??
        _$SelfRevocationStatusData._(
          oneOf: BuiltValueNullFieldError.checkNotNull(
            oneOf,
            r'SelfRevocationStatusData',
            'oneOf',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
