// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'opaque_registration_finish_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const OpaqueRegistrationFinishDataResultEnum
_$opaqueRegistrationFinishDataResultEnum_authenticated =
    const OpaqueRegistrationFinishDataResultEnum._('authenticated');

OpaqueRegistrationFinishDataResultEnum
_$opaqueRegistrationFinishDataResultEnumValueOf(String name) {
  switch (name) {
    case 'authenticated':
      return _$opaqueRegistrationFinishDataResultEnum_authenticated;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<OpaqueRegistrationFinishDataResultEnum>
_$opaqueRegistrationFinishDataResultEnumValues =
    BuiltSet<OpaqueRegistrationFinishDataResultEnum>(
      const <OpaqueRegistrationFinishDataResultEnum>[
        _$opaqueRegistrationFinishDataResultEnum_authenticated,
      ],
    );

Serializer<OpaqueRegistrationFinishDataResultEnum>
_$opaqueRegistrationFinishDataResultEnumSerializer =
    _$OpaqueRegistrationFinishDataResultEnumSerializer();

class _$OpaqueRegistrationFinishDataResultEnumSerializer
    implements PrimitiveSerializer<OpaqueRegistrationFinishDataResultEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'authenticated': 'authenticated',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'authenticated': 'authenticated',
  };

  @override
  final Iterable<Type> types = const <Type>[
    OpaqueRegistrationFinishDataResultEnum,
  ];
  @override
  final String wireName = 'OpaqueRegistrationFinishDataResultEnum';

  @override
  Object serialize(
    Serializers serializers,
    OpaqueRegistrationFinishDataResultEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  OpaqueRegistrationFinishDataResultEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => OpaqueRegistrationFinishDataResultEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$OpaqueRegistrationFinishData extends OpaqueRegistrationFinishData {
  @override
  final int protocolVersion;
  @override
  final OpaqueRegistrationFinishDataResultEnum result;
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

  factory _$OpaqueRegistrationFinishData([
    void Function(OpaqueRegistrationFinishDataBuilder)? updates,
  ]) => (OpaqueRegistrationFinishDataBuilder()..update(updates))._build();

  _$OpaqueRegistrationFinishData._({
    required this.protocolVersion,
    required this.result,
    required this.keyEpoch,
    required this.token,
    required this.tokenExpiresAt,
    required this.user,
    required this.device,
  }) : super._();
  @override
  OpaqueRegistrationFinishData rebuild(
    void Function(OpaqueRegistrationFinishDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  OpaqueRegistrationFinishDataBuilder toBuilder() =>
      OpaqueRegistrationFinishDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is OpaqueRegistrationFinishData &&
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
    return (newBuiltValueToStringHelper(r'OpaqueRegistrationFinishData')
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

class OpaqueRegistrationFinishDataBuilder
    implements
        Builder<
          OpaqueRegistrationFinishData,
          OpaqueRegistrationFinishDataBuilder
        > {
  _$OpaqueRegistrationFinishData? _$v;

  int? _protocolVersion;
  int? get protocolVersion => _$this._protocolVersion;
  set protocolVersion(int? protocolVersion) =>
      _$this._protocolVersion = protocolVersion;

  OpaqueRegistrationFinishDataResultEnum? _result;
  OpaqueRegistrationFinishDataResultEnum? get result => _$this._result;
  set result(OpaqueRegistrationFinishDataResultEnum? result) =>
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

  OpaqueRegistrationFinishDataBuilder() {
    OpaqueRegistrationFinishData._defaults(this);
  }

  OpaqueRegistrationFinishDataBuilder get _$this {
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
  void replace(OpaqueRegistrationFinishData other) {
    _$v = other as _$OpaqueRegistrationFinishData;
  }

  @override
  void update(void Function(OpaqueRegistrationFinishDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  OpaqueRegistrationFinishData build() => _build();

  _$OpaqueRegistrationFinishData _build() {
    _$OpaqueRegistrationFinishData _$result;
    try {
      _$result =
          _$v ??
          _$OpaqueRegistrationFinishData._(
            protocolVersion: BuiltValueNullFieldError.checkNotNull(
              protocolVersion,
              r'OpaqueRegistrationFinishData',
              'protocolVersion',
            ),
            result: BuiltValueNullFieldError.checkNotNull(
              result,
              r'OpaqueRegistrationFinishData',
              'result',
            ),
            keyEpoch: BuiltValueNullFieldError.checkNotNull(
              keyEpoch,
              r'OpaqueRegistrationFinishData',
              'keyEpoch',
            ),
            token: BuiltValueNullFieldError.checkNotNull(
              token,
              r'OpaqueRegistrationFinishData',
              'token',
            ),
            tokenExpiresAt: BuiltValueNullFieldError.checkNotNull(
              tokenExpiresAt,
              r'OpaqueRegistrationFinishData',
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
          r'OpaqueRegistrationFinishData',
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
