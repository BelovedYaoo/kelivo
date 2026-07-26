// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_pairing_create_data_target_device.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const DevicePairingCreateDataTargetDevicePlatformEnum
_$devicePairingCreateDataTargetDevicePlatformEnum_android =
    const DevicePairingCreateDataTargetDevicePlatformEnum._('android');
const DevicePairingCreateDataTargetDevicePlatformEnum
_$devicePairingCreateDataTargetDevicePlatformEnum_ios =
    const DevicePairingCreateDataTargetDevicePlatformEnum._('ios');
const DevicePairingCreateDataTargetDevicePlatformEnum
_$devicePairingCreateDataTargetDevicePlatformEnum_macos =
    const DevicePairingCreateDataTargetDevicePlatformEnum._('macos');
const DevicePairingCreateDataTargetDevicePlatformEnum
_$devicePairingCreateDataTargetDevicePlatformEnum_windows =
    const DevicePairingCreateDataTargetDevicePlatformEnum._('windows');
const DevicePairingCreateDataTargetDevicePlatformEnum
_$devicePairingCreateDataTargetDevicePlatformEnum_linux =
    const DevicePairingCreateDataTargetDevicePlatformEnum._('linux');

DevicePairingCreateDataTargetDevicePlatformEnum
_$devicePairingCreateDataTargetDevicePlatformEnumValueOf(String name) {
  switch (name) {
    case 'android':
      return _$devicePairingCreateDataTargetDevicePlatformEnum_android;
    case 'ios':
      return _$devicePairingCreateDataTargetDevicePlatformEnum_ios;
    case 'macos':
      return _$devicePairingCreateDataTargetDevicePlatformEnum_macos;
    case 'windows':
      return _$devicePairingCreateDataTargetDevicePlatformEnum_windows;
    case 'linux':
      return _$devicePairingCreateDataTargetDevicePlatformEnum_linux;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<DevicePairingCreateDataTargetDevicePlatformEnum>
_$devicePairingCreateDataTargetDevicePlatformEnumValues =
    BuiltSet<DevicePairingCreateDataTargetDevicePlatformEnum>(
      const <DevicePairingCreateDataTargetDevicePlatformEnum>[
        _$devicePairingCreateDataTargetDevicePlatformEnum_android,
        _$devicePairingCreateDataTargetDevicePlatformEnum_ios,
        _$devicePairingCreateDataTargetDevicePlatformEnum_macos,
        _$devicePairingCreateDataTargetDevicePlatformEnum_windows,
        _$devicePairingCreateDataTargetDevicePlatformEnum_linux,
      ],
    );

Serializer<DevicePairingCreateDataTargetDevicePlatformEnum>
_$devicePairingCreateDataTargetDevicePlatformEnumSerializer =
    _$DevicePairingCreateDataTargetDevicePlatformEnumSerializer();

class _$DevicePairingCreateDataTargetDevicePlatformEnumSerializer
    implements
        PrimitiveSerializer<DevicePairingCreateDataTargetDevicePlatformEnum> {
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
    DevicePairingCreateDataTargetDevicePlatformEnum,
  ];
  @override
  final String wireName = 'DevicePairingCreateDataTargetDevicePlatformEnum';

  @override
  Object serialize(
    Serializers serializers,
    DevicePairingCreateDataTargetDevicePlatformEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  DevicePairingCreateDataTargetDevicePlatformEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => DevicePairingCreateDataTargetDevicePlatformEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$DevicePairingCreateDataTargetDevice
    extends DevicePairingCreateDataTargetDevice {
  @override
  final String id;
  @override
  final String name;
  @override
  final DevicePairingCreateDataTargetDevicePlatformEnum platform;
  @override
  final String clientVersion;
  @override
  final int keyVersion;
  @override
  final int authGeneration;
  @override
  final String signingPublicKey;
  @override
  final String keyAgreementPublicKey;

  factory _$DevicePairingCreateDataTargetDevice([
    void Function(DevicePairingCreateDataTargetDeviceBuilder)? updates,
  ]) =>
      (DevicePairingCreateDataTargetDeviceBuilder()..update(updates))._build();

  _$DevicePairingCreateDataTargetDevice._({
    required this.id,
    required this.name,
    required this.platform,
    required this.clientVersion,
    required this.keyVersion,
    required this.authGeneration,
    required this.signingPublicKey,
    required this.keyAgreementPublicKey,
  }) : super._();
  @override
  DevicePairingCreateDataTargetDevice rebuild(
    void Function(DevicePairingCreateDataTargetDeviceBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  DevicePairingCreateDataTargetDeviceBuilder toBuilder() =>
      DevicePairingCreateDataTargetDeviceBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DevicePairingCreateDataTargetDevice &&
        id == other.id &&
        name == other.name &&
        platform == other.platform &&
        clientVersion == other.clientVersion &&
        keyVersion == other.keyVersion &&
        authGeneration == other.authGeneration &&
        signingPublicKey == other.signingPublicKey &&
        keyAgreementPublicKey == other.keyAgreementPublicKey;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jc(_$hash, name.hashCode);
    _$hash = $jc(_$hash, platform.hashCode);
    _$hash = $jc(_$hash, clientVersion.hashCode);
    _$hash = $jc(_$hash, keyVersion.hashCode);
    _$hash = $jc(_$hash, authGeneration.hashCode);
    _$hash = $jc(_$hash, signingPublicKey.hashCode);
    _$hash = $jc(_$hash, keyAgreementPublicKey.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'DevicePairingCreateDataTargetDevice')
          ..add('id', id)
          ..add('name', name)
          ..add('platform', platform)
          ..add('clientVersion', clientVersion)
          ..add('keyVersion', keyVersion)
          ..add('authGeneration', authGeneration)
          ..add('signingPublicKey', signingPublicKey)
          ..add('keyAgreementPublicKey', keyAgreementPublicKey))
        .toString();
  }
}

class DevicePairingCreateDataTargetDeviceBuilder
    implements
        Builder<
          DevicePairingCreateDataTargetDevice,
          DevicePairingCreateDataTargetDeviceBuilder
        > {
  _$DevicePairingCreateDataTargetDevice? _$v;

  String? _id;
  String? get id => _$this._id;
  set id(String? id) => _$this._id = id;

  String? _name;
  String? get name => _$this._name;
  set name(String? name) => _$this._name = name;

  DevicePairingCreateDataTargetDevicePlatformEnum? _platform;
  DevicePairingCreateDataTargetDevicePlatformEnum? get platform =>
      _$this._platform;
  set platform(DevicePairingCreateDataTargetDevicePlatformEnum? platform) =>
      _$this._platform = platform;

  String? _clientVersion;
  String? get clientVersion => _$this._clientVersion;
  set clientVersion(String? clientVersion) =>
      _$this._clientVersion = clientVersion;

  int? _keyVersion;
  int? get keyVersion => _$this._keyVersion;
  set keyVersion(int? keyVersion) => _$this._keyVersion = keyVersion;

  int? _authGeneration;
  int? get authGeneration => _$this._authGeneration;
  set authGeneration(int? authGeneration) =>
      _$this._authGeneration = authGeneration;

  String? _signingPublicKey;
  String? get signingPublicKey => _$this._signingPublicKey;
  set signingPublicKey(String? signingPublicKey) =>
      _$this._signingPublicKey = signingPublicKey;

  String? _keyAgreementPublicKey;
  String? get keyAgreementPublicKey => _$this._keyAgreementPublicKey;
  set keyAgreementPublicKey(String? keyAgreementPublicKey) =>
      _$this._keyAgreementPublicKey = keyAgreementPublicKey;

  DevicePairingCreateDataTargetDeviceBuilder() {
    DevicePairingCreateDataTargetDevice._defaults(this);
  }

  DevicePairingCreateDataTargetDeviceBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _id = $v.id;
      _name = $v.name;
      _platform = $v.platform;
      _clientVersion = $v.clientVersion;
      _keyVersion = $v.keyVersion;
      _authGeneration = $v.authGeneration;
      _signingPublicKey = $v.signingPublicKey;
      _keyAgreementPublicKey = $v.keyAgreementPublicKey;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DevicePairingCreateDataTargetDevice other) {
    _$v = other as _$DevicePairingCreateDataTargetDevice;
  }

  @override
  void update(
    void Function(DevicePairingCreateDataTargetDeviceBuilder)? updates,
  ) {
    if (updates != null) updates(this);
  }

  @override
  DevicePairingCreateDataTargetDevice build() => _build();

  _$DevicePairingCreateDataTargetDevice _build() {
    final _$result =
        _$v ??
        _$DevicePairingCreateDataTargetDevice._(
          id: BuiltValueNullFieldError.checkNotNull(
            id,
            r'DevicePairingCreateDataTargetDevice',
            'id',
          ),
          name: BuiltValueNullFieldError.checkNotNull(
            name,
            r'DevicePairingCreateDataTargetDevice',
            'name',
          ),
          platform: BuiltValueNullFieldError.checkNotNull(
            platform,
            r'DevicePairingCreateDataTargetDevice',
            'platform',
          ),
          clientVersion: BuiltValueNullFieldError.checkNotNull(
            clientVersion,
            r'DevicePairingCreateDataTargetDevice',
            'clientVersion',
          ),
          keyVersion: BuiltValueNullFieldError.checkNotNull(
            keyVersion,
            r'DevicePairingCreateDataTargetDevice',
            'keyVersion',
          ),
          authGeneration: BuiltValueNullFieldError.checkNotNull(
            authGeneration,
            r'DevicePairingCreateDataTargetDevice',
            'authGeneration',
          ),
          signingPublicKey: BuiltValueNullFieldError.checkNotNull(
            signingPublicKey,
            r'DevicePairingCreateDataTargetDevice',
            'signingPublicKey',
          ),
          keyAgreementPublicKey: BuiltValueNullFieldError.checkNotNull(
            keyAgreementPublicKey,
            r'DevicePairingCreateDataTargetDevice',
            'keyAgreementPublicKey',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
