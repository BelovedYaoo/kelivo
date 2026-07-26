// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'opaque_login_finish_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const OpaqueLoginFinishDataResultEnum
_$opaqueLoginFinishDataResultEnum_deviceApprovalRequired =
    const OpaqueLoginFinishDataResultEnum._('deviceApprovalRequired');

OpaqueLoginFinishDataResultEnum _$opaqueLoginFinishDataResultEnumValueOf(
  String name,
) {
  switch (name) {
    case 'deviceApprovalRequired':
      return _$opaqueLoginFinishDataResultEnum_deviceApprovalRequired;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<OpaqueLoginFinishDataResultEnum>
_$opaqueLoginFinishDataResultEnumValues =
    BuiltSet<OpaqueLoginFinishDataResultEnum>(
      const <OpaqueLoginFinishDataResultEnum>[
        _$opaqueLoginFinishDataResultEnum_deviceApprovalRequired,
      ],
    );

Serializer<OpaqueLoginFinishDataResultEnum>
_$opaqueLoginFinishDataResultEnumSerializer =
    _$OpaqueLoginFinishDataResultEnumSerializer();

class _$OpaqueLoginFinishDataResultEnumSerializer
    implements PrimitiveSerializer<OpaqueLoginFinishDataResultEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'deviceApprovalRequired': 'device-approval-required',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'device-approval-required': 'deviceApprovalRequired',
  };

  @override
  final Iterable<Type> types = const <Type>[OpaqueLoginFinishDataResultEnum];
  @override
  final String wireName = 'OpaqueLoginFinishDataResultEnum';

  @override
  Object serialize(
    Serializers serializers,
    OpaqueLoginFinishDataResultEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  OpaqueLoginFinishDataResultEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => OpaqueLoginFinishDataResultEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$OpaqueLoginFinishData extends OpaqueLoginFinishData {
  @override
  final OneOf oneOf;

  factory _$OpaqueLoginFinishData([
    void Function(OpaqueLoginFinishDataBuilder)? updates,
  ]) => (OpaqueLoginFinishDataBuilder()..update(updates))._build();

  _$OpaqueLoginFinishData._({required this.oneOf}) : super._();
  @override
  OpaqueLoginFinishData rebuild(
    void Function(OpaqueLoginFinishDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  OpaqueLoginFinishDataBuilder toBuilder() =>
      OpaqueLoginFinishDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is OpaqueLoginFinishData && oneOf == other.oneOf;
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
      r'OpaqueLoginFinishData',
    )..add('oneOf', oneOf)).toString();
  }
}

class OpaqueLoginFinishDataBuilder
    implements Builder<OpaqueLoginFinishData, OpaqueLoginFinishDataBuilder> {
  _$OpaqueLoginFinishData? _$v;

  OneOf? _oneOf;
  OneOf? get oneOf => _$this._oneOf;
  set oneOf(OneOf? oneOf) => _$this._oneOf = oneOf;

  OpaqueLoginFinishDataBuilder() {
    OpaqueLoginFinishData._defaults(this);
  }

  OpaqueLoginFinishDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _oneOf = $v.oneOf;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(OpaqueLoginFinishData other) {
    _$v = other as _$OpaqueLoginFinishData;
  }

  @override
  void update(void Function(OpaqueLoginFinishDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  OpaqueLoginFinishData build() => _build();

  _$OpaqueLoginFinishData _build() {
    final _$result =
        _$v ??
        _$OpaqueLoginFinishData._(
          oneOf: BuiltValueNullFieldError.checkNotNull(
            oneOf,
            r'OpaqueLoginFinishData',
            'oneOf',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
