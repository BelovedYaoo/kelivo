// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'admin_device_summary.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const AdminDeviceSummaryPlatformEnum _$adminDeviceSummaryPlatformEnum_android =
    const AdminDeviceSummaryPlatformEnum._('android');
const AdminDeviceSummaryPlatformEnum _$adminDeviceSummaryPlatformEnum_ios =
    const AdminDeviceSummaryPlatformEnum._('ios');
const AdminDeviceSummaryPlatformEnum _$adminDeviceSummaryPlatformEnum_macos =
    const AdminDeviceSummaryPlatformEnum._('macos');
const AdminDeviceSummaryPlatformEnum _$adminDeviceSummaryPlatformEnum_windows =
    const AdminDeviceSummaryPlatformEnum._('windows');
const AdminDeviceSummaryPlatformEnum _$adminDeviceSummaryPlatformEnum_linux =
    const AdminDeviceSummaryPlatformEnum._('linux');

AdminDeviceSummaryPlatformEnum _$adminDeviceSummaryPlatformEnumValueOf(
  String name,
) {
  switch (name) {
    case 'android':
      return _$adminDeviceSummaryPlatformEnum_android;
    case 'ios':
      return _$adminDeviceSummaryPlatformEnum_ios;
    case 'macos':
      return _$adminDeviceSummaryPlatformEnum_macos;
    case 'windows':
      return _$adminDeviceSummaryPlatformEnum_windows;
    case 'linux':
      return _$adminDeviceSummaryPlatformEnum_linux;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<AdminDeviceSummaryPlatformEnum>
_$adminDeviceSummaryPlatformEnumValues =
    BuiltSet<AdminDeviceSummaryPlatformEnum>(
      const <AdminDeviceSummaryPlatformEnum>[
        _$adminDeviceSummaryPlatformEnum_android,
        _$adminDeviceSummaryPlatformEnum_ios,
        _$adminDeviceSummaryPlatformEnum_macos,
        _$adminDeviceSummaryPlatformEnum_windows,
        _$adminDeviceSummaryPlatformEnum_linux,
      ],
    );

const AdminDeviceSummaryStatusEnum _$adminDeviceSummaryStatusEnum_active =
    const AdminDeviceSummaryStatusEnum._('active');
const AdminDeviceSummaryStatusEnum _$adminDeviceSummaryStatusEnum_revoked =
    const AdminDeviceSummaryStatusEnum._('revoked');

AdminDeviceSummaryStatusEnum _$adminDeviceSummaryStatusEnumValueOf(
  String name,
) {
  switch (name) {
    case 'active':
      return _$adminDeviceSummaryStatusEnum_active;
    case 'revoked':
      return _$adminDeviceSummaryStatusEnum_revoked;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<AdminDeviceSummaryStatusEnum>
_$adminDeviceSummaryStatusEnumValues = BuiltSet<AdminDeviceSummaryStatusEnum>(
  const <AdminDeviceSummaryStatusEnum>[
    _$adminDeviceSummaryStatusEnum_active,
    _$adminDeviceSummaryStatusEnum_revoked,
  ],
);

Serializer<AdminDeviceSummaryPlatformEnum>
_$adminDeviceSummaryPlatformEnumSerializer =
    _$AdminDeviceSummaryPlatformEnumSerializer();
Serializer<AdminDeviceSummaryStatusEnum>
_$adminDeviceSummaryStatusEnumSerializer =
    _$AdminDeviceSummaryStatusEnumSerializer();

class _$AdminDeviceSummaryPlatformEnumSerializer
    implements PrimitiveSerializer<AdminDeviceSummaryPlatformEnum> {
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
  final Iterable<Type> types = const <Type>[AdminDeviceSummaryPlatformEnum];
  @override
  final String wireName = 'AdminDeviceSummaryPlatformEnum';

  @override
  Object serialize(
    Serializers serializers,
    AdminDeviceSummaryPlatformEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  AdminDeviceSummaryPlatformEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => AdminDeviceSummaryPlatformEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$AdminDeviceSummaryStatusEnumSerializer
    implements PrimitiveSerializer<AdminDeviceSummaryStatusEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'active': 'active',
    'revoked': 'revoked',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'active': 'active',
    'revoked': 'revoked',
  };

  @override
  final Iterable<Type> types = const <Type>[AdminDeviceSummaryStatusEnum];
  @override
  final String wireName = 'AdminDeviceSummaryStatusEnum';

  @override
  Object serialize(
    Serializers serializers,
    AdminDeviceSummaryStatusEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  AdminDeviceSummaryStatusEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => AdminDeviceSummaryStatusEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$AdminDeviceSummary extends AdminDeviceSummary {
  @override
  final String id;
  @override
  final String name;
  @override
  final AdminDeviceSummaryPlatformEnum platform;
  @override
  final String clientVersion;
  @override
  final AdminDeviceSummaryStatusEnum status;
  @override
  final DateTime createdAt;
  @override
  final DateTime? lastSeenAt;
  @override
  final DateTime? revokedAt;
  @override
  final bool isCurrent;
  @override
  final AdminDeviceUserSummary user;

  factory _$AdminDeviceSummary([
    void Function(AdminDeviceSummaryBuilder)? updates,
  ]) => (AdminDeviceSummaryBuilder()..update(updates))._build();

  _$AdminDeviceSummary._({
    required this.id,
    required this.name,
    required this.platform,
    required this.clientVersion,
    required this.status,
    required this.createdAt,
    this.lastSeenAt,
    this.revokedAt,
    required this.isCurrent,
    required this.user,
  }) : super._();
  @override
  AdminDeviceSummary rebuild(
    void Function(AdminDeviceSummaryBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  AdminDeviceSummaryBuilder toBuilder() =>
      AdminDeviceSummaryBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AdminDeviceSummary &&
        id == other.id &&
        name == other.name &&
        platform == other.platform &&
        clientVersion == other.clientVersion &&
        status == other.status &&
        createdAt == other.createdAt &&
        lastSeenAt == other.lastSeenAt &&
        revokedAt == other.revokedAt &&
        isCurrent == other.isCurrent &&
        user == other.user;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jc(_$hash, name.hashCode);
    _$hash = $jc(_$hash, platform.hashCode);
    _$hash = $jc(_$hash, clientVersion.hashCode);
    _$hash = $jc(_$hash, status.hashCode);
    _$hash = $jc(_$hash, createdAt.hashCode);
    _$hash = $jc(_$hash, lastSeenAt.hashCode);
    _$hash = $jc(_$hash, revokedAt.hashCode);
    _$hash = $jc(_$hash, isCurrent.hashCode);
    _$hash = $jc(_$hash, user.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'AdminDeviceSummary')
          ..add('id', id)
          ..add('name', name)
          ..add('platform', platform)
          ..add('clientVersion', clientVersion)
          ..add('status', status)
          ..add('createdAt', createdAt)
          ..add('lastSeenAt', lastSeenAt)
          ..add('revokedAt', revokedAt)
          ..add('isCurrent', isCurrent)
          ..add('user', user))
        .toString();
  }
}

class AdminDeviceSummaryBuilder
    implements Builder<AdminDeviceSummary, AdminDeviceSummaryBuilder> {
  _$AdminDeviceSummary? _$v;

  String? _id;
  String? get id => _$this._id;
  set id(String? id) => _$this._id = id;

  String? _name;
  String? get name => _$this._name;
  set name(String? name) => _$this._name = name;

  AdminDeviceSummaryPlatformEnum? _platform;
  AdminDeviceSummaryPlatformEnum? get platform => _$this._platform;
  set platform(AdminDeviceSummaryPlatformEnum? platform) =>
      _$this._platform = platform;

  String? _clientVersion;
  String? get clientVersion => _$this._clientVersion;
  set clientVersion(String? clientVersion) =>
      _$this._clientVersion = clientVersion;

  AdminDeviceSummaryStatusEnum? _status;
  AdminDeviceSummaryStatusEnum? get status => _$this._status;
  set status(AdminDeviceSummaryStatusEnum? status) => _$this._status = status;

  DateTime? _createdAt;
  DateTime? get createdAt => _$this._createdAt;
  set createdAt(DateTime? createdAt) => _$this._createdAt = createdAt;

  DateTime? _lastSeenAt;
  DateTime? get lastSeenAt => _$this._lastSeenAt;
  set lastSeenAt(DateTime? lastSeenAt) => _$this._lastSeenAt = lastSeenAt;

  DateTime? _revokedAt;
  DateTime? get revokedAt => _$this._revokedAt;
  set revokedAt(DateTime? revokedAt) => _$this._revokedAt = revokedAt;

  bool? _isCurrent;
  bool? get isCurrent => _$this._isCurrent;
  set isCurrent(bool? isCurrent) => _$this._isCurrent = isCurrent;

  AdminDeviceUserSummaryBuilder? _user;
  AdminDeviceUserSummaryBuilder get user =>
      _$this._user ??= AdminDeviceUserSummaryBuilder();
  set user(AdminDeviceUserSummaryBuilder? user) => _$this._user = user;

  AdminDeviceSummaryBuilder() {
    AdminDeviceSummary._defaults(this);
  }

  AdminDeviceSummaryBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _id = $v.id;
      _name = $v.name;
      _platform = $v.platform;
      _clientVersion = $v.clientVersion;
      _status = $v.status;
      _createdAt = $v.createdAt;
      _lastSeenAt = $v.lastSeenAt;
      _revokedAt = $v.revokedAt;
      _isCurrent = $v.isCurrent;
      _user = $v.user.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AdminDeviceSummary other) {
    _$v = other as _$AdminDeviceSummary;
  }

  @override
  void update(void Function(AdminDeviceSummaryBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  AdminDeviceSummary build() => _build();

  _$AdminDeviceSummary _build() {
    _$AdminDeviceSummary _$result;
    try {
      _$result =
          _$v ??
          _$AdminDeviceSummary._(
            id: BuiltValueNullFieldError.checkNotNull(
              id,
              r'AdminDeviceSummary',
              'id',
            ),
            name: BuiltValueNullFieldError.checkNotNull(
              name,
              r'AdminDeviceSummary',
              'name',
            ),
            platform: BuiltValueNullFieldError.checkNotNull(
              platform,
              r'AdminDeviceSummary',
              'platform',
            ),
            clientVersion: BuiltValueNullFieldError.checkNotNull(
              clientVersion,
              r'AdminDeviceSummary',
              'clientVersion',
            ),
            status: BuiltValueNullFieldError.checkNotNull(
              status,
              r'AdminDeviceSummary',
              'status',
            ),
            createdAt: BuiltValueNullFieldError.checkNotNull(
              createdAt,
              r'AdminDeviceSummary',
              'createdAt',
            ),
            lastSeenAt: lastSeenAt,
            revokedAt: revokedAt,
            isCurrent: BuiltValueNullFieldError.checkNotNull(
              isCurrent,
              r'AdminDeviceSummary',
              'isCurrent',
            ),
            user: user.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'user';
        user.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'AdminDeviceSummary',
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
