// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'self_revocation_status_data_one_of1.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const SelfRevocationStatusDataOneOf1StatusEnum
_$selfRevocationStatusDataOneOf1StatusEnum_confirmed =
    const SelfRevocationStatusDataOneOf1StatusEnum._('confirmed');

SelfRevocationStatusDataOneOf1StatusEnum
_$selfRevocationStatusDataOneOf1StatusEnumValueOf(String name) {
  switch (name) {
    case 'confirmed':
      return _$selfRevocationStatusDataOneOf1StatusEnum_confirmed;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<SelfRevocationStatusDataOneOf1StatusEnum>
_$selfRevocationStatusDataOneOf1StatusEnumValues =
    BuiltSet<SelfRevocationStatusDataOneOf1StatusEnum>(
      const <SelfRevocationStatusDataOneOf1StatusEnum>[
        _$selfRevocationStatusDataOneOf1StatusEnum_confirmed,
      ],
    );

Serializer<SelfRevocationStatusDataOneOf1StatusEnum>
_$selfRevocationStatusDataOneOf1StatusEnumSerializer =
    _$SelfRevocationStatusDataOneOf1StatusEnumSerializer();

class _$SelfRevocationStatusDataOneOf1StatusEnumSerializer
    implements PrimitiveSerializer<SelfRevocationStatusDataOneOf1StatusEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'confirmed': 'confirmed',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'confirmed': 'confirmed',
  };

  @override
  final Iterable<Type> types = const <Type>[
    SelfRevocationStatusDataOneOf1StatusEnum,
  ];
  @override
  final String wireName = 'SelfRevocationStatusDataOneOf1StatusEnum';

  @override
  Object serialize(
    Serializers serializers,
    SelfRevocationStatusDataOneOf1StatusEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  SelfRevocationStatusDataOneOf1StatusEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => SelfRevocationStatusDataOneOf1StatusEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$SelfRevocationStatusDataOneOf1 extends SelfRevocationStatusDataOneOf1 {
  @override
  final SelfRevocationStatusDataOneOf1StatusEnum status;
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
  final SelfRevocationStatusDataOneOf1Receipt receipt;

  factory _$SelfRevocationStatusDataOneOf1([
    void Function(SelfRevocationStatusDataOneOf1Builder)? updates,
  ]) => (SelfRevocationStatusDataOneOf1Builder()..update(updates))._build();

  _$SelfRevocationStatusDataOneOf1._({
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
    required this.receipt,
  }) : super._();
  @override
  SelfRevocationStatusDataOneOf1 rebuild(
    void Function(SelfRevocationStatusDataOneOf1Builder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  SelfRevocationStatusDataOneOf1Builder toBuilder() =>
      SelfRevocationStatusDataOneOf1Builder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SelfRevocationStatusDataOneOf1 &&
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
        receipt == other.receipt;
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
    _$hash = $jc(_$hash, receipt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'SelfRevocationStatusDataOneOf1')
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
          ..add('receipt', receipt))
        .toString();
  }
}

class SelfRevocationStatusDataOneOf1Builder
    implements
        Builder<
          SelfRevocationStatusDataOneOf1,
          SelfRevocationStatusDataOneOf1Builder
        > {
  _$SelfRevocationStatusDataOneOf1? _$v;

  SelfRevocationStatusDataOneOf1StatusEnum? _status;
  SelfRevocationStatusDataOneOf1StatusEnum? get status => _$this._status;
  set status(SelfRevocationStatusDataOneOf1StatusEnum? status) =>
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

  SelfRevocationStatusDataOneOf1ReceiptBuilder? _receipt;
  SelfRevocationStatusDataOneOf1ReceiptBuilder get receipt =>
      _$this._receipt ??= SelfRevocationStatusDataOneOf1ReceiptBuilder();
  set receipt(SelfRevocationStatusDataOneOf1ReceiptBuilder? receipt) =>
      _$this._receipt = receipt;

  SelfRevocationStatusDataOneOf1Builder() {
    SelfRevocationStatusDataOneOf1._defaults(this);
  }

  SelfRevocationStatusDataOneOf1Builder get _$this {
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
      _receipt = $v.receipt.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SelfRevocationStatusDataOneOf1 other) {
    _$v = other as _$SelfRevocationStatusDataOneOf1;
  }

  @override
  void update(void Function(SelfRevocationStatusDataOneOf1Builder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SelfRevocationStatusDataOneOf1 build() => _build();

  _$SelfRevocationStatusDataOneOf1 _build() {
    _$SelfRevocationStatusDataOneOf1 _$result;
    try {
      _$result =
          _$v ??
          _$SelfRevocationStatusDataOneOf1._(
            status: BuiltValueNullFieldError.checkNotNull(
              status,
              r'SelfRevocationStatusDataOneOf1',
              'status',
            ),
            deviceId: BuiltValueNullFieldError.checkNotNull(
              deviceId,
              r'SelfRevocationStatusDataOneOf1',
              'deviceId',
            ),
            mutationId: BuiltValueNullFieldError.checkNotNull(
              mutationId,
              r'SelfRevocationStatusDataOneOf1',
              'mutationId',
            ),
            operationId: BuiltValueNullFieldError.checkNotNull(
              operationId,
              r'SelfRevocationStatusDataOneOf1',
              'operationId',
            ),
            expectedGeneration: BuiltValueNullFieldError.checkNotNull(
              expectedGeneration,
              r'SelfRevocationStatusDataOneOf1',
              'expectedGeneration',
            ),
            expectedKeyEpoch: BuiltValueNullFieldError.checkNotNull(
              expectedKeyEpoch,
              r'SelfRevocationStatusDataOneOf1',
              'expectedKeyEpoch',
            ),
            expectedMembershipManifestDigest:
                BuiltValueNullFieldError.checkNotNull(
                  expectedMembershipManifestDigest,
                  r'SelfRevocationStatusDataOneOf1',
                  'expectedMembershipManifestDigest',
                ),
            intentDigest: BuiltValueNullFieldError.checkNotNull(
              intentDigest,
              r'SelfRevocationStatusDataOneOf1',
              'intentDigest',
            ),
            intentSignature: BuiltValueNullFieldError.checkNotNull(
              intentSignature,
              r'SelfRevocationStatusDataOneOf1',
              'intentSignature',
            ),
            requestedAt: BuiltValueNullFieldError.checkNotNull(
              requestedAt,
              r'SelfRevocationStatusDataOneOf1',
              'requestedAt',
            ),
            expiresAt: BuiltValueNullFieldError.checkNotNull(
              expiresAt,
              r'SelfRevocationStatusDataOneOf1',
              'expiresAt',
            ),
            receiptExpiresAt: BuiltValueNullFieldError.checkNotNull(
              receiptExpiresAt,
              r'SelfRevocationStatusDataOneOf1',
              'receiptExpiresAt',
            ),
            receipt: receipt.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'receipt';
        receipt.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'SelfRevocationStatusDataOneOf1',
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
