// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trusted_device_summary.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const TrustedDeviceSummaryPlatformEnum
_$trustedDeviceSummaryPlatformEnum_android =
    const TrustedDeviceSummaryPlatformEnum._('android');
const TrustedDeviceSummaryPlatformEnum _$trustedDeviceSummaryPlatformEnum_ios =
    const TrustedDeviceSummaryPlatformEnum._('ios');
const TrustedDeviceSummaryPlatformEnum
_$trustedDeviceSummaryPlatformEnum_macos =
    const TrustedDeviceSummaryPlatformEnum._('macos');
const TrustedDeviceSummaryPlatformEnum
_$trustedDeviceSummaryPlatformEnum_windows =
    const TrustedDeviceSummaryPlatformEnum._('windows');
const TrustedDeviceSummaryPlatformEnum
_$trustedDeviceSummaryPlatformEnum_linux =
    const TrustedDeviceSummaryPlatformEnum._('linux');

TrustedDeviceSummaryPlatformEnum _$trustedDeviceSummaryPlatformEnumValueOf(
  String name,
) {
  switch (name) {
    case 'android':
      return _$trustedDeviceSummaryPlatformEnum_android;
    case 'ios':
      return _$trustedDeviceSummaryPlatformEnum_ios;
    case 'macos':
      return _$trustedDeviceSummaryPlatformEnum_macos;
    case 'windows':
      return _$trustedDeviceSummaryPlatformEnum_windows;
    case 'linux':
      return _$trustedDeviceSummaryPlatformEnum_linux;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<TrustedDeviceSummaryPlatformEnum>
_$trustedDeviceSummaryPlatformEnumValues =
    BuiltSet<TrustedDeviceSummaryPlatformEnum>(
      const <TrustedDeviceSummaryPlatformEnum>[
        _$trustedDeviceSummaryPlatformEnum_android,
        _$trustedDeviceSummaryPlatformEnum_ios,
        _$trustedDeviceSummaryPlatformEnum_macos,
        _$trustedDeviceSummaryPlatformEnum_windows,
        _$trustedDeviceSummaryPlatformEnum_linux,
      ],
    );

const TrustedDeviceSummaryStatusEnum _$trustedDeviceSummaryStatusEnum_active =
    const TrustedDeviceSummaryStatusEnum._('active');
const TrustedDeviceSummaryStatusEnum _$trustedDeviceSummaryStatusEnum_revoked =
    const TrustedDeviceSummaryStatusEnum._('revoked');

TrustedDeviceSummaryStatusEnum _$trustedDeviceSummaryStatusEnumValueOf(
  String name,
) {
  switch (name) {
    case 'active':
      return _$trustedDeviceSummaryStatusEnum_active;
    case 'revoked':
      return _$trustedDeviceSummaryStatusEnum_revoked;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<TrustedDeviceSummaryStatusEnum>
_$trustedDeviceSummaryStatusEnumValues =
    BuiltSet<TrustedDeviceSummaryStatusEnum>(
      const <TrustedDeviceSummaryStatusEnum>[
        _$trustedDeviceSummaryStatusEnum_active,
        _$trustedDeviceSummaryStatusEnum_revoked,
      ],
    );

Serializer<TrustedDeviceSummaryPlatformEnum>
_$trustedDeviceSummaryPlatformEnumSerializer =
    _$TrustedDeviceSummaryPlatformEnumSerializer();
Serializer<TrustedDeviceSummaryStatusEnum>
_$trustedDeviceSummaryStatusEnumSerializer =
    _$TrustedDeviceSummaryStatusEnumSerializer();

class _$TrustedDeviceSummaryPlatformEnumSerializer
    implements PrimitiveSerializer<TrustedDeviceSummaryPlatformEnum> {
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
  final Iterable<Type> types = const <Type>[TrustedDeviceSummaryPlatformEnum];
  @override
  final String wireName = 'TrustedDeviceSummaryPlatformEnum';

  @override
  Object serialize(
    Serializers serializers,
    TrustedDeviceSummaryPlatformEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  TrustedDeviceSummaryPlatformEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => TrustedDeviceSummaryPlatformEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$TrustedDeviceSummaryStatusEnumSerializer
    implements PrimitiveSerializer<TrustedDeviceSummaryStatusEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'active': 'active',
    'revoked': 'revoked',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'active': 'active',
    'revoked': 'revoked',
  };

  @override
  final Iterable<Type> types = const <Type>[TrustedDeviceSummaryStatusEnum];
  @override
  final String wireName = 'TrustedDeviceSummaryStatusEnum';

  @override
  Object serialize(
    Serializers serializers,
    TrustedDeviceSummaryStatusEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  TrustedDeviceSummaryStatusEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => TrustedDeviceSummaryStatusEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$TrustedDeviceSummary extends TrustedDeviceSummary {
  @override
  final String id;
  @override
  final String name;
  @override
  final TrustedDeviceSummaryPlatformEnum platform;
  @override
  final String clientVersion;
  @override
  final int authGeneration;
  @override
  final TrustedDeviceSummaryStatusEnum status;
  @override
  final DateTime createdAt;
  @override
  final DateTime? lastSeenAt;
  @override
  final DateTime? revokedAt;
  @override
  final bool isCurrent;

  factory _$TrustedDeviceSummary([
    void Function(TrustedDeviceSummaryBuilder)? updates,
  ]) => (TrustedDeviceSummaryBuilder()..update(updates))._build();

  _$TrustedDeviceSummary._({
    required this.id,
    required this.name,
    required this.platform,
    required this.clientVersion,
    required this.authGeneration,
    required this.status,
    required this.createdAt,
    this.lastSeenAt,
    this.revokedAt,
    required this.isCurrent,
  }) : super._();
  @override
  TrustedDeviceSummary rebuild(
    void Function(TrustedDeviceSummaryBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  TrustedDeviceSummaryBuilder toBuilder() =>
      TrustedDeviceSummaryBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is TrustedDeviceSummary &&
        id == other.id &&
        name == other.name &&
        platform == other.platform &&
        clientVersion == other.clientVersion &&
        authGeneration == other.authGeneration &&
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
    _$hash = $jc(_$hash, authGeneration.hashCode);
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
    return (newBuiltValueToStringHelper(r'TrustedDeviceSummary')
          ..add('id', id)
          ..add('name', name)
          ..add('platform', platform)
          ..add('clientVersion', clientVersion)
          ..add('authGeneration', authGeneration)
          ..add('status', status)
          ..add('createdAt', createdAt)
          ..add('lastSeenAt', lastSeenAt)
          ..add('revokedAt', revokedAt)
          ..add('isCurrent', isCurrent))
        .toString();
  }
}

class TrustedDeviceSummaryBuilder
    implements Builder<TrustedDeviceSummary, TrustedDeviceSummaryBuilder> {
  _$TrustedDeviceSummary? _$v;

  String? _id;
  String? get id => _$this._id;
  set id(String? id) => _$this._id = id;

  String? _name;
  String? get name => _$this._name;
  set name(String? name) => _$this._name = name;

  TrustedDeviceSummaryPlatformEnum? _platform;
  TrustedDeviceSummaryPlatformEnum? get platform => _$this._platform;
  set platform(TrustedDeviceSummaryPlatformEnum? platform) =>
      _$this._platform = platform;

  String? _clientVersion;
  String? get clientVersion => _$this._clientVersion;
  set clientVersion(String? clientVersion) =>
      _$this._clientVersion = clientVersion;

  int? _authGeneration;
  int? get authGeneration => _$this._authGeneration;
  set authGeneration(int? authGeneration) =>
      _$this._authGeneration = authGeneration;

  TrustedDeviceSummaryStatusEnum? _status;
  TrustedDeviceSummaryStatusEnum? get status => _$this._status;
  set status(TrustedDeviceSummaryStatusEnum? status) => _$this._status = status;

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

  TrustedDeviceSummaryBuilder() {
    TrustedDeviceSummary._defaults(this);
  }

  TrustedDeviceSummaryBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _id = $v.id;
      _name = $v.name;
      _platform = $v.platform;
      _clientVersion = $v.clientVersion;
      _authGeneration = $v.authGeneration;
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
  void replace(TrustedDeviceSummary other) {
    _$v = other as _$TrustedDeviceSummary;
  }

  @override
  void update(void Function(TrustedDeviceSummaryBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  TrustedDeviceSummary build() => _build();

  _$TrustedDeviceSummary _build() {
    final _$result =
        _$v ??
        _$TrustedDeviceSummary._(
          id: BuiltValueNullFieldError.checkNotNull(
            id,
            r'TrustedDeviceSummary',
            'id',
          ),
          name: BuiltValueNullFieldError.checkNotNull(
            name,
            r'TrustedDeviceSummary',
            'name',
          ),
          platform: BuiltValueNullFieldError.checkNotNull(
            platform,
            r'TrustedDeviceSummary',
            'platform',
          ),
          clientVersion: BuiltValueNullFieldError.checkNotNull(
            clientVersion,
            r'TrustedDeviceSummary',
            'clientVersion',
          ),
          authGeneration: BuiltValueNullFieldError.checkNotNull(
            authGeneration,
            r'TrustedDeviceSummary',
            'authGeneration',
          ),
          status: BuiltValueNullFieldError.checkNotNull(
            status,
            r'TrustedDeviceSummary',
            'status',
          ),
          createdAt: BuiltValueNullFieldError.checkNotNull(
            createdAt,
            r'TrustedDeviceSummary',
            'createdAt',
          ),
          lastSeenAt: lastSeenAt,
          revokedAt: revokedAt,
          isCurrent: BuiltValueNullFieldError.checkNotNull(
            isCurrent,
            r'TrustedDeviceSummary',
            'isCurrent',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
