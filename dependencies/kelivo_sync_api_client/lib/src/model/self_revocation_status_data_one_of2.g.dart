// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'self_revocation_status_data_one_of2.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const SelfRevocationStatusDataOneOf2StatusEnum
_$selfRevocationStatusDataOneOf2StatusEnum_cancelled =
    const SelfRevocationStatusDataOneOf2StatusEnum._('cancelled');

SelfRevocationStatusDataOneOf2StatusEnum
_$selfRevocationStatusDataOneOf2StatusEnumValueOf(String name) {
  switch (name) {
    case 'cancelled':
      return _$selfRevocationStatusDataOneOf2StatusEnum_cancelled;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<SelfRevocationStatusDataOneOf2StatusEnum>
_$selfRevocationStatusDataOneOf2StatusEnumValues =
    BuiltSet<SelfRevocationStatusDataOneOf2StatusEnum>(
      const <SelfRevocationStatusDataOneOf2StatusEnum>[
        _$selfRevocationStatusDataOneOf2StatusEnum_cancelled,
      ],
    );

Serializer<SelfRevocationStatusDataOneOf2StatusEnum>
_$selfRevocationStatusDataOneOf2StatusEnumSerializer =
    _$SelfRevocationStatusDataOneOf2StatusEnumSerializer();

class _$SelfRevocationStatusDataOneOf2StatusEnumSerializer
    implements PrimitiveSerializer<SelfRevocationStatusDataOneOf2StatusEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'cancelled': 'cancelled',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'cancelled': 'cancelled',
  };

  @override
  final Iterable<Type> types = const <Type>[
    SelfRevocationStatusDataOneOf2StatusEnum,
  ];
  @override
  final String wireName = 'SelfRevocationStatusDataOneOf2StatusEnum';

  @override
  Object serialize(
    Serializers serializers,
    SelfRevocationStatusDataOneOf2StatusEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  SelfRevocationStatusDataOneOf2StatusEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => SelfRevocationStatusDataOneOf2StatusEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$SelfRevocationStatusDataOneOf2 extends SelfRevocationStatusDataOneOf2 {
  @override
  final SelfRevocationStatusDataOneOf2StatusEnum status;
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
  @override
  final DateTime cancelledAt;

  factory _$SelfRevocationStatusDataOneOf2([
    void Function(SelfRevocationStatusDataOneOf2Builder)? updates,
  ]) => (SelfRevocationStatusDataOneOf2Builder()..update(updates))._build();

  _$SelfRevocationStatusDataOneOf2._({
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
    required this.cancelledAt,
  }) : super._();
  @override
  SelfRevocationStatusDataOneOf2 rebuild(
    void Function(SelfRevocationStatusDataOneOf2Builder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  SelfRevocationStatusDataOneOf2Builder toBuilder() =>
      SelfRevocationStatusDataOneOf2Builder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SelfRevocationStatusDataOneOf2 &&
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
        receiptExpiresAt == other.receiptExpiresAt &&
        cancelledAt == other.cancelledAt;
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
    _$hash = $jc(_$hash, cancelledAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'SelfRevocationStatusDataOneOf2')
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
          ..add('receiptExpiresAt', receiptExpiresAt)
          ..add('cancelledAt', cancelledAt))
        .toString();
  }
}

class SelfRevocationStatusDataOneOf2Builder
    implements
        Builder<
          SelfRevocationStatusDataOneOf2,
          SelfRevocationStatusDataOneOf2Builder
        > {
  _$SelfRevocationStatusDataOneOf2? _$v;

  SelfRevocationStatusDataOneOf2StatusEnum? _status;
  SelfRevocationStatusDataOneOf2StatusEnum? get status => _$this._status;
  set status(SelfRevocationStatusDataOneOf2StatusEnum? status) =>
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

  DateTime? _cancelledAt;
  DateTime? get cancelledAt => _$this._cancelledAt;
  set cancelledAt(DateTime? cancelledAt) => _$this._cancelledAt = cancelledAt;

  SelfRevocationStatusDataOneOf2Builder() {
    SelfRevocationStatusDataOneOf2._defaults(this);
  }

  SelfRevocationStatusDataOneOf2Builder get _$this {
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
      _cancelledAt = $v.cancelledAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SelfRevocationStatusDataOneOf2 other) {
    _$v = other as _$SelfRevocationStatusDataOneOf2;
  }

  @override
  void update(void Function(SelfRevocationStatusDataOneOf2Builder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SelfRevocationStatusDataOneOf2 build() => _build();

  _$SelfRevocationStatusDataOneOf2 _build() {
    final _$result =
        _$v ??
        _$SelfRevocationStatusDataOneOf2._(
          status: BuiltValueNullFieldError.checkNotNull(
            status,
            r'SelfRevocationStatusDataOneOf2',
            'status',
          ),
          deviceId: BuiltValueNullFieldError.checkNotNull(
            deviceId,
            r'SelfRevocationStatusDataOneOf2',
            'deviceId',
          ),
          mutationId: BuiltValueNullFieldError.checkNotNull(
            mutationId,
            r'SelfRevocationStatusDataOneOf2',
            'mutationId',
          ),
          operationId: BuiltValueNullFieldError.checkNotNull(
            operationId,
            r'SelfRevocationStatusDataOneOf2',
            'operationId',
          ),
          expectedGeneration: BuiltValueNullFieldError.checkNotNull(
            expectedGeneration,
            r'SelfRevocationStatusDataOneOf2',
            'expectedGeneration',
          ),
          expectedKeyEpoch: BuiltValueNullFieldError.checkNotNull(
            expectedKeyEpoch,
            r'SelfRevocationStatusDataOneOf2',
            'expectedKeyEpoch',
          ),
          expectedMembershipManifestDigest:
              BuiltValueNullFieldError.checkNotNull(
                expectedMembershipManifestDigest,
                r'SelfRevocationStatusDataOneOf2',
                'expectedMembershipManifestDigest',
              ),
          intentDigest: BuiltValueNullFieldError.checkNotNull(
            intentDigest,
            r'SelfRevocationStatusDataOneOf2',
            'intentDigest',
          ),
          intentSignature: BuiltValueNullFieldError.checkNotNull(
            intentSignature,
            r'SelfRevocationStatusDataOneOf2',
            'intentSignature',
          ),
          requestedAt: BuiltValueNullFieldError.checkNotNull(
            requestedAt,
            r'SelfRevocationStatusDataOneOf2',
            'requestedAt',
          ),
          expiresAt: BuiltValueNullFieldError.checkNotNull(
            expiresAt,
            r'SelfRevocationStatusDataOneOf2',
            'expiresAt',
          ),
          receiptExpiresAt: BuiltValueNullFieldError.checkNotNull(
            receiptExpiresAt,
            r'SelfRevocationStatusDataOneOf2',
            'receiptExpiresAt',
          ),
          cancelledAt: BuiltValueNullFieldError.checkNotNull(
            cancelledAt,
            r'SelfRevocationStatusDataOneOf2',
            'cancelledAt',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
