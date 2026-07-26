// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'opaque_login_finish_data_one_of1.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const OpaqueLoginFinishDataOneOf1ResultEnum
_$opaqueLoginFinishDataOneOf1ResultEnum_deviceApprovalRequired =
    const OpaqueLoginFinishDataOneOf1ResultEnum._('deviceApprovalRequired');

OpaqueLoginFinishDataOneOf1ResultEnum
_$opaqueLoginFinishDataOneOf1ResultEnumValueOf(String name) {
  switch (name) {
    case 'deviceApprovalRequired':
      return _$opaqueLoginFinishDataOneOf1ResultEnum_deviceApprovalRequired;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<OpaqueLoginFinishDataOneOf1ResultEnum>
_$opaqueLoginFinishDataOneOf1ResultEnumValues =
    BuiltSet<OpaqueLoginFinishDataOneOf1ResultEnum>(
      const <OpaqueLoginFinishDataOneOf1ResultEnum>[
        _$opaqueLoginFinishDataOneOf1ResultEnum_deviceApprovalRequired,
      ],
    );

Serializer<OpaqueLoginFinishDataOneOf1ResultEnum>
_$opaqueLoginFinishDataOneOf1ResultEnumSerializer =
    _$OpaqueLoginFinishDataOneOf1ResultEnumSerializer();

class _$OpaqueLoginFinishDataOneOf1ResultEnumSerializer
    implements PrimitiveSerializer<OpaqueLoginFinishDataOneOf1ResultEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'deviceApprovalRequired': 'device-approval-required',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'device-approval-required': 'deviceApprovalRequired',
  };

  @override
  final Iterable<Type> types = const <Type>[
    OpaqueLoginFinishDataOneOf1ResultEnum,
  ];
  @override
  final String wireName = 'OpaqueLoginFinishDataOneOf1ResultEnum';

  @override
  Object serialize(
    Serializers serializers,
    OpaqueLoginFinishDataOneOf1ResultEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  OpaqueLoginFinishDataOneOf1ResultEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => OpaqueLoginFinishDataOneOf1ResultEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$OpaqueLoginFinishDataOneOf1 extends OpaqueLoginFinishDataOneOf1 {
  @override
  final int protocolVersion;
  @override
  final OpaqueLoginFinishDataOneOf1ResultEnum result;
  @override
  final String onboardingToken;
  @override
  final DateTime onboardingTokenExpiresAt;
  @override
  final OpaqueLoginFinishDataOneOf1Device device;

  factory _$OpaqueLoginFinishDataOneOf1([
    void Function(OpaqueLoginFinishDataOneOf1Builder)? updates,
  ]) => (OpaqueLoginFinishDataOneOf1Builder()..update(updates))._build();

  _$OpaqueLoginFinishDataOneOf1._({
    required this.protocolVersion,
    required this.result,
    required this.onboardingToken,
    required this.onboardingTokenExpiresAt,
    required this.device,
  }) : super._();
  @override
  OpaqueLoginFinishDataOneOf1 rebuild(
    void Function(OpaqueLoginFinishDataOneOf1Builder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  OpaqueLoginFinishDataOneOf1Builder toBuilder() =>
      OpaqueLoginFinishDataOneOf1Builder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is OpaqueLoginFinishDataOneOf1 &&
        protocolVersion == other.protocolVersion &&
        result == other.result &&
        onboardingToken == other.onboardingToken &&
        onboardingTokenExpiresAt == other.onboardingTokenExpiresAt &&
        device == other.device;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, protocolVersion.hashCode);
    _$hash = $jc(_$hash, result.hashCode);
    _$hash = $jc(_$hash, onboardingToken.hashCode);
    _$hash = $jc(_$hash, onboardingTokenExpiresAt.hashCode);
    _$hash = $jc(_$hash, device.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'OpaqueLoginFinishDataOneOf1')
          ..add('protocolVersion', protocolVersion)
          ..add('result', result)
          ..add('onboardingToken', onboardingToken)
          ..add('onboardingTokenExpiresAt', onboardingTokenExpiresAt)
          ..add('device', device))
        .toString();
  }
}

class OpaqueLoginFinishDataOneOf1Builder
    implements
        Builder<
          OpaqueLoginFinishDataOneOf1,
          OpaqueLoginFinishDataOneOf1Builder
        > {
  _$OpaqueLoginFinishDataOneOf1? _$v;

  int? _protocolVersion;
  int? get protocolVersion => _$this._protocolVersion;
  set protocolVersion(int? protocolVersion) =>
      _$this._protocolVersion = protocolVersion;

  OpaqueLoginFinishDataOneOf1ResultEnum? _result;
  OpaqueLoginFinishDataOneOf1ResultEnum? get result => _$this._result;
  set result(OpaqueLoginFinishDataOneOf1ResultEnum? result) =>
      _$this._result = result;

  String? _onboardingToken;
  String? get onboardingToken => _$this._onboardingToken;
  set onboardingToken(String? onboardingToken) =>
      _$this._onboardingToken = onboardingToken;

  DateTime? _onboardingTokenExpiresAt;
  DateTime? get onboardingTokenExpiresAt => _$this._onboardingTokenExpiresAt;
  set onboardingTokenExpiresAt(DateTime? onboardingTokenExpiresAt) =>
      _$this._onboardingTokenExpiresAt = onboardingTokenExpiresAt;

  OpaqueLoginFinishDataOneOf1DeviceBuilder? _device;
  OpaqueLoginFinishDataOneOf1DeviceBuilder get device =>
      _$this._device ??= OpaqueLoginFinishDataOneOf1DeviceBuilder();
  set device(OpaqueLoginFinishDataOneOf1DeviceBuilder? device) =>
      _$this._device = device;

  OpaqueLoginFinishDataOneOf1Builder() {
    OpaqueLoginFinishDataOneOf1._defaults(this);
  }

  OpaqueLoginFinishDataOneOf1Builder get _$this {
    final $v = _$v;
    if ($v != null) {
      _protocolVersion = $v.protocolVersion;
      _result = $v.result;
      _onboardingToken = $v.onboardingToken;
      _onboardingTokenExpiresAt = $v.onboardingTokenExpiresAt;
      _device = $v.device.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(OpaqueLoginFinishDataOneOf1 other) {
    _$v = other as _$OpaqueLoginFinishDataOneOf1;
  }

  @override
  void update(void Function(OpaqueLoginFinishDataOneOf1Builder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  OpaqueLoginFinishDataOneOf1 build() => _build();

  _$OpaqueLoginFinishDataOneOf1 _build() {
    _$OpaqueLoginFinishDataOneOf1 _$result;
    try {
      _$result =
          _$v ??
          _$OpaqueLoginFinishDataOneOf1._(
            protocolVersion: BuiltValueNullFieldError.checkNotNull(
              protocolVersion,
              r'OpaqueLoginFinishDataOneOf1',
              'protocolVersion',
            ),
            result: BuiltValueNullFieldError.checkNotNull(
              result,
              r'OpaqueLoginFinishDataOneOf1',
              'result',
            ),
            onboardingToken: BuiltValueNullFieldError.checkNotNull(
              onboardingToken,
              r'OpaqueLoginFinishDataOneOf1',
              'onboardingToken',
            ),
            onboardingTokenExpiresAt: BuiltValueNullFieldError.checkNotNull(
              onboardingTokenExpiresAt,
              r'OpaqueLoginFinishDataOneOf1',
              'onboardingTokenExpiresAt',
            ),
            device: device.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'device';
        device.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'OpaqueLoginFinishDataOneOf1',
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
