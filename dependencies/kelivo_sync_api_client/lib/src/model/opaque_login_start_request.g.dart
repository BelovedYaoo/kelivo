// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'opaque_login_start_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const OpaqueLoginStartRequestPlatformEnum
_$opaqueLoginStartRequestPlatformEnum_android =
    const OpaqueLoginStartRequestPlatformEnum._('android');
const OpaqueLoginStartRequestPlatformEnum
_$opaqueLoginStartRequestPlatformEnum_ios =
    const OpaqueLoginStartRequestPlatformEnum._('ios');
const OpaqueLoginStartRequestPlatformEnum
_$opaqueLoginStartRequestPlatformEnum_macos =
    const OpaqueLoginStartRequestPlatformEnum._('macos');
const OpaqueLoginStartRequestPlatformEnum
_$opaqueLoginStartRequestPlatformEnum_windows =
    const OpaqueLoginStartRequestPlatformEnum._('windows');
const OpaqueLoginStartRequestPlatformEnum
_$opaqueLoginStartRequestPlatformEnum_linux =
    const OpaqueLoginStartRequestPlatformEnum._('linux');

OpaqueLoginStartRequestPlatformEnum
_$opaqueLoginStartRequestPlatformEnumValueOf(String name) {
  switch (name) {
    case 'android':
      return _$opaqueLoginStartRequestPlatformEnum_android;
    case 'ios':
      return _$opaqueLoginStartRequestPlatformEnum_ios;
    case 'macos':
      return _$opaqueLoginStartRequestPlatformEnum_macos;
    case 'windows':
      return _$opaqueLoginStartRequestPlatformEnum_windows;
    case 'linux':
      return _$opaqueLoginStartRequestPlatformEnum_linux;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<OpaqueLoginStartRequestPlatformEnum>
_$opaqueLoginStartRequestPlatformEnumValues =
    BuiltSet<OpaqueLoginStartRequestPlatformEnum>(
      const <OpaqueLoginStartRequestPlatformEnum>[
        _$opaqueLoginStartRequestPlatformEnum_android,
        _$opaqueLoginStartRequestPlatformEnum_ios,
        _$opaqueLoginStartRequestPlatformEnum_macos,
        _$opaqueLoginStartRequestPlatformEnum_windows,
        _$opaqueLoginStartRequestPlatformEnum_linux,
      ],
    );

Serializer<OpaqueLoginStartRequestPlatformEnum>
_$opaqueLoginStartRequestPlatformEnumSerializer =
    _$OpaqueLoginStartRequestPlatformEnumSerializer();

class _$OpaqueLoginStartRequestPlatformEnumSerializer
    implements PrimitiveSerializer<OpaqueLoginStartRequestPlatformEnum> {
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
    OpaqueLoginStartRequestPlatformEnum,
  ];
  @override
  final String wireName = 'OpaqueLoginStartRequestPlatformEnum';

  @override
  Object serialize(
    Serializers serializers,
    OpaqueLoginStartRequestPlatformEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  OpaqueLoginStartRequestPlatformEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => OpaqueLoginStartRequestPlatformEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$OpaqueLoginStartRequest extends OpaqueLoginStartRequest {
  @override
  final int protocolVersion;
  @override
  final String loginName;
  @override
  final String deviceId;
  @override
  final String deviceName;
  @override
  final OpaqueLoginStartRequestPlatformEnum platform;
  @override
  final String clientVersion;
  @override
  final int deviceKeyVersion;
  @override
  final String signingPublicKey;
  @override
  final String keyAgreementPublicKey;
  @override
  final String credentialRequest;

  factory _$OpaqueLoginStartRequest([
    void Function(OpaqueLoginStartRequestBuilder)? updates,
  ]) => (OpaqueLoginStartRequestBuilder()..update(updates))._build();

  _$OpaqueLoginStartRequest._({
    required this.protocolVersion,
    required this.loginName,
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.clientVersion,
    required this.deviceKeyVersion,
    required this.signingPublicKey,
    required this.keyAgreementPublicKey,
    required this.credentialRequest,
  }) : super._();
  @override
  OpaqueLoginStartRequest rebuild(
    void Function(OpaqueLoginStartRequestBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  OpaqueLoginStartRequestBuilder toBuilder() =>
      OpaqueLoginStartRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is OpaqueLoginStartRequest &&
        protocolVersion == other.protocolVersion &&
        loginName == other.loginName &&
        deviceId == other.deviceId &&
        deviceName == other.deviceName &&
        platform == other.platform &&
        clientVersion == other.clientVersion &&
        deviceKeyVersion == other.deviceKeyVersion &&
        signingPublicKey == other.signingPublicKey &&
        keyAgreementPublicKey == other.keyAgreementPublicKey &&
        credentialRequest == other.credentialRequest;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, protocolVersion.hashCode);
    _$hash = $jc(_$hash, loginName.hashCode);
    _$hash = $jc(_$hash, deviceId.hashCode);
    _$hash = $jc(_$hash, deviceName.hashCode);
    _$hash = $jc(_$hash, platform.hashCode);
    _$hash = $jc(_$hash, clientVersion.hashCode);
    _$hash = $jc(_$hash, deviceKeyVersion.hashCode);
    _$hash = $jc(_$hash, signingPublicKey.hashCode);
    _$hash = $jc(_$hash, keyAgreementPublicKey.hashCode);
    _$hash = $jc(_$hash, credentialRequest.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'OpaqueLoginStartRequest')
          ..add('protocolVersion', protocolVersion)
          ..add('loginName', loginName)
          ..add('deviceId', deviceId)
          ..add('deviceName', deviceName)
          ..add('platform', platform)
          ..add('clientVersion', clientVersion)
          ..add('deviceKeyVersion', deviceKeyVersion)
          ..add('signingPublicKey', signingPublicKey)
          ..add('keyAgreementPublicKey', keyAgreementPublicKey)
          ..add('credentialRequest', credentialRequest))
        .toString();
  }
}

class OpaqueLoginStartRequestBuilder
    implements
        Builder<OpaqueLoginStartRequest, OpaqueLoginStartRequestBuilder> {
  _$OpaqueLoginStartRequest? _$v;

  int? _protocolVersion;
  int? get protocolVersion => _$this._protocolVersion;
  set protocolVersion(int? protocolVersion) =>
      _$this._protocolVersion = protocolVersion;

  String? _loginName;
  String? get loginName => _$this._loginName;
  set loginName(String? loginName) => _$this._loginName = loginName;

  String? _deviceId;
  String? get deviceId => _$this._deviceId;
  set deviceId(String? deviceId) => _$this._deviceId = deviceId;

  String? _deviceName;
  String? get deviceName => _$this._deviceName;
  set deviceName(String? deviceName) => _$this._deviceName = deviceName;

  OpaqueLoginStartRequestPlatformEnum? _platform;
  OpaqueLoginStartRequestPlatformEnum? get platform => _$this._platform;
  set platform(OpaqueLoginStartRequestPlatformEnum? platform) =>
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

  String? _credentialRequest;
  String? get credentialRequest => _$this._credentialRequest;
  set credentialRequest(String? credentialRequest) =>
      _$this._credentialRequest = credentialRequest;

  OpaqueLoginStartRequestBuilder() {
    OpaqueLoginStartRequest._defaults(this);
  }

  OpaqueLoginStartRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _protocolVersion = $v.protocolVersion;
      _loginName = $v.loginName;
      _deviceId = $v.deviceId;
      _deviceName = $v.deviceName;
      _platform = $v.platform;
      _clientVersion = $v.clientVersion;
      _deviceKeyVersion = $v.deviceKeyVersion;
      _signingPublicKey = $v.signingPublicKey;
      _keyAgreementPublicKey = $v.keyAgreementPublicKey;
      _credentialRequest = $v.credentialRequest;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(OpaqueLoginStartRequest other) {
    _$v = other as _$OpaqueLoginStartRequest;
  }

  @override
  void update(void Function(OpaqueLoginStartRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  OpaqueLoginStartRequest build() => _build();

  _$OpaqueLoginStartRequest _build() {
    final _$result =
        _$v ??
        _$OpaqueLoginStartRequest._(
          protocolVersion: BuiltValueNullFieldError.checkNotNull(
            protocolVersion,
            r'OpaqueLoginStartRequest',
            'protocolVersion',
          ),
          loginName: BuiltValueNullFieldError.checkNotNull(
            loginName,
            r'OpaqueLoginStartRequest',
            'loginName',
          ),
          deviceId: BuiltValueNullFieldError.checkNotNull(
            deviceId,
            r'OpaqueLoginStartRequest',
            'deviceId',
          ),
          deviceName: BuiltValueNullFieldError.checkNotNull(
            deviceName,
            r'OpaqueLoginStartRequest',
            'deviceName',
          ),
          platform: BuiltValueNullFieldError.checkNotNull(
            platform,
            r'OpaqueLoginStartRequest',
            'platform',
          ),
          clientVersion: BuiltValueNullFieldError.checkNotNull(
            clientVersion,
            r'OpaqueLoginStartRequest',
            'clientVersion',
          ),
          deviceKeyVersion: BuiltValueNullFieldError.checkNotNull(
            deviceKeyVersion,
            r'OpaqueLoginStartRequest',
            'deviceKeyVersion',
          ),
          signingPublicKey: BuiltValueNullFieldError.checkNotNull(
            signingPublicKey,
            r'OpaqueLoginStartRequest',
            'signingPublicKey',
          ),
          keyAgreementPublicKey: BuiltValueNullFieldError.checkNotNull(
            keyAgreementPublicKey,
            r'OpaqueLoginStartRequest',
            'keyAgreementPublicKey',
          ),
          credentialRequest: BuiltValueNullFieldError.checkNotNull(
            credentialRequest,
            r'OpaqueLoginStartRequest',
            'credentialRequest',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
