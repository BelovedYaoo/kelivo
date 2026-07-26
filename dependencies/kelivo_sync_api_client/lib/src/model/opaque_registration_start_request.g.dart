// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'opaque_registration_start_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const OpaqueRegistrationStartRequestPlatformEnum
_$opaqueRegistrationStartRequestPlatformEnum_android =
    const OpaqueRegistrationStartRequestPlatformEnum._('android');
const OpaqueRegistrationStartRequestPlatformEnum
_$opaqueRegistrationStartRequestPlatformEnum_ios =
    const OpaqueRegistrationStartRequestPlatformEnum._('ios');
const OpaqueRegistrationStartRequestPlatformEnum
_$opaqueRegistrationStartRequestPlatformEnum_macos =
    const OpaqueRegistrationStartRequestPlatformEnum._('macos');
const OpaqueRegistrationStartRequestPlatformEnum
_$opaqueRegistrationStartRequestPlatformEnum_windows =
    const OpaqueRegistrationStartRequestPlatformEnum._('windows');
const OpaqueRegistrationStartRequestPlatformEnum
_$opaqueRegistrationStartRequestPlatformEnum_linux =
    const OpaqueRegistrationStartRequestPlatformEnum._('linux');

OpaqueRegistrationStartRequestPlatformEnum
_$opaqueRegistrationStartRequestPlatformEnumValueOf(String name) {
  switch (name) {
    case 'android':
      return _$opaqueRegistrationStartRequestPlatformEnum_android;
    case 'ios':
      return _$opaqueRegistrationStartRequestPlatformEnum_ios;
    case 'macos':
      return _$opaqueRegistrationStartRequestPlatformEnum_macos;
    case 'windows':
      return _$opaqueRegistrationStartRequestPlatformEnum_windows;
    case 'linux':
      return _$opaqueRegistrationStartRequestPlatformEnum_linux;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<OpaqueRegistrationStartRequestPlatformEnum>
_$opaqueRegistrationStartRequestPlatformEnumValues =
    BuiltSet<OpaqueRegistrationStartRequestPlatformEnum>(
      const <OpaqueRegistrationStartRequestPlatformEnum>[
        _$opaqueRegistrationStartRequestPlatformEnum_android,
        _$opaqueRegistrationStartRequestPlatformEnum_ios,
        _$opaqueRegistrationStartRequestPlatformEnum_macos,
        _$opaqueRegistrationStartRequestPlatformEnum_windows,
        _$opaqueRegistrationStartRequestPlatformEnum_linux,
      ],
    );

Serializer<OpaqueRegistrationStartRequestPlatformEnum>
_$opaqueRegistrationStartRequestPlatformEnumSerializer =
    _$OpaqueRegistrationStartRequestPlatformEnumSerializer();

class _$OpaqueRegistrationStartRequestPlatformEnumSerializer
    implements PrimitiveSerializer<OpaqueRegistrationStartRequestPlatformEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'android': 'android',
    'ios': 'ios',
    'macos': 'macos',
    'windows': 'windows',
    'linux': 'linux',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'android': 'android',
    'ios': 'ios',
    'macos': 'macos',
    'windows': 'windows',
    'linux': 'linux',
  };

  @override
  final Iterable<Type> types = const <Type>[
    OpaqueRegistrationStartRequestPlatformEnum,
  ];
  @override
  final String wireName = 'OpaqueRegistrationStartRequestPlatformEnum';

  @override
  Object serialize(
    Serializers serializers,
    OpaqueRegistrationStartRequestPlatformEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  OpaqueRegistrationStartRequestPlatformEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => OpaqueRegistrationStartRequestPlatformEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$OpaqueRegistrationStartRequest extends OpaqueRegistrationStartRequest {
  @override
  final int protocolVersion;
  @override
  final String loginName;
  @override
  final String displayName;
  @override
  final String deviceId;
  @override
  final String deviceName;
  @override
  final OpaqueRegistrationStartRequestPlatformEnum platform;
  @override
  final String clientVersion;
  @override
  final int deviceKeyVersion;
  @override
  final String signingPublicKey;
  @override
  final String keyAgreementPublicKey;
  @override
  final String registrationRequest;

  factory _$OpaqueRegistrationStartRequest([
    void Function(OpaqueRegistrationStartRequestBuilder)? updates,
  ]) => (OpaqueRegistrationStartRequestBuilder()..update(updates))._build();

  _$OpaqueRegistrationStartRequest._({
    required this.protocolVersion,
    required this.loginName,
    required this.displayName,
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.clientVersion,
    required this.deviceKeyVersion,
    required this.signingPublicKey,
    required this.keyAgreementPublicKey,
    required this.registrationRequest,
  }) : super._();
  @override
  OpaqueRegistrationStartRequest rebuild(
    void Function(OpaqueRegistrationStartRequestBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  OpaqueRegistrationStartRequestBuilder toBuilder() =>
      OpaqueRegistrationStartRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is OpaqueRegistrationStartRequest &&
        protocolVersion == other.protocolVersion &&
        loginName == other.loginName &&
        displayName == other.displayName &&
        deviceId == other.deviceId &&
        deviceName == other.deviceName &&
        platform == other.platform &&
        clientVersion == other.clientVersion &&
        deviceKeyVersion == other.deviceKeyVersion &&
        signingPublicKey == other.signingPublicKey &&
        keyAgreementPublicKey == other.keyAgreementPublicKey &&
        registrationRequest == other.registrationRequest;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, protocolVersion.hashCode);
    _$hash = $jc(_$hash, loginName.hashCode);
    _$hash = $jc(_$hash, displayName.hashCode);
    _$hash = $jc(_$hash, deviceId.hashCode);
    _$hash = $jc(_$hash, deviceName.hashCode);
    _$hash = $jc(_$hash, platform.hashCode);
    _$hash = $jc(_$hash, clientVersion.hashCode);
    _$hash = $jc(_$hash, deviceKeyVersion.hashCode);
    _$hash = $jc(_$hash, signingPublicKey.hashCode);
    _$hash = $jc(_$hash, keyAgreementPublicKey.hashCode);
    _$hash = $jc(_$hash, registrationRequest.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'OpaqueRegistrationStartRequest')
          ..add('protocolVersion', protocolVersion)
          ..add('loginName', loginName)
          ..add('displayName', displayName)
          ..add('deviceId', deviceId)
          ..add('deviceName', deviceName)
          ..add('platform', platform)
          ..add('clientVersion', clientVersion)
          ..add('deviceKeyVersion', deviceKeyVersion)
          ..add('signingPublicKey', signingPublicKey)
          ..add('keyAgreementPublicKey', keyAgreementPublicKey)
          ..add('registrationRequest', registrationRequest))
        .toString();
  }
}

class OpaqueRegistrationStartRequestBuilder
    implements
        Builder<
          OpaqueRegistrationStartRequest,
          OpaqueRegistrationStartRequestBuilder
        > {
  _$OpaqueRegistrationStartRequest? _$v;

  int? _protocolVersion;
  int? get protocolVersion => _$this._protocolVersion;
  set protocolVersion(int? protocolVersion) =>
      _$this._protocolVersion = protocolVersion;

  String? _loginName;
  String? get loginName => _$this._loginName;
  set loginName(String? loginName) => _$this._loginName = loginName;

  String? _displayName;
  String? get displayName => _$this._displayName;
  set displayName(String? displayName) => _$this._displayName = displayName;

  String? _deviceId;
  String? get deviceId => _$this._deviceId;
  set deviceId(String? deviceId) => _$this._deviceId = deviceId;

  String? _deviceName;
  String? get deviceName => _$this._deviceName;
  set deviceName(String? deviceName) => _$this._deviceName = deviceName;

  OpaqueRegistrationStartRequestPlatformEnum? _platform;
  OpaqueRegistrationStartRequestPlatformEnum? get platform => _$this._platform;
  set platform(OpaqueRegistrationStartRequestPlatformEnum? platform) =>
      _$this._platform = platform;

  String? _clientVersion;
  String? get clientVersion => _$this._clientVersion;
  set clientVersion(String? clientVersion) =>
      _$this._clientVersion = clientVersion;

  int? _deviceKeyVersion;
  int? get deviceKeyVersion => _$this._deviceKeyVersion;
  set deviceKeyVersion(int? deviceKeyVersion) =>
      _$this._deviceKeyVersion = deviceKeyVersion;

  String? _signingPublicKey;
  String? get signingPublicKey => _$this._signingPublicKey;
  set signingPublicKey(String? signingPublicKey) =>
      _$this._signingPublicKey = signingPublicKey;

  String? _keyAgreementPublicKey;
  String? get keyAgreementPublicKey => _$this._keyAgreementPublicKey;
  set keyAgreementPublicKey(String? keyAgreementPublicKey) =>
      _$this._keyAgreementPublicKey = keyAgreementPublicKey;

  String? _registrationRequest;
  String? get registrationRequest => _$this._registrationRequest;
  set registrationRequest(String? registrationRequest) =>
      _$this._registrationRequest = registrationRequest;

  OpaqueRegistrationStartRequestBuilder() {
    OpaqueRegistrationStartRequest._defaults(this);
  }

  OpaqueRegistrationStartRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _protocolVersion = $v.protocolVersion;
      _loginName = $v.loginName;
      _displayName = $v.displayName;
      _deviceId = $v.deviceId;
      _deviceName = $v.deviceName;
      _platform = $v.platform;
      _clientVersion = $v.clientVersion;
      _deviceKeyVersion = $v.deviceKeyVersion;
      _signingPublicKey = $v.signingPublicKey;
      _keyAgreementPublicKey = $v.keyAgreementPublicKey;
      _registrationRequest = $v.registrationRequest;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(OpaqueRegistrationStartRequest other) {
    _$v = other as _$OpaqueRegistrationStartRequest;
  }

  @override
  void update(void Function(OpaqueRegistrationStartRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  OpaqueRegistrationStartRequest build() => _build();

  _$OpaqueRegistrationStartRequest _build() {
    final _$result =
        _$v ??
        _$OpaqueRegistrationStartRequest._(
          protocolVersion: BuiltValueNullFieldError.checkNotNull(
            protocolVersion,
            r'OpaqueRegistrationStartRequest',
            'protocolVersion',
          ),
          loginName: BuiltValueNullFieldError.checkNotNull(
            loginName,
            r'OpaqueRegistrationStartRequest',
            'loginName',
          ),
          displayName: BuiltValueNullFieldError.checkNotNull(
            displayName,
            r'OpaqueRegistrationStartRequest',
            'displayName',
          ),
          deviceId: BuiltValueNullFieldError.checkNotNull(
            deviceId,
            r'OpaqueRegistrationStartRequest',
            'deviceId',
          ),
          deviceName: BuiltValueNullFieldError.checkNotNull(
            deviceName,
            r'OpaqueRegistrationStartRequest',
            'deviceName',
          ),
          platform: BuiltValueNullFieldError.checkNotNull(
            platform,
            r'OpaqueRegistrationStartRequest',
            'platform',
          ),
          clientVersion: BuiltValueNullFieldError.checkNotNull(
            clientVersion,
            r'OpaqueRegistrationStartRequest',
            'clientVersion',
          ),
          deviceKeyVersion: BuiltValueNullFieldError.checkNotNull(
            deviceKeyVersion,
            r'OpaqueRegistrationStartRequest',
            'deviceKeyVersion',
          ),
          signingPublicKey: BuiltValueNullFieldError.checkNotNull(
            signingPublicKey,
            r'OpaqueRegistrationStartRequest',
            'signingPublicKey',
          ),
          keyAgreementPublicKey: BuiltValueNullFieldError.checkNotNull(
            keyAgreementPublicKey,
            r'OpaqueRegistrationStartRequest',
            'keyAgreementPublicKey',
          ),
          registrationRequest: BuiltValueNullFieldError.checkNotNull(
            registrationRequest,
            r'OpaqueRegistrationStartRequest',
            'registrationRequest',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
