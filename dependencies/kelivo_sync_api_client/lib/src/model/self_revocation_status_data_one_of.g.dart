// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'self_revocation_status_data_one_of.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const SelfRevocationStatusDataOneOfStatusEnum
_$selfRevocationStatusDataOneOfStatusEnum_pending =
    const SelfRevocationStatusDataOneOfStatusEnum._('pending');

SelfRevocationStatusDataOneOfStatusEnum
_$selfRevocationStatusDataOneOfStatusEnumValueOf(String name) {
  switch (name) {
    case 'pending':
      return _$selfRevocationStatusDataOneOfStatusEnum_pending;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<SelfRevocationStatusDataOneOfStatusEnum>
_$selfRevocationStatusDataOneOfStatusEnumValues =
    BuiltSet<SelfRevocationStatusDataOneOfStatusEnum>(
      const <SelfRevocationStatusDataOneOfStatusEnum>[
        _$selfRevocationStatusDataOneOfStatusEnum_pending,
      ],
    );

Serializer<SelfRevocationStatusDataOneOfStatusEnum>
_$selfRevocationStatusDataOneOfStatusEnumSerializer =
    _$SelfRevocationStatusDataOneOfStatusEnumSerializer();

class _$SelfRevocationStatusDataOneOfStatusEnumSerializer
    implements PrimitiveSerializer<SelfRevocationStatusDataOneOfStatusEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'pending': 'pending',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'pending': 'pending',
  };

  @override
  final Iterable<Type> types = const <Type>[
    SelfRevocationStatusDataOneOfStatusEnum,
  ];
  @override
  final String wireName = 'SelfRevocationStatusDataOneOfStatusEnum';

  @override
  Object serialize(
    Serializers serializers,
    SelfRevocationStatusDataOneOfStatusEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  SelfRevocationStatusDataOneOfStatusEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => SelfRevocationStatusDataOneOfStatusEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$SelfRevocationStatusDataOneOf extends SelfRevocationStatusDataOneOf {
  @override
  final SelfRevocationStatusDataOneOfStatusEnum status;
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

  factory _$SelfRevocationStatusDataOneOf([
    void Function(SelfRevocationStatusDataOneOfBuilder)? updates,
  ]) => (SelfRevocationStatusDataOneOfBuilder()..update(updates))._build();

  _$SelfRevocationStatusDataOneOf._({
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
  SelfRevocationStatusDataOneOf rebuild(
    void Function(SelfRevocationStatusDataOneOfBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  SelfRevocationStatusDataOneOfBuilder toBuilder() =>
      SelfRevocationStatusDataOneOfBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SelfRevocationStatusDataOneOf &&
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
    return (newBuiltValueToStringHelper(r'SelfRevocationStatusDataOneOf')
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

class SelfRevocationStatusDataOneOfBuilder
    implements
        Builder<
          SelfRevocationStatusDataOneOf,
          SelfRevocationStatusDataOneOfBuilder
        > {
  _$SelfRevocationStatusDataOneOf? _$v;

  SelfRevocationStatusDataOneOfStatusEnum? _status;
  SelfRevocationStatusDataOneOfStatusEnum? get status => _$this._status;
  set status(SelfRevocationStatusDataOneOfStatusEnum? status) =>
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

  SelfRevocationStatusDataOneOfBuilder() {
    SelfRevocationStatusDataOneOf._defaults(this);
  }

  SelfRevocationStatusDataOneOfBuilder get _$this {
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
  void replace(SelfRevocationStatusDataOneOf other) {
    _$v = other as _$SelfRevocationStatusDataOneOf;
  }

  @override
  void update(void Function(SelfRevocationStatusDataOneOfBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SelfRevocationStatusDataOneOf build() => _build();

  _$SelfRevocationStatusDataOneOf _build() {
    final _$result =
        _$v ??
        _$SelfRevocationStatusDataOneOf._(
          status: BuiltValueNullFieldError.checkNotNull(
            status,
            r'SelfRevocationStatusDataOneOf',
            'status',
          ),
          deviceId: BuiltValueNullFieldError.checkNotNull(
            deviceId,
            r'SelfRevocationStatusDataOneOf',
            'deviceId',
          ),
          mutationId: BuiltValueNullFieldError.checkNotNull(
            mutationId,
            r'SelfRevocationStatusDataOneOf',
            'mutationId',
          ),
          operationId: BuiltValueNullFieldError.checkNotNull(
            operationId,
            r'SelfRevocationStatusDataOneOf',
            'operationId',
          ),
          expectedGeneration: BuiltValueNullFieldError.checkNotNull(
            expectedGeneration,
            r'SelfRevocationStatusDataOneOf',
            'expectedGeneration',
          ),
          expectedKeyEpoch: BuiltValueNullFieldError.checkNotNull(
            expectedKeyEpoch,
            r'SelfRevocationStatusDataOneOf',
            'expectedKeyEpoch',
          ),
          expectedMembershipManifestDigest:
              BuiltValueNullFieldError.checkNotNull(
                expectedMembershipManifestDigest,
                r'SelfRevocationStatusDataOneOf',
                'expectedMembershipManifestDigest',
              ),
          intentDigest: BuiltValueNullFieldError.checkNotNull(
            intentDigest,
            r'SelfRevocationStatusDataOneOf',
            'intentDigest',
          ),
          intentSignature: BuiltValueNullFieldError.checkNotNull(
            intentSignature,
            r'SelfRevocationStatusDataOneOf',
            'intentSignature',
          ),
          requestedAt: BuiltValueNullFieldError.checkNotNull(
            requestedAt,
            r'SelfRevocationStatusDataOneOf',
            'requestedAt',
          ),
          expiresAt: BuiltValueNullFieldError.checkNotNull(
            expiresAt,
            r'SelfRevocationStatusDataOneOf',
            'expiresAt',
          ),
          receiptExpiresAt: BuiltValueNullFieldError.checkNotNull(
            receiptExpiresAt,
            r'SelfRevocationStatusDataOneOf',
            'receiptExpiresAt',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
