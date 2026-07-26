// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'opaque_login_finish_data_one_of.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const OpaqueLoginFinishDataOneOfResultEnum
_$opaqueLoginFinishDataOneOfResultEnum_authenticated =
    const OpaqueLoginFinishDataOneOfResultEnum._('authenticated');

OpaqueLoginFinishDataOneOfResultEnum
_$opaqueLoginFinishDataOneOfResultEnumValueOf(String name) {
  switch (name) {
    case 'authenticated':
      return _$opaqueLoginFinishDataOneOfResultEnum_authenticated;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<OpaqueLoginFinishDataOneOfResultEnum>
_$opaqueLoginFinishDataOneOfResultEnumValues =
    BuiltSet<OpaqueLoginFinishDataOneOfResultEnum>(
      const <OpaqueLoginFinishDataOneOfResultEnum>[
        _$opaqueLoginFinishDataOneOfResultEnum_authenticated,
      ],
    );

Serializer<OpaqueLoginFinishDataOneOfResultEnum>
_$opaqueLoginFinishDataOneOfResultEnumSerializer =
    _$OpaqueLoginFinishDataOneOfResultEnumSerializer();

class _$OpaqueLoginFinishDataOneOfResultEnumSerializer
    implements PrimitiveSerializer<OpaqueLoginFinishDataOneOfResultEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'authenticated': 'authenticated',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'authenticated': 'authenticated',
  };

  @override
  final Iterable<Type> types = const <Type>[
    OpaqueLoginFinishDataOneOfResultEnum,
  ];
  @override
  final String wireName = 'OpaqueLoginFinishDataOneOfResultEnum';

  @override
  Object serialize(
    Serializers serializers,
    OpaqueLoginFinishDataOneOfResultEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  OpaqueLoginFinishDataOneOfResultEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => OpaqueLoginFinishDataOneOfResultEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$OpaqueLoginFinishDataOneOf extends OpaqueLoginFinishDataOneOf {
  @override
  final int protocolVersion;
  @override
  final OpaqueLoginFinishDataOneOfResultEnum result;
  @override
  final int keyEpoch;
  @override
  final String token;
  @override
  final DateTime tokenExpiresAt;
  @override
  final OpaqueRegistrationFinishDataUser user;
  @override
  final OpaqueRegistrationFinishDataDevice device;

  factory _$OpaqueLoginFinishDataOneOf([
    void Function(OpaqueLoginFinishDataOneOfBuilder)? updates,
  ]) => (OpaqueLoginFinishDataOneOfBuilder()..update(updates))._build();

  _$OpaqueLoginFinishDataOneOf._({
    required this.protocolVersion,
    required this.result,
    required this.keyEpoch,
    required this.token,
    required this.tokenExpiresAt,
    required this.user,
    required this.device,
  }) : super._();
  @override
  OpaqueLoginFinishDataOneOf rebuild(
    void Function(OpaqueLoginFinishDataOneOfBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  OpaqueLoginFinishDataOneOfBuilder toBuilder() =>
      OpaqueLoginFinishDataOneOfBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is OpaqueLoginFinishDataOneOf &&
        protocolVersion == other.protocolVersion &&
        result == other.result &&
        keyEpoch == other.keyEpoch &&
        token == other.token &&
        tokenExpiresAt == other.tokenExpiresAt &&
        user == other.user &&
        device == other.device;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, protocolVersion.hashCode);
    _$hash = $jc(_$hash, result.hashCode);
    _$hash = $jc(_$hash, keyEpoch.hashCode);
    _$hash = $jc(_$hash, token.hashCode);
    _$hash = $jc(_$hash, tokenExpiresAt.hashCode);
    _$hash = $jc(_$hash, user.hashCode);
    _$hash = $jc(_$hash, device.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'OpaqueLoginFinishDataOneOf')
          ..add('protocolVersion', protocolVersion)
          ..add('result', result)
          ..add('keyEpoch', keyEpoch)
          ..add('token', token)
          ..add('tokenExpiresAt', tokenExpiresAt)
          ..add('user', user)
          ..add('device', device))
        .toString();
  }
}

class OpaqueLoginFinishDataOneOfBuilder
    implements
        Builder<OpaqueLoginFinishDataOneOf, OpaqueLoginFinishDataOneOfBuilder> {
  _$OpaqueLoginFinishDataOneOf? _$v;

  int? _protocolVersion;
  int? get protocolVersion => _$this._protocolVersion;
  set protocolVersion(int? protocolVersion) =>
      _$this._protocolVersion = protocolVersion;

  OpaqueLoginFinishDataOneOfResultEnum? _result;
  OpaqueLoginFinishDataOneOfResultEnum? get result => _$this._result;
  set result(OpaqueLoginFinishDataOneOfResultEnum? result) =>
      _$this._result = result;

  int? _keyEpoch;
  int? get keyEpoch => _$this._keyEpoch;
  set keyEpoch(int? keyEpoch) => _$this._keyEpoch = keyEpoch;

  String? _token;
  String? get token => _$this._token;
  set token(String? token) => _$this._token = token;

  DateTime? _tokenExpiresAt;
  DateTime? get tokenExpiresAt => _$this._tokenExpiresAt;
  set tokenExpiresAt(DateTime? tokenExpiresAt) =>
      _$this._tokenExpiresAt = tokenExpiresAt;

  OpaqueRegistrationFinishDataUserBuilder? _user;
  OpaqueRegistrationFinishDataUserBuilder get user =>
      _$this._user ??= OpaqueRegistrationFinishDataUserBuilder();
  set user(OpaqueRegistrationFinishDataUserBuilder? user) =>
      _$this._user = user;

  OpaqueRegistrationFinishDataDeviceBuilder? _device;
  OpaqueRegistrationFinishDataDeviceBuilder get device =>
      _$this._device ??= OpaqueRegistrationFinishDataDeviceBuilder();
  set device(OpaqueRegistrationFinishDataDeviceBuilder? device) =>
      _$this._device = device;

  OpaqueLoginFinishDataOneOfBuilder() {
    OpaqueLoginFinishDataOneOf._defaults(this);
  }

  OpaqueLoginFinishDataOneOfBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _protocolVersion = $v.protocolVersion;
      _result = $v.result;
      _keyEpoch = $v.keyEpoch;
      _token = $v.token;
      _tokenExpiresAt = $v.tokenExpiresAt;
      _user = $v.user.toBuilder();
      _device = $v.device.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(OpaqueLoginFinishDataOneOf other) {
    _$v = other as _$OpaqueLoginFinishDataOneOf;
  }

  @override
  void update(void Function(OpaqueLoginFinishDataOneOfBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  OpaqueLoginFinishDataOneOf build() => _build();

  _$OpaqueLoginFinishDataOneOf _build() {
    _$OpaqueLoginFinishDataOneOf _$result;
    try {
      _$result =
          _$v ??
          _$OpaqueLoginFinishDataOneOf._(
            protocolVersion: BuiltValueNullFieldError.checkNotNull(
              protocolVersion,
              r'OpaqueLoginFinishDataOneOf',
              'protocolVersion',
            ),
            result: BuiltValueNullFieldError.checkNotNull(
              result,
              r'OpaqueLoginFinishDataOneOf',
              'result',
            ),
            keyEpoch: BuiltValueNullFieldError.checkNotNull(
              keyEpoch,
              r'OpaqueLoginFinishDataOneOf',
              'keyEpoch',
            ),
            token: BuiltValueNullFieldError.checkNotNull(
              token,
              r'OpaqueLoginFinishDataOneOf',
              'token',
            ),
            tokenExpiresAt: BuiltValueNullFieldError.checkNotNull(
              tokenExpiresAt,
              r'OpaqueLoginFinishDataOneOf',
              'tokenExpiresAt',
            ),
            user: user.build(),
            device: device.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'user';
        user.build();
        _$failedField = 'device';
        device.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'OpaqueLoginFinishDataOneOf',
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
