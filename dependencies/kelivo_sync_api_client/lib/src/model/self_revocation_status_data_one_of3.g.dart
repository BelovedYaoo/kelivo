// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'self_revocation_status_data_one_of3.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const SelfRevocationStatusDataOneOf3StatusEnum
_$selfRevocationStatusDataOneOf3StatusEnum_expired =
    const SelfRevocationStatusDataOneOf3StatusEnum._('expired');

SelfRevocationStatusDataOneOf3StatusEnum
_$selfRevocationStatusDataOneOf3StatusEnumValueOf(String name) {
  switch (name) {
    case 'expired':
      return _$selfRevocationStatusDataOneOf3StatusEnum_expired;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<SelfRevocationStatusDataOneOf3StatusEnum>
_$selfRevocationStatusDataOneOf3StatusEnumValues =
    BuiltSet<SelfRevocationStatusDataOneOf3StatusEnum>(
      const <SelfRevocationStatusDataOneOf3StatusEnum>[
        _$selfRevocationStatusDataOneOf3StatusEnum_expired,
      ],
    );

Serializer<SelfRevocationStatusDataOneOf3StatusEnum>
_$selfRevocationStatusDataOneOf3StatusEnumSerializer =
    _$SelfRevocationStatusDataOneOf3StatusEnumSerializer();

class _$SelfRevocationStatusDataOneOf3StatusEnumSerializer
    implements PrimitiveSerializer<SelfRevocationStatusDataOneOf3StatusEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'expired': 'expired',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'expired': 'expired',
  };

  @override
  final Iterable<Type> types = const <Type>[
    SelfRevocationStatusDataOneOf3StatusEnum,
  ];
  @override
  final String wireName = 'SelfRevocationStatusDataOneOf3StatusEnum';

  @override
  Object serialize(
    Serializers serializers,
    SelfRevocationStatusDataOneOf3StatusEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  SelfRevocationStatusDataOneOf3StatusEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => SelfRevocationStatusDataOneOf3StatusEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$SelfRevocationStatusDataOneOf3 extends SelfRevocationStatusDataOneOf3 {
  @override
  final SelfRevocationStatusDataOneOf3StatusEnum status;
  @override
  final String deviceId;
  @override
  final String mutationId;
  @override
  final String operationId;
  @override
  final int expectedGeneration;
  @override
  final int expectedKeyEpoch;
  @override
  final String expectedMembershipManifestDigest;
  @override
  final String intentDigest;
  @override
  final String intentSignature;
  @override
  final DateTime requestedAt;
  @override
  final DateTime expiresAt;
  @override
  final DateTime receiptExpiresAt;

  factory _$SelfRevocationStatusDataOneOf3([
    void Function(SelfRevocationStatusDataOneOf3Builder)? updates,
  ]) => (SelfRevocationStatusDataOneOf3Builder()..update(updates))._build();

  _$SelfRevocationStatusDataOneOf3._({
    required this.status,
    required this.deviceId,
    required this.mutationId,
    required this.operationId,
    required this.expectedGeneration,
    required this.expectedKeyEpoch,
    required this.expectedMembershipManifestDigest,
    required this.intentDigest,
    required this.intentSignature,
    required this.requestedAt,
    required this.expiresAt,
    required this.receiptExpiresAt,
  }) : super._();
  @override
  SelfRevocationStatusDataOneOf3 rebuild(
    void Function(SelfRevocationStatusDataOneOf3Builder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  SelfRevocationStatusDataOneOf3Builder toBuilder() =>
      SelfRevocationStatusDataOneOf3Builder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SelfRevocationStatusDataOneOf3 &&
        status == other.status &&
        deviceId == other.deviceId &&
        mutationId == other.mutationId &&
        operationId == other.operationId &&
        expectedGeneration == other.expectedGeneration &&
        expectedKeyEpoch == other.expectedKeyEpoch &&
        expectedMembershipManifestDigest ==
            other.expectedMembershipManifestDigest &&
        intentDigest == other.intentDigest &&
        intentSignature == other.intentSignature &&
        requestedAt == other.requestedAt &&
        expiresAt == other.expiresAt &&
        receiptExpiresAt == other.receiptExpiresAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, status.hashCode);
    _$hash = $jc(_$hash, deviceId.hashCode);
    _$hash = $jc(_$hash, mutationId.hashCode);
    _$hash = $jc(_$hash, operationId.hashCode);
    _$hash = $jc(_$hash, expectedGeneration.hashCode);
    _$hash = $jc(_$hash, expectedKeyEpoch.hashCode);
    _$hash = $jc(_$hash, expectedMembershipManifestDigest.hashCode);
    _$hash = $jc(_$hash, intentDigest.hashCode);
    _$hash = $jc(_$hash, intentSignature.hashCode);
    _$hash = $jc(_$hash, requestedAt.hashCode);
    _$hash = $jc(_$hash, expiresAt.hashCode);
    _$hash = $jc(_$hash, receiptExpiresAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'SelfRevocationStatusDataOneOf3')
          ..add('status', status)
          ..add('deviceId', deviceId)
          ..add('mutationId', mutationId)
          ..add('operationId', operationId)
          ..add('expectedGeneration', expectedGeneration)
          ..add('expectedKeyEpoch', expectedKeyEpoch)
          ..add(
            'expectedMembershipManifestDigest',
            expectedMembershipManifestDigest,
          )
          ..add('intentDigest', intentDigest)
          ..add('intentSignature', intentSignature)
          ..add('requestedAt', requestedAt)
          ..add('expiresAt', expiresAt)
          ..add('receiptExpiresAt', receiptExpiresAt))
        .toString();
  }
}

class SelfRevocationStatusDataOneOf3Builder
    implements
        Builder<
          SelfRevocationStatusDataOneOf3,
          SelfRevocationStatusDataOneOf3Builder
        > {
  _$SelfRevocationStatusDataOneOf3? _$v;

  SelfRevocationStatusDataOneOf3StatusEnum? _status;
  SelfRevocationStatusDataOneOf3StatusEnum? get status => _$this._status;
  set status(SelfRevocationStatusDataOneOf3StatusEnum? status) =>
      _$this._status = status;

  String? _deviceId;
  String? get deviceId => _$this._deviceId;
  set deviceId(String? deviceId) => _$this._deviceId = deviceId;

  String? _mutationId;
  String? get mutationId => _$this._mutationId;
  set mutationId(String? mutationId) => _$this._mutationId = mutationId;

  String? _operationId;
  String? get operationId => _$this._operationId;
  set operationId(String? operationId) => _$this._operationId = operationId;

  int? _expectedGeneration;
  int? get expectedGeneration => _$this._expectedGeneration;
  set expectedGeneration(int? expectedGeneration) =>
      _$this._expectedGeneration = expectedGeneration;

  int? _expectedKeyEpoch;
  int? get expectedKeyEpoch => _$this._expectedKeyEpoch;
  set expectedKeyEpoch(int? expectedKeyEpoch) =>
      _$this._expectedKeyEpoch = expectedKeyEpoch;

  String? _expectedMembershipManifestDigest;
  String? get expectedMembershipManifestDigest =>
      _$this._expectedMembershipManifestDigest;
  set expectedMembershipManifestDigest(
    String? expectedMembershipManifestDigest,
  ) => _$this._expectedMembershipManifestDigest =
      expectedMembershipManifestDigest;

  String? _intentDigest;
  String? get intentDigest => _$this._intentDigest;
  set intentDigest(String? intentDigest) => _$this._intentDigest = intentDigest;

  String? _intentSignature;
  String? get intentSignature => _$this._intentSignature;
  set intentSignature(String? intentSignature) =>
      _$this._intentSignature = intentSignature;

  DateTime? _requestedAt;
  DateTime? get requestedAt => _$this._requestedAt;
  set requestedAt(DateTime? requestedAt) => _$this._requestedAt = requestedAt;

  DateTime? _expiresAt;
  DateTime? get expiresAt => _$this._expiresAt;
  set expiresAt(DateTime? expiresAt) => _$this._expiresAt = expiresAt;

  DateTime? _receiptExpiresAt;
  DateTime? get receiptExpiresAt => _$this._receiptExpiresAt;
  set receiptExpiresAt(DateTime? receiptExpiresAt) =>
      _$this._receiptExpiresAt = receiptExpiresAt;

  SelfRevocationStatusDataOneOf3Builder() {
    SelfRevocationStatusDataOneOf3._defaults(this);
  }

  SelfRevocationStatusDataOneOf3Builder get _$this {
    final $v = _$v;
    if ($v != null) {
      _status = $v.status;
      _deviceId = $v.deviceId;
      _mutationId = $v.mutationId;
      _operationId = $v.operationId;
      _expectedGeneration = $v.expectedGeneration;
      _expectedKeyEpoch = $v.expectedKeyEpoch;
      _expectedMembershipManifestDigest = $v.expectedMembershipManifestDigest;
      _intentDigest = $v.intentDigest;
      _intentSignature = $v.intentSignature;
      _requestedAt = $v.requestedAt;
      _expiresAt = $v.expiresAt;
      _receiptExpiresAt = $v.receiptExpiresAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SelfRevocationStatusDataOneOf3 other) {
    _$v = other as _$SelfRevocationStatusDataOneOf3;
  }

  @override
  void update(void Function(SelfRevocationStatusDataOneOf3Builder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SelfRevocationStatusDataOneOf3 build() => _build();

  _$SelfRevocationStatusDataOneOf3 _build() {
    final _$result =
        _$v ??
        _$SelfRevocationStatusDataOneOf3._(
          status: BuiltValueNullFieldError.checkNotNull(
            status,
            r'SelfRevocationStatusDataOneOf3',
            'status',
          ),
          deviceId: BuiltValueNullFieldError.checkNotNull(
            deviceId,
            r'SelfRevocationStatusDataOneOf3',
            'deviceId',
          ),
          mutationId: BuiltValueNullFieldError.checkNotNull(
            mutationId,
            r'SelfRevocationStatusDataOneOf3',
            'mutationId',
          ),
          operationId: BuiltValueNullFieldError.checkNotNull(
            operationId,
            r'SelfRevocationStatusDataOneOf3',
            'operationId',
          ),
          expectedGeneration: BuiltValueNullFieldError.checkNotNull(
            expectedGeneration,
            r'SelfRevocationStatusDataOneOf3',
            'expectedGeneration',
          ),
          expectedKeyEpoch: BuiltValueNullFieldError.checkNotNull(
            expectedKeyEpoch,
            r'SelfRevocationStatusDataOneOf3',
            'expectedKeyEpoch',
          ),
          expectedMembershipManifestDigest:
              BuiltValueNullFieldError.checkNotNull(
                expectedMembershipManifestDigest,
                r'SelfRevocationStatusDataOneOf3',
                'expectedMembershipManifestDigest',
              ),
          intentDigest: BuiltValueNullFieldError.checkNotNull(
            intentDigest,
            r'SelfRevocationStatusDataOneOf3',
            'intentDigest',
          ),
          intentSignature: BuiltValueNullFieldError.checkNotNull(
            intentSignature,
            r'SelfRevocationStatusDataOneOf3',
            'intentSignature',
          ),
          requestedAt: BuiltValueNullFieldError.checkNotNull(
            requestedAt,
            r'SelfRevocationStatusDataOneOf3',
            'requestedAt',
          ),
          expiresAt: BuiltValueNullFieldError.checkNotNull(
            expiresAt,
            r'SelfRevocationStatusDataOneOf3',
            'expiresAt',
          ),
          receiptExpiresAt: BuiltValueNullFieldError.checkNotNull(
            receiptExpiresAt,
            r'SelfRevocationStatusDataOneOf3',
            'receiptExpiresAt',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
