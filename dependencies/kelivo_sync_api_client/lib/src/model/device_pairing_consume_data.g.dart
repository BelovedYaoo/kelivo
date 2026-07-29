// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_pairing_consume_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const DevicePairingConsumeDataResultEnum
_$devicePairingConsumeDataResultEnum_authenticated =
    const DevicePairingConsumeDataResultEnum._('authenticated');

DevicePairingConsumeDataResultEnum _$devicePairingConsumeDataResultEnumValueOf(
  String name,
) {
  switch (name) {
    case 'authenticated':
      return _$devicePairingConsumeDataResultEnum_authenticated;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<DevicePairingConsumeDataResultEnum>
_$devicePairingConsumeDataResultEnumValues =
    BuiltSet<DevicePairingConsumeDataResultEnum>(
      const <DevicePairingConsumeDataResultEnum>[
        _$devicePairingConsumeDataResultEnum_authenticated,
      ],
    );

Serializer<DevicePairingConsumeDataResultEnum>
_$devicePairingConsumeDataResultEnumSerializer =
    _$DevicePairingConsumeDataResultEnumSerializer();

class _$DevicePairingConsumeDataResultEnumSerializer
    implements PrimitiveSerializer<DevicePairingConsumeDataResultEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'authenticated': 'authenticated',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'authenticated': 'authenticated',
  };

  @override
  final Iterable<Type> types = const <Type>[DevicePairingConsumeDataResultEnum];
  @override
  final String wireName = 'DevicePairingConsumeDataResultEnum';

  @override
  Object serialize(
    Serializers serializers,
    DevicePairingConsumeDataResultEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  DevicePairingConsumeDataResultEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => DevicePairingConsumeDataResultEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$DevicePairingConsumeData extends DevicePairingConsumeData {
  @override
  final int protocolVersion;
  @override
  final DevicePairingConsumeDataResultEnum result;
  @override
  final int keyEpoch;
  @override
  final int securityGeneration;
  @override
  final String membershipManifestDigest;
  @override
  final String token;
  @override
  final DateTime tokenExpiresAt;
  @override
  final OpaqueRegistrationFinishDataUser user;
  @override
  final OpaqueRegistrationFinishDataDevice device;

  factory _$DevicePairingConsumeData([
    void Function(DevicePairingConsumeDataBuilder)? updates,
  ]) => (DevicePairingConsumeDataBuilder()..update(updates))._build();

  _$DevicePairingConsumeData._({
    required this.protocolVersion,
    required this.result,
    required this.keyEpoch,
    required this.securityGeneration,
    required this.membershipManifestDigest,
    required this.token,
    required this.tokenExpiresAt,
    required this.user,
    required this.device,
  }) : super._();
  @override
  DevicePairingConsumeData rebuild(
    void Function(DevicePairingConsumeDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  DevicePairingConsumeDataBuilder toBuilder() =>
      DevicePairingConsumeDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DevicePairingConsumeData &&
        protocolVersion == other.protocolVersion &&
        result == other.result &&
        keyEpoch == other.keyEpoch &&
        securityGeneration == other.securityGeneration &&
        membershipManifestDigest == other.membershipManifestDigest &&
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
    _$hash = $jc(_$hash, securityGeneration.hashCode);
    _$hash = $jc(_$hash, membershipManifestDigest.hashCode);
    _$hash = $jc(_$hash, token.hashCode);
    _$hash = $jc(_$hash, tokenExpiresAt.hashCode);
    _$hash = $jc(_$hash, user.hashCode);
    _$hash = $jc(_$hash, device.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'DevicePairingConsumeData')
          ..add('protocolVersion', protocolVersion)
          ..add('result', result)
          ..add('keyEpoch', keyEpoch)
          ..add('securityGeneration', securityGeneration)
          ..add('membershipManifestDigest', membershipManifestDigest)
          ..add('token', token)
          ..add('tokenExpiresAt', tokenExpiresAt)
          ..add('user', user)
          ..add('device', device))
        .toString();
  }
}

class DevicePairingConsumeDataBuilder
    implements
        Builder<DevicePairingConsumeData, DevicePairingConsumeDataBuilder> {
  _$DevicePairingConsumeData? _$v;

  int? _protocolVersion;
  int? get protocolVersion => _$this._protocolVersion;
  set protocolVersion(int? protocolVersion) =>
      _$this._protocolVersion = protocolVersion;

  DevicePairingConsumeDataResultEnum? _result;
  DevicePairingConsumeDataResultEnum? get result => _$this._result;
  set result(DevicePairingConsumeDataResultEnum? result) =>
      _$this._result = result;

  int? _keyEpoch;
  int? get keyEpoch => _$this._keyEpoch;
  set keyEpoch(int? keyEpoch) => _$this._keyEpoch = keyEpoch;

  int? _securityGeneration;
  int? get securityGeneration => _$this._securityGeneration;
  set securityGeneration(int? securityGeneration) =>
      _$this._securityGeneration = securityGeneration;

  String? _membershipManifestDigest;
  String? get membershipManifestDigest => _$this._membershipManifestDigest;
  set membershipManifestDigest(String? membershipManifestDigest) =>
      _$this._membershipManifestDigest = membershipManifestDigest;

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

  DevicePairingConsumeDataBuilder() {
    DevicePairingConsumeData._defaults(this);
  }

  DevicePairingConsumeDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _protocolVersion = $v.protocolVersion;
      _result = $v.result;
      _keyEpoch = $v.keyEpoch;
      _securityGeneration = $v.securityGeneration;
      _membershipManifestDigest = $v.membershipManifestDigest;
      _token = $v.token;
      _tokenExpiresAt = $v.tokenExpiresAt;
      _user = $v.user.toBuilder();
      _device = $v.device.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DevicePairingConsumeData other) {
    _$v = other as _$DevicePairingConsumeData;
  }

  @override
  void update(void Function(DevicePairingConsumeDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DevicePairingConsumeData build() => _build();

  _$DevicePairingConsumeData _build() {
    _$DevicePairingConsumeData _$result;
    try {
      _$result =
          _$v ??
          _$DevicePairingConsumeData._(
            protocolVersion: BuiltValueNullFieldError.checkNotNull(
              protocolVersion,
              r'DevicePairingConsumeData',
              'protocolVersion',
            ),
            result: BuiltValueNullFieldError.checkNotNull(
              result,
              r'DevicePairingConsumeData',
              'result',
            ),
            keyEpoch: BuiltValueNullFieldError.checkNotNull(
              keyEpoch,
              r'DevicePairingConsumeData',
              'keyEpoch',
            ),
            securityGeneration: BuiltValueNullFieldError.checkNotNull(
              securityGeneration,
              r'DevicePairingConsumeData',
              'securityGeneration',
            ),
            membershipManifestDigest: BuiltValueNullFieldError.checkNotNull(
              membershipManifestDigest,
              r'DevicePairingConsumeData',
              'membershipManifestDigest',
            ),
            token: BuiltValueNullFieldError.checkNotNull(
              token,
              r'DevicePairingConsumeData',
              'token',
            ),
            tokenExpiresAt: BuiltValueNullFieldError.checkNotNull(
              tokenExpiresAt,
              r'DevicePairingConsumeData',
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
          r'DevicePairingConsumeData',
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
