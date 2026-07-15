// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_session_summary.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const DeviceSessionSummaryPlatformEnum
_$deviceSessionSummaryPlatformEnum_android =
    const DeviceSessionSummaryPlatformEnum._('android');
const DeviceSessionSummaryPlatformEnum _$deviceSessionSummaryPlatformEnum_ios =
    const DeviceSessionSummaryPlatformEnum._('ios');
const DeviceSessionSummaryPlatformEnum
_$deviceSessionSummaryPlatformEnum_macos =
    const DeviceSessionSummaryPlatformEnum._('macos');
const DeviceSessionSummaryPlatformEnum
_$deviceSessionSummaryPlatformEnum_windows =
    const DeviceSessionSummaryPlatformEnum._('windows');
const DeviceSessionSummaryPlatformEnum
_$deviceSessionSummaryPlatformEnum_linux =
    const DeviceSessionSummaryPlatformEnum._('linux');

DeviceSessionSummaryPlatformEnum _$deviceSessionSummaryPlatformEnumValueOf(
  String name,
) {
  switch (name) {
    case 'android':
      return _$deviceSessionSummaryPlatformEnum_android;
    case 'ios':
      return _$deviceSessionSummaryPlatformEnum_ios;
    case 'macos':
      return _$deviceSessionSummaryPlatformEnum_macos;
    case 'windows':
      return _$deviceSessionSummaryPlatformEnum_windows;
    case 'linux':
      return _$deviceSessionSummaryPlatformEnum_linux;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<DeviceSessionSummaryPlatformEnum>
_$deviceSessionSummaryPlatformEnumValues =
    BuiltSet<DeviceSessionSummaryPlatformEnum>(
      const <DeviceSessionSummaryPlatformEnum>[
        _$deviceSessionSummaryPlatformEnum_android,
        _$deviceSessionSummaryPlatformEnum_ios,
        _$deviceSessionSummaryPlatformEnum_macos,
        _$deviceSessionSummaryPlatformEnum_windows,
        _$deviceSessionSummaryPlatformEnum_linux,
      ],
    );

const DeviceSessionSummaryStatusEnum _$deviceSessionSummaryStatusEnum_active =
    const DeviceSessionSummaryStatusEnum._('active');
const DeviceSessionSummaryStatusEnum _$deviceSessionSummaryStatusEnum_revoked =
    const DeviceSessionSummaryStatusEnum._('revoked');

DeviceSessionSummaryStatusEnum _$deviceSessionSummaryStatusEnumValueOf(
  String name,
) {
  switch (name) {
    case 'active':
      return _$deviceSessionSummaryStatusEnum_active;
    case 'revoked':
      return _$deviceSessionSummaryStatusEnum_revoked;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<DeviceSessionSummaryStatusEnum>
_$deviceSessionSummaryStatusEnumValues =
    BuiltSet<DeviceSessionSummaryStatusEnum>(
      const <DeviceSessionSummaryStatusEnum>[
        _$deviceSessionSummaryStatusEnum_active,
        _$deviceSessionSummaryStatusEnum_revoked,
      ],
    );

Serializer<DeviceSessionSummaryPlatformEnum>
_$deviceSessionSummaryPlatformEnumSerializer =
    _$DeviceSessionSummaryPlatformEnumSerializer();
Serializer<DeviceSessionSummaryStatusEnum>
_$deviceSessionSummaryStatusEnumSerializer =
    _$DeviceSessionSummaryStatusEnumSerializer();

class _$DeviceSessionSummaryPlatformEnumSerializer
    implements PrimitiveSerializer<DeviceSessionSummaryPlatformEnum> {
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
  final Iterable<Type> types = const <Type>[DeviceSessionSummaryPlatformEnum];
  @override
  final String wireName = 'DeviceSessionSummaryPlatformEnum';

  @override
  Object serialize(
    Serializers serializers,
    DeviceSessionSummaryPlatformEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  DeviceSessionSummaryPlatformEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => DeviceSessionSummaryPlatformEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$DeviceSessionSummaryStatusEnumSerializer
    implements PrimitiveSerializer<DeviceSessionSummaryStatusEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'active': 'active',
    'revoked': 'revoked',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'active': 'active',
    'revoked': 'revoked',
  };

  @override
  final Iterable<Type> types = const <Type>[DeviceSessionSummaryStatusEnum];
  @override
  final String wireName = 'DeviceSessionSummaryStatusEnum';

  @override
  Object serialize(
    Serializers serializers,
    DeviceSessionSummaryStatusEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  DeviceSessionSummaryStatusEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => DeviceSessionSummaryStatusEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$DeviceSessionSummary extends DeviceSessionSummary {
  @override
  final String id;
  @override
  final String name;
  @override
  final DeviceSessionSummaryPlatformEnum platform;
  @override
  final String clientVersion;
  @override
  final DeviceSessionSummaryStatusEnum status;
  @override
  final DateTime createdAt;
  @override
  final DateTime? lastSeenAt;
  @override
  final DateTime? revokedAt;
  @override
  final bool isCurrent;

  factory _$DeviceSessionSummary([
    void Function(DeviceSessionSummaryBuilder)? updates,
  ]) => (DeviceSessionSummaryBuilder()..update(updates))._build();

  _$DeviceSessionSummary._({
    required this.id,
    required this.name,
    required this.platform,
    required this.clientVersion,
    required this.status,
    required this.createdAt,
    this.lastSeenAt,
    this.revokedAt,
    required this.isCurrent,
  }) : super._();
  @override
  DeviceSessionSummary rebuild(
    void Function(DeviceSessionSummaryBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  DeviceSessionSummaryBuilder toBuilder() =>
      DeviceSessionSummaryBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DeviceSessionSummary &&
        id == other.id &&
        name == other.name &&
        platform == other.platform &&
        clientVersion == other.clientVersion &&
        status == other.status &&
        createdAt == other.createdAt &&
        lastSeenAt == other.lastSeenAt &&
        revokedAt == other.revokedAt &&
        isCurrent == other.isCurrent;
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
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'DeviceSessionSummary')
          ..add('id', id)
          ..add('name', name)
          ..add('platform', platform)
          ..add('clientVersion', clientVersion)
          ..add('status', status)
          ..add('createdAt', createdAt)
          ..add('lastSeenAt', lastSeenAt)
          ..add('revokedAt', revokedAt)
          ..add('isCurrent', isCurrent))
        .toString();
  }
}

class DeviceSessionSummaryBuilder
    implements Builder<DeviceSessionSummary, DeviceSessionSummaryBuilder> {
  _$DeviceSessionSummary? _$v;

  String? _id;
  String? get id => _$this._id;
  set id(String? id) => _$this._id = id;

  String? _name;
  String? get name => _$this._name;
  set name(String? name) => _$this._name = name;

  DeviceSessionSummaryPlatformEnum? _platform;
  DeviceSessionSummaryPlatformEnum? get platform => _$this._platform;
  set platform(DeviceSessionSummaryPlatformEnum? platform) =>
      _$this._platform = platform;

  String? _clientVersion;
  String? get clientVersion => _$this._clientVersion;
  set clientVersion(String? clientVersion) =>
      _$this._clientVersion = clientVersion;

  DeviceSessionSummaryStatusEnum? _status;
  DeviceSessionSummaryStatusEnum? get status => _$this._status;
  set status(DeviceSessionSummaryStatusEnum? status) => _$this._status = status;

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

  DeviceSessionSummaryBuilder() {
    DeviceSessionSummary._defaults(this);
  }

  DeviceSessionSummaryBuilder get _$this {
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
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DeviceSessionSummary other) {
    _$v = other as _$DeviceSessionSummary;
  }

  @override
  void update(void Function(DeviceSessionSummaryBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DeviceSessionSummary build() => _build();

  _$DeviceSessionSummary _build() {
    final _$result =
        _$v ??
        _$DeviceSessionSummary._(
          id: BuiltValueNullFieldError.checkNotNull(
            id,
            r'DeviceSessionSummary',
            'id',
          ),
          name: BuiltValueNullFieldError.checkNotNull(
            name,
            r'DeviceSessionSummary',
            'name',
          ),
          platform: BuiltValueNullFieldError.checkNotNull(
            platform,
            r'DeviceSessionSummary',
            'platform',
          ),
          clientVersion: BuiltValueNullFieldError.checkNotNull(
            clientVersion,
            r'DeviceSessionSummary',
            'clientVersion',
          ),
          status: BuiltValueNullFieldError.checkNotNull(
            status,
            r'DeviceSessionSummary',
            'status',
          ),
          createdAt: BuiltValueNullFieldError.checkNotNull(
            createdAt,
            r'DeviceSessionSummary',
            'createdAt',
          ),
          lastSeenAt: lastSeenAt,
          revokedAt: revokedAt,
          isCurrent: BuiltValueNullFieldError.checkNotNull(
            isCurrent,
            r'DeviceSessionSummary',
            'isCurrent',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
