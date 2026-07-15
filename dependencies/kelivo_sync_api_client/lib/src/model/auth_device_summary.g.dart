// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_device_summary.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const AuthDeviceSummaryPlatformEnum _$authDeviceSummaryPlatformEnum_android =
    const AuthDeviceSummaryPlatformEnum._('android');
const AuthDeviceSummaryPlatformEnum _$authDeviceSummaryPlatformEnum_ios =
    const AuthDeviceSummaryPlatformEnum._('ios');
const AuthDeviceSummaryPlatformEnum _$authDeviceSummaryPlatformEnum_macos =
    const AuthDeviceSummaryPlatformEnum._('macos');
const AuthDeviceSummaryPlatformEnum _$authDeviceSummaryPlatformEnum_windows =
    const AuthDeviceSummaryPlatformEnum._('windows');
const AuthDeviceSummaryPlatformEnum _$authDeviceSummaryPlatformEnum_linux =
    const AuthDeviceSummaryPlatformEnum._('linux');

AuthDeviceSummaryPlatformEnum _$authDeviceSummaryPlatformEnumValueOf(
  String name,
) {
  switch (name) {
    case 'android':
      return _$authDeviceSummaryPlatformEnum_android;
    case 'ios':
      return _$authDeviceSummaryPlatformEnum_ios;
    case 'macos':
      return _$authDeviceSummaryPlatformEnum_macos;
    case 'windows':
      return _$authDeviceSummaryPlatformEnum_windows;
    case 'linux':
      return _$authDeviceSummaryPlatformEnum_linux;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<AuthDeviceSummaryPlatformEnum>
_$authDeviceSummaryPlatformEnumValues = BuiltSet<AuthDeviceSummaryPlatformEnum>(
  const <AuthDeviceSummaryPlatformEnum>[
    _$authDeviceSummaryPlatformEnum_android,
    _$authDeviceSummaryPlatformEnum_ios,
    _$authDeviceSummaryPlatformEnum_macos,
    _$authDeviceSummaryPlatformEnum_windows,
    _$authDeviceSummaryPlatformEnum_linux,
  ],
);

Serializer<AuthDeviceSummaryPlatformEnum>
_$authDeviceSummaryPlatformEnumSerializer =
    _$AuthDeviceSummaryPlatformEnumSerializer();

class _$AuthDeviceSummaryPlatformEnumSerializer
    implements PrimitiveSerializer<AuthDeviceSummaryPlatformEnum> {
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
  final Iterable<Type> types = const <Type>[AuthDeviceSummaryPlatformEnum];
  @override
  final String wireName = 'AuthDeviceSummaryPlatformEnum';

  @override
  Object serialize(
    Serializers serializers,
    AuthDeviceSummaryPlatformEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  AuthDeviceSummaryPlatformEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => AuthDeviceSummaryPlatformEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$AuthDeviceSummary extends AuthDeviceSummary {
  @override
  final String id;
  @override
  final String name;
  @override
  final AuthDeviceSummaryPlatformEnum platform;
  @override
  final String clientVersion;
  @override
  final DateTime createdAt;

  factory _$AuthDeviceSummary([
    void Function(AuthDeviceSummaryBuilder)? updates,
  ]) => (AuthDeviceSummaryBuilder()..update(updates))._build();

  _$AuthDeviceSummary._({
    required this.id,
    required this.name,
    required this.platform,
    required this.clientVersion,
    required this.createdAt,
  }) : super._();
  @override
  AuthDeviceSummary rebuild(void Function(AuthDeviceSummaryBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  AuthDeviceSummaryBuilder toBuilder() =>
      AuthDeviceSummaryBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AuthDeviceSummary &&
        id == other.id &&
        name == other.name &&
        platform == other.platform &&
        clientVersion == other.clientVersion &&
        createdAt == other.createdAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jc(_$hash, name.hashCode);
    _$hash = $jc(_$hash, platform.hashCode);
    _$hash = $jc(_$hash, clientVersion.hashCode);
    _$hash = $jc(_$hash, createdAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'AuthDeviceSummary')
          ..add('id', id)
          ..add('name', name)
          ..add('platform', platform)
          ..add('clientVersion', clientVersion)
          ..add('createdAt', createdAt))
        .toString();
  }
}

class AuthDeviceSummaryBuilder
    implements Builder<AuthDeviceSummary, AuthDeviceSummaryBuilder> {
  _$AuthDeviceSummary? _$v;

  String? _id;
  String? get id => _$this._id;
  set id(String? id) => _$this._id = id;

  String? _name;
  String? get name => _$this._name;
  set name(String? name) => _$this._name = name;

  AuthDeviceSummaryPlatformEnum? _platform;
  AuthDeviceSummaryPlatformEnum? get platform => _$this._platform;
  set platform(AuthDeviceSummaryPlatformEnum? platform) =>
      _$this._platform = platform;

  String? _clientVersion;
  String? get clientVersion => _$this._clientVersion;
  set clientVersion(String? clientVersion) =>
      _$this._clientVersion = clientVersion;

  DateTime? _createdAt;
  DateTime? get createdAt => _$this._createdAt;
  set createdAt(DateTime? createdAt) => _$this._createdAt = createdAt;

  AuthDeviceSummaryBuilder() {
    AuthDeviceSummary._defaults(this);
  }

  AuthDeviceSummaryBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _id = $v.id;
      _name = $v.name;
      _platform = $v.platform;
      _clientVersion = $v.clientVersion;
      _createdAt = $v.createdAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AuthDeviceSummary other) {
    _$v = other as _$AuthDeviceSummary;
  }

  @override
  void update(void Function(AuthDeviceSummaryBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  AuthDeviceSummary build() => _build();

  _$AuthDeviceSummary _build() {
    final _$result =
        _$v ??
        _$AuthDeviceSummary._(
          id: BuiltValueNullFieldError.checkNotNull(
            id,
            r'AuthDeviceSummary',
            'id',
          ),
          name: BuiltValueNullFieldError.checkNotNull(
            name,
            r'AuthDeviceSummary',
            'name',
          ),
          platform: BuiltValueNullFieldError.checkNotNull(
            platform,
            r'AuthDeviceSummary',
            'platform',
          ),
          clientVersion: BuiltValueNullFieldError.checkNotNull(
            clientVersion,
            r'AuthDeviceSummary',
            'clientVersion',
          ),
          createdAt: BuiltValueNullFieldError.checkNotNull(
            createdAt,
            r'AuthDeviceSummary',
            'createdAt',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
