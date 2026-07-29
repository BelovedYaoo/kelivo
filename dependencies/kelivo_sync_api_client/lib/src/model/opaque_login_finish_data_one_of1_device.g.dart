// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'opaque_login_finish_data_one_of1_device.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const OpaqueLoginFinishDataOneOf1DevicePlatformEnum
_$opaqueLoginFinishDataOneOf1DevicePlatformEnum_android =
    const OpaqueLoginFinishDataOneOf1DevicePlatformEnum._('android');
const OpaqueLoginFinishDataOneOf1DevicePlatformEnum
_$opaqueLoginFinishDataOneOf1DevicePlatformEnum_ios =
    const OpaqueLoginFinishDataOneOf1DevicePlatformEnum._('ios');
const OpaqueLoginFinishDataOneOf1DevicePlatformEnum
_$opaqueLoginFinishDataOneOf1DevicePlatformEnum_macos =
    const OpaqueLoginFinishDataOneOf1DevicePlatformEnum._('macos');
const OpaqueLoginFinishDataOneOf1DevicePlatformEnum
_$opaqueLoginFinishDataOneOf1DevicePlatformEnum_windows =
    const OpaqueLoginFinishDataOneOf1DevicePlatformEnum._('windows');
const OpaqueLoginFinishDataOneOf1DevicePlatformEnum
_$opaqueLoginFinishDataOneOf1DevicePlatformEnum_linux =
    const OpaqueLoginFinishDataOneOf1DevicePlatformEnum._('linux');

