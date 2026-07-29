// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'opaque_registration_finish_data_device.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const OpaqueRegistrationFinishDataDevicePlatformEnum
_$opaqueRegistrationFinishDataDevicePlatformEnum_android =
    const OpaqueRegistrationFinishDataDevicePlatformEnum._('android');
const OpaqueRegistrationFinishDataDevicePlatformEnum
_$opaqueRegistrationFinishDataDevicePlatformEnum_ios =
    const OpaqueRegistrationFinishDataDevicePlatformEnum._('ios');
const OpaqueRegistrationFinishDataDevicePlatformEnum
_$opaqueRegistrationFinishDataDevicePlatformEnum_macos =
    const OpaqueRegistrationFinishDataDevicePlatformEnum._('macos');
const OpaqueRegistrationFinishDataDevicePlatformEnum
_$opaqueRegistrationFinishDataDevicePlatformEnum_windows =
    const OpaqueRegistrationFinishDataDevicePlatformEnum._('windows');
const OpaqueRegistrationFinishDataDevicePlatformEnum
_$opaqueRegistrationFinishDataDevicePlatformEnum_linux =
    const OpaqueRegistrationFinishDataDevicePlatformEnum._('linux');

OpaqueRegistrationFinishDataDevicePlatformEnum
_$opaqueRegistrationFinishDataDevicePlatformEnumValueOf(String name) {
  switch (name) {
    case 'android':
      return _$opaqueRegistrationFinishDataDevicePlatformEnum_android;
    case 'ios':
      return _$opaqueRegistrationFinishDataDevicePlatformEnum_ios;
    case 'macos':
      return _$opaqueRegistrationFinishDataDevicePlatformEnum_macos;
    case 'windows':
      return _$opaqueRegistrationFinishDataDevicePlatformEnum_windows;
    case 'linux':
      return _$opaqueRegistrationFinishDataDevicePlatformEnum_linux;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<OpaqueRegistrationFinishDataDevicePlatformEnum>
_$opaqueRegistrationFinishDataDevicePlatformEnumValues =
    BuiltSet<OpaqueRegistrationFinishDataDevicePlatformEnum>(
      const <OpaqueRegistrationFinishDataDevicePlatformEnum>[
        _$opaqueRegistrationFinishDataDevicePlatformEnum_android,
        _$opaqueRegistrationFinishDataDevicePlatformEnum_ios,
        _$opaqueRegistrationFinishDataDevicePlatformEnum_macos,
        _$opaqueRegistrationFinishDataDevicePlatformEnum_windows,
        _$opaqueRegistrationFinishDataDevicePlatformEnum_linux,
      ],
    );

const OpaqueRegistrationFinishDataDeviceStatusEnum
_$opaqueRegistrationFinishDataDeviceStatusEnum_active =
    const OpaqueRegistrationFinishDataDeviceStatusEnum._('active');

OpaqueRegistrationFinishDataDeviceStatusEnum
_$opaqueRegistrationFinishDataDeviceStatusEnumValueOf(String name) {
  switch (name) {
    case 'active':
      return _$opaqueRegistrationFinishDataDeviceStatusEnum_active;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<OpaqueRegistrationFinishDataDeviceStatusEnum>
_$opaqueRegistrationFinishDataDeviceStatusEnumValues =
    BuiltSet<OpaqueRegistrationFinishDataDeviceStatusEnum>(
      const <OpaqueRegistrationFinishDataDeviceStatusEnum>[
        _$opaqueRegistrationFinishDataDeviceStatusEnum_active,
      ],
    );

Serializer<OpaqueRegistrationFinishDataDevicePlatformEnum>
_$opaqueRegistrationFinishDataDevicePlatformEnumSerializer =
    _$OpaqueRegistrationFinishDataDevicePlatformEnumSerializer();
Serializer<OpaqueRegistrationFinishDataDeviceStatusEnum>
_$opaqueRegistrationFinishDataDeviceStatusEnumSerializer =
    _$OpaqueRegistrationFinishDataDeviceStatusEnumSerializer();

class _$OpaqueRegistrationFinishDataDevicePlatformEnumSerializer
    implements
        PrimitiveSerializer<OpaqueRegistrationFinishDataDevicePlatformEnum> {
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
    OpaqueRegistrationFinishDataDevicePlatformEnum,
  ];
  @override
  final String wireName = 'OpaqueRegistrationFinishDataDevicePlatformEnum';

  @override
  Object serialize(
    Serializers serializers,
    OpaqueRegistrationFinishDataDevicePlatformEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  OpaqueRegistrationFinishDataDevicePlatformEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => OpaqueRegistrationFinishDataDevicePlatformEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$OpaqueRegistrationFinishDataDeviceStatusEnumSerializer
    implements
        PrimitiveSerializer<OpaqueRegistrationFinishDataDeviceStatusEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'active': 'active',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'active': 'active',
  };

  @override
  final Iterable<Type> types = const <Type>[
    OpaqueRegistrationFinishDataDeviceStatusEnum,
  ];
  @override
  final String wireName = 'OpaqueRegistrationFinishDataDeviceStatusEnum';

  @override
  Object serialize(
    Serializers serializers,
    OpaqueRegistrationFinishDataDeviceStatusEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  OpaqueRegistrationFinishDataDeviceStatusEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => OpaqueRegistrationFinishDataDeviceStatusEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$OpaqueRegistrationFinishDataDevice
    extends OpaqueRegistrationFinishDataDevice {
  @override
  final String id;
  @override
  final String name;
  @override
  final OpaqueRegistrationFinishDataDevicePlatformEnum platform;
  @override
  final String clientVersion;
  @override
  final int authGeneration;
  @override
  final OpaqueRegistrationFinishDataDeviceStatusEnum status;
  @override
  final DateTime createdAt;
  @override
  final int sessionGeneration;

  factory _$OpaqueRegistrationFinishDataDevice([
    void Function(OpaqueRegistrationFinishDataDeviceBuilder)? updates,
  ]) => (OpaqueRegistrationFinishDataDeviceBuilder()..update(updates))._build();

  _$OpaqueRegistrationFinishDataDevice._({
    required this.id,
    required this.name,
    required this.platform,
    required this.clientVersion,
    required this.authGeneration,
    required this.status,
    required this.createdAt,
    required this.sessionGeneration,
  }) : super._();
  @override
  OpaqueRegistrationFinishDataDevice rebuild(
    void Function(OpaqueRegistrationFinishDataDeviceBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  OpaqueRegistrationFinishDataDeviceBuilder toBuilder() =>
      OpaqueRegistrationFinishDataDeviceBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is OpaqueRegistrationFinishDataDevice &&
        id == other.id &&
        name == other.name &&
        platform == other.platform &&
        clientVersion == other.clientVersion &&
        authGeneration == other.authGeneration &&
        status == other.status &&
        createdAt == other.createdAt &&
        sessionGeneration == other.sessionGeneration;
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
    _$hash = $jc(_$hash, sessionGeneration.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'OpaqueRegistrationFinishDataDevice')
          ..add('id', id)
          ..add('name', name)
          ..add('platform', platform)
          ..add('clientVersion', clientVersion)
          ..add('authGeneration', authGeneration)
          ..add('status', status)
          ..add('createdAt', createdAt)
          ..add('sessionGeneration', sessionGeneration))
        .toString();
  }
}

class OpaqueRegistrationFinishDataDeviceBuilder
    implements
        Builder<
          OpaqueRegistrationFinishDataDevice,
          OpaqueRegistrationFinishDataDeviceBuilder
        > {
  _$OpaqueRegistrationFinishDataDevice? _$v;

  String? _id;
  String? get id => _$this._id;
  set id(String? id) => _$this._id = id;

  String? _name;
  String? get name => _$this._name;
  set name(String? name) => _$this._name = name;

  OpaqueRegistrationFinishDataDevicePlatformEnum? _platform;
  OpaqueRegistrationFinishDataDevicePlatformEnum? get platform =>
      _$this._platform;
  set platform(OpaqueRegistrationFinishDataDevicePlatformEnum? platform) =>
      _$this._platform = platform;

  String? _clientVersion;
  String? get clientVersion => _$this._clientVersion;
  set clientVersion(String? clientVersion) =>
      _$this._clientVersion = clientVersion;

  int? _authGeneration;
  int? get authGeneration => _$this._authGeneration;
  set authGeneration(int? authGeneration) =>
      _$this._authGeneration = authGeneration;

  OpaqueRegistrationFinishDataDeviceStatusEnum? _status;
  OpaqueRegistrationFinishDataDeviceStatusEnum? get status => _$this._status;
  set status(OpaqueRegistrationFinishDataDeviceStatusEnum? status) =>
      _$this._status = status;

  DateTime? _createdAt;
  DateTime? get createdAt => _$this._createdAt;
  set createdAt(DateTime? createdAt) => _$this._createdAt = createdAt;

  int? _sessionGeneration;
  int? get sessionGeneration => _$this._sessionGeneration;
  set sessionGeneration(int? sessionGeneration) =>
      _$this._sessionGeneration = sessionGeneration;

  OpaqueRegistrationFinishDataDeviceBuilder() {
    OpaqueRegistrationFinishDataDevice._defaults(this);
  }

  OpaqueRegistrationFinishDataDeviceBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _id = $v.id;
      _name = $v.name;
      _platform = $v.platform;
      _clientVersion = $v.clientVersion;
      _authGeneration = $v.authGeneration;
      _status = $v.status;
      _createdAt = $v.createdAt;
      _sessionGeneration = $v.sessionGeneration;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(OpaqueRegistrationFinishDataDevice other) {
    _$v = other as _$OpaqueRegistrationFinishDataDevice;
  }

  @override
  void update(
    void Function(OpaqueRegistrationFinishDataDeviceBuilder)? updates,
  ) {
    if (updates != null) updates(this);
  }

  @override
  OpaqueRegistrationFinishDataDevice build() => _build();

  _$OpaqueRegistrationFinishDataDevice _build() {
    final _$result =
        _$v ??
        _$OpaqueRegistrationFinishDataDevice._(
          id: BuiltValueNullFieldError.checkNotNull(
            id,
            r'OpaqueRegistrationFinishDataDevice',
            'id',
          ),
          name: BuiltValueNullFieldError.checkNotNull(
            name,
            r'OpaqueRegistrationFinishDataDevice',
            'name',
          ),
          platform: BuiltValueNullFieldError.checkNotNull(
            platform,
            r'OpaqueRegistrationFinishDataDevice',
            'platform',
          ),
          clientVersion: BuiltValueNullFieldError.checkNotNull(
            clientVersion,
            r'OpaqueRegistrationFinishDataDevice',
            'clientVersion',
          ),
          authGeneration: BuiltValueNullFieldError.checkNotNull(
            authGeneration,
            r'OpaqueRegistrationFinishDataDevice',
            'authGeneration',
          ),
          status: BuiltValueNullFieldError.checkNotNull(
            status,
            r'OpaqueRegistrationFinishDataDevice',
            'status',
          ),
          createdAt: BuiltValueNullFieldError.checkNotNull(
            createdAt,
            r'OpaqueRegistrationFinishDataDevice',
            'createdAt',
          ),
          sessionGeneration: BuiltValueNullFieldError.checkNotNull(
            sessionGeneration,
            r'OpaqueRegistrationFinishDataDevice',
            'sessionGeneration',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
