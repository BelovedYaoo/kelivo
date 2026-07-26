// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_pairing_query_data_one_of.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const DevicePairingQueryDataOneOfStatusEnum
_$devicePairingQueryDataOneOfStatusEnum_pending =
    const DevicePairingQueryDataOneOfStatusEnum._('pending');

DevicePairingQueryDataOneOfStatusEnum
_$devicePairingQueryDataOneOfStatusEnumValueOf(String name) {
  switch (name) {
    case 'pending':
      return _$devicePairingQueryDataOneOfStatusEnum_pending;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<DevicePairingQueryDataOneOfStatusEnum>
_$devicePairingQueryDataOneOfStatusEnumValues =
    BuiltSet<DevicePairingQueryDataOneOfStatusEnum>(
      const <DevicePairingQueryDataOneOfStatusEnum>[
        _$devicePairingQueryDataOneOfStatusEnum_pending,
      ],
    );

Serializer<DevicePairingQueryDataOneOfStatusEnum>
_$devicePairingQueryDataOneOfStatusEnumSerializer =
    _$DevicePairingQueryDataOneOfStatusEnumSerializer();

class _$DevicePairingQueryDataOneOfStatusEnumSerializer
    implements PrimitiveSerializer<DevicePairingQueryDataOneOfStatusEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'pending': 'pending',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'pending': 'pending',
  };

  @override
  final Iterable<Type> types = const <Type>[
    DevicePairingQueryDataOneOfStatusEnum,
  ];
  @override
  final String wireName = 'DevicePairingQueryDataOneOfStatusEnum';

  @override
  Object serialize(
    Serializers serializers,
    DevicePairingQueryDataOneOfStatusEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  DevicePairingQueryDataOneOfStatusEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => DevicePairingQueryDataOneOfStatusEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$DevicePairingQueryDataOneOf extends DevicePairingQueryDataOneOf {
  @override
  final int protocolVersion;
  @override
  final String pairingId;
  @override
  final String accountContextId;
  @override
  final String challenge;
  @override
  final DateTime expiresAt;
  @override
  final DevicePairingCreateDataTargetDevice targetDevice;
  @override
  final DevicePairingQueryDataOneOfStatusEnum status;

  factory _$DevicePairingQueryDataOneOf([
    void Function(DevicePairingQueryDataOneOfBuilder)? updates,
  ]) => (DevicePairingQueryDataOneOfBuilder()..update(updates))._build();

  _$DevicePairingQueryDataOneOf._({
    required this.protocolVersion,
    required this.pairingId,
    required this.accountContextId,
    required this.challenge,
    required this.expiresAt,
    required this.targetDevice,
    required this.status,
  }) : super._();
  @override
  DevicePairingQueryDataOneOf rebuild(
    void Function(DevicePairingQueryDataOneOfBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  DevicePairingQueryDataOneOfBuilder toBuilder() =>
      DevicePairingQueryDataOneOfBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DevicePairingQueryDataOneOf &&
        protocolVersion == other.protocolVersion &&
        pairingId == other.pairingId &&
        accountContextId == other.accountContextId &&
        challenge == other.challenge &&
        expiresAt == other.expiresAt &&
        targetDevice == other.targetDevice &&
        status == other.status;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, protocolVersion.hashCode);
    _$hash = $jc(_$hash, pairingId.hashCode);
    _$hash = $jc(_$hash, accountContextId.hashCode);
    _$hash = $jc(_$hash, challenge.hashCode);
    _$hash = $jc(_$hash, expiresAt.hashCode);
    _$hash = $jc(_$hash, targetDevice.hashCode);
    _$hash = $jc(_$hash, status.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'DevicePairingQueryDataOneOf')
          ..add('protocolVersion', protocolVersion)
          ..add('pairingId', pairingId)
          ..add('accountContextId', accountContextId)
          ..add('challenge', challenge)
          ..add('expiresAt', expiresAt)
          ..add('targetDevice', targetDevice)
          ..add('status', status))
        .toString();
  }
}

class DevicePairingQueryDataOneOfBuilder
    implements
        Builder<
          DevicePairingQueryDataOneOf,
          DevicePairingQueryDataOneOfBuilder
        > {
  _$DevicePairingQueryDataOneOf? _$v;

  int? _protocolVersion;
  int? get protocolVersion => _$this._protocolVersion;
  set protocolVersion(int? protocolVersion) =>
      _$this._protocolVersion = protocolVersion;

  String? _pairingId;
  String? get pairingId => _$this._pairingId;
  set pairingId(String? pairingId) => _$this._pairingId = pairingId;

  String? _accountContextId;
  String? get accountContextId => _$this._accountContextId;
  set accountContextId(String? accountContextId) =>
      _$this._accountContextId = accountContextId;

  String? _challenge;
  String? get challenge => _$this._challenge;
  set challenge(String? challenge) => _$this._challenge = challenge;

  DateTime? _expiresAt;
  DateTime? get expiresAt => _$this._expiresAt;
  set expiresAt(DateTime? expiresAt) => _$this._expiresAt = expiresAt;

  DevicePairingCreateDataTargetDeviceBuilder? _targetDevice;
  DevicePairingCreateDataTargetDeviceBuilder get targetDevice =>
      _$this._targetDevice ??= DevicePairingCreateDataTargetDeviceBuilder();
  set targetDevice(DevicePairingCreateDataTargetDeviceBuilder? targetDevice) =>
      _$this._targetDevice = targetDevice;

  DevicePairingQueryDataOneOfStatusEnum? _status;
  DevicePairingQueryDataOneOfStatusEnum? get status => _$this._status;
  set status(DevicePairingQueryDataOneOfStatusEnum? status) =>
      _$this._status = status;

  DevicePairingQueryDataOneOfBuilder() {
    DevicePairingQueryDataOneOf._defaults(this);
  }

  DevicePairingQueryDataOneOfBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _protocolVersion = $v.protocolVersion;
      _pairingId = $v.pairingId;
      _accountContextId = $v.accountContextId;
      _challenge = $v.challenge;
      _expiresAt = $v.expiresAt;
      _targetDevice = $v.targetDevice.toBuilder();
      _status = $v.status;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DevicePairingQueryDataOneOf other) {
    _$v = other as _$DevicePairingQueryDataOneOf;
  }

  @override
  void update(void Function(DevicePairingQueryDataOneOfBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DevicePairingQueryDataOneOf build() => _build();

  _$DevicePairingQueryDataOneOf _build() {
    _$DevicePairingQueryDataOneOf _$result;
    try {
      _$result =
          _$v ??
          _$DevicePairingQueryDataOneOf._(
            protocolVersion: BuiltValueNullFieldError.checkNotNull(
              protocolVersion,
              r'DevicePairingQueryDataOneOf',
              'protocolVersion',
            ),
            pairingId: BuiltValueNullFieldError.checkNotNull(
              pairingId,
              r'DevicePairingQueryDataOneOf',
              'pairingId',
            ),
            accountContextId: BuiltValueNullFieldError.checkNotNull(
              accountContextId,
              r'DevicePairingQueryDataOneOf',
              'accountContextId',
            ),
            challenge: BuiltValueNullFieldError.checkNotNull(
              challenge,
              r'DevicePairingQueryDataOneOf',
              'challenge',
            ),
            expiresAt: BuiltValueNullFieldError.checkNotNull(
              expiresAt,
              r'DevicePairingQueryDataOneOf',
              'expiresAt',
            ),
            targetDevice: targetDevice.build(),
            status: BuiltValueNullFieldError.checkNotNull(
              status,
              r'DevicePairingQueryDataOneOf',
              'status',
            ),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'targetDevice';
        targetDevice.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'DevicePairingQueryDataOneOf',
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