OpaqueLoginFinishDataOneOf1DevicePlatformEnum
_$opaqueLoginFinishDataOneOf1DevicePlatformEnumValueOf(String name) {
  switch (name) {
    case 'android':
      return _$opaqueLoginFinishDataOneOf1DevicePlatformEnum_android;
    case 'ios':
      return _$opaqueLoginFinishDataOneOf1DevicePlatformEnum_ios;
    case 'macos':
      return _$opaqueLoginFinishDataOneOf1DevicePlatformEnum_macos;
    case 'windows':
      return _$opaqueLoginFinishDataOneOf1DevicePlatformEnum_windows;
    case 'linux':
      return _$opaqueLoginFinishDataOneOf1DevicePlatformEnum_linux;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<OpaqueLoginFinishDataOneOf1DevicePlatformEnum>
_$opaqueLoginFinishDataOneOf1DevicePlatformEnumValues =
    BuiltSet<OpaqueLoginFinishDataOneOf1DevicePlatformEnum>(
      const <OpaqueLoginFinishDataOneOf1DevicePlatformEnum>[
        _$opaqueLoginFinishDataOneOf1DevicePlatformEnum_android,
        _$opaqueLoginFinishDataOneOf1DevicePlatformEnum_ios,
        _$opaqueLoginFinishDataOneOf1DevicePlatformEnum_macos,
        _$opaqueLoginFinishDataOneOf1DevicePlatformEnum_windows,
        _$opaqueLoginFinishDataOneOf1DevicePlatformEnum_linux,
      ],
    );

const OpaqueLoginFinishDataOneOf1DeviceStatusEnum
_$opaqueLoginFinishDataOneOf1DeviceStatusEnum_pending =
    const OpaqueLoginFinishDataOneOf1DeviceStatusEnum._('pending');

OpaqueLoginFinishDataOneOf1DeviceStatusEnum
_$opaqueLoginFinishDataOneOf1DeviceStatusEnumValueOf(String name) {
  switch (name) {
    case 'pending':
      return _$opaqueLoginFinishDataOneOf1DeviceStatusEnum_pending;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<OpaqueLoginFinishDataOneOf1DeviceStatusEnum>
_$opaqueLoginFinishDataOneOf1DeviceStatusEnumValues =
    BuiltSet<OpaqueLoginFinishDataOneOf1DeviceStatusEnum>(
      const <OpaqueLoginFinishDataOneOf1DeviceStatusEnum>[
        _$opaqueLoginFinishDataOneOf1DeviceStatusEnum_pending,
      ],
    );

Serializer<OpaqueLoginFinishDataOneOf1DevicePlatformEnum>
_$opaqueLoginFinishDataOneOf1DevicePlatformEnumSerializer =
    _$OpaqueLoginFinishDataOneOf1DevicePlatformEnumSerializer();
Serializer<OpaqueLoginFinishDataOneOf1DeviceStatusEnum>
_$opaqueLoginFinishDataOneOf1DeviceStatusEnumSerializer =
    _$OpaqueLoginFinishDataOneOf1DeviceStatusEnumSerializer();

class _$OpaqueLoginFinishDataOneOf1DevicePlatformEnumSerializer
    implements
        PrimitiveSerializer<OpaqueLoginFinishDataOneOf1DevicePlatformEnum> {
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
    OpaqueLoginFinishDataOneOf1DevicePlatformEnum,
  ];
  @override
  final String wireName = 'OpaqueLoginFinishDataOneOf1DevicePlatformEnum';

  @override
  Object serialize(
    Serializers serializers,
    OpaqueLoginFinishDataOneOf1DevicePlatformEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  OpaqueLoginFinishDataOneOf1DevicePlatformEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => OpaqueLoginFinishDataOneOf1DevicePlatformEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$OpaqueLoginFinishDataOneOf1DeviceStatusEnumSerializer
    implements
        PrimitiveSerializer<OpaqueLoginFinishDataOneOf1DeviceStatusEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'pending': 'pending',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'pending': 'pending',
  };

  @override
  final Iterable<Type> types = const <Type>[
    OpaqueLoginFinishDataOneOf1DeviceStatusEnum,
  ];
  @override
  final String wireName = 'OpaqueLoginFinishDataOneOf1DeviceStatusEnum';

  @override
  Object serialize(
    Serializers serializers,
    OpaqueLoginFinishDataOneOf1DeviceStatusEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  OpaqueLoginFinishDataOneOf1DeviceStatusEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => OpaqueLoginFinishDataOneOf1DeviceStatusEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$OpaqueLoginFinishDataOneOf1Device
    extends OpaqueLoginFinishDataOneOf1Device {
  @override
  final String id;
  @override
  final String name;
  @override
  final OpaqueLoginFinishDataOneOf1DevicePlatformEnum platform;
  @override
  final String clientVersion;
  @override
  final int authGeneration;
  @override
  final OpaqueLoginFinishDataOneOf1DeviceStatusEnum status;
  @override
  final DateTime createdAt;

  factory _$OpaqueLoginFinishDataOneOf1Device([
    void Function(OpaqueLoginFinishDataOneOf1DeviceBuilder)? updates,
  ]) => (OpaqueLoginFinishDataOneOf1DeviceBuilder()..update(updates))._build();

  _$OpaqueLoginFinishDataOneOf1Device._({
    required this.id,
    required this.name,
    required this.platform,
    required this.clientVersion,
    required this.authGeneration,
    required this.status,
    required this.createdAt,
  }) : super._();
  @override
  OpaqueLoginFinishDataOneOf1Device rebuild(
    void Function(OpaqueLoginFinishDataOneOf1DeviceBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  OpaqueLoginFinishDataOneOf1DeviceBuilder toBuilder() =>
      OpaqueLoginFinishDataOneOf1DeviceBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is OpaqueLoginFinishDataOneOf1Device &&
        id == other.id &&
        name == other.name &&
        platform == other.platform &&
        clientVersion == other.clientVersion &&
        authGeneration == other.authGeneration &&
        status == other.status &&
        createdAt == other.createdAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jc(_$hash, name.hashCode);
    _$hash = $jc(_$hash, platform.hashCode);
    _$hash = $jc(_$hash, clientVersion.hashCode);
    _$hash = $jc(_$hash, authGeneration.hashCode);
    _$hash = $jc(_$hash, status.hashCode);
    _$hash = $jc(_$hash, createdAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'OpaqueLoginFinishDataOneOf1Device')
          ..add('id', id)
          ..add('name', name)
          ..add('platform', platform)
          ..add('clientVersion', clientVersion)
          ..add('authGeneration', authGeneration)
          ..add('status', status)
          ..add('createdAt', createdAt))
        .toString();
  }
}

class OpaqueLoginFinishDataOneOf1DeviceBuilder
    implements
        Builder<
          OpaqueLoginFinishDataOneOf1Device,
          OpaqueLoginFinishDataOneOf1DeviceBuilder
        > {
  _$OpaqueLoginFinishDataOneOf1Device? _$v;

  String? _id;
  String? get id => _$this._id;
  set id(String? id) => _$this._id = id;

  String? _name;
  String? get name => _$this._name;
  set name(String? name) => _$this._name = name;

  OpaqueLoginFinishDataOneOf1DevicePlatformEnum? _platform;
  OpaqueLoginFinishDataOneOf1DevicePlatformEnum? get platform =>
      _$this._platform;
  set platform(OpaqueLoginFinishDataOneOf1DevicePlatformEnum? platform) =>
      _$this._platform = platform;

  String? _clientVersion;
  String? get clientVersion => _$this._clientVersion;
  set clientVersion(String? clientVersion) =>
      _$this._clientVersion = clientVersion;

  int? _authGeneration;
  int? get authGeneration => _$this._authGeneration;
  set authGeneration(int? authGeneration) =>
      _$this._authGeneration = authGeneration;

  OpaqueLoginFinishDataOneOf1DeviceStatusEnum? _status;
  OpaqueLoginFinishDataOneOf1DeviceStatusEnum? get status => _$this._status;
  set status(OpaqueLoginFinishDataOneOf1DeviceStatusEnum? status) =>
      _$this._status = status;

  DateTime? _createdAt;
  DateTime? get createdAt => _$this._createdAt;
  set createdAt(DateTime? createdAt) => _$this._createdAt = createdAt;

  OpaqueLoginFinishDataOneOf1DeviceBuilder() {
    OpaqueLoginFinishDataOneOf1Device._defaults(this);
  }

  OpaqueLoginFinishDataOneOf1DeviceBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _id = $v.id;
      _name = $v.name;
      _platform = $v.platform;
      _clientVersion = $v.clientVersion;
      _authGeneration = $v.authGeneration;
      _status = $v.status;
      _createdAt = $v.createdAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(OpaqueLoginFinishDataOneOf1Device other) {
    _$v = other as _$OpaqueLoginFinishDataOneOf1Device;
  }

  @override
  void update(
    void Function(OpaqueLoginFinishDataOneOf1DeviceBuilder)? updates,
  ) {
    if (updates != null) updates(this);
  }

  @override
  OpaqueLoginFinishDataOneOf1Device build() => _build();

  _$OpaqueLoginFinishDataOneOf1Device _build() {
    final _$result =
        _$v ??
        _$OpaqueLoginFinishDataOneOf1Device._(
          id: BuiltValueNullFieldError.checkNotNull(
            id,
            r'OpaqueLoginFinishDataOneOf1Device',
            'id',
          ),
          name: BuiltValueNullFieldError.checkNotNull(
            name,
            r'OpaqueLoginFinishDataOneOf1Device',
            'name',
          ),
          platform: BuiltValueNullFieldError.checkNotNull(
            platform,
            r'OpaqueLoginFinishDataOneOf1Device',
            'platform',
          ),
          clientVersion: BuiltValueNullFieldError.checkNotNull(
            clientVersion,
            r'OpaqueLoginFinishDataOneOf1Device',
            'clientVersion',
          ),
          authGeneration: BuiltValueNullFieldError.checkNotNull(
            authGeneration,
            r'OpaqueLoginFinishDataOneOf1Device',
            'authGeneration',
          ),
          status: BuiltValueNullFieldError.checkNotNull(
            status,
            r'OpaqueLoginFinishDataOneOf1Device',
            'status',
          ),
          createdAt: BuiltValueNullFieldError.checkNotNull(
            createdAt,
            r'OpaqueLoginFinishDataOneOf1Device',
            'createdAt',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
