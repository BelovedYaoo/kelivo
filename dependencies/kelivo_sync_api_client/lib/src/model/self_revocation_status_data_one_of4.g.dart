// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'self_revocation_status_data_one_of4.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const SelfRevocationStatusDataOneOf4StatusEnum
_$selfRevocationStatusDataOneOf4StatusEnum_superseded =
    const SelfRevocationStatusDataOneOf4StatusEnum._('superseded');

SelfRevocationStatusDataOneOf4StatusEnum
_$selfRevocationStatusDataOneOf4StatusEnumValueOf(String name) {
  switch (name) {
    case 'superseded':
      return _$selfRevocationStatusDataOneOf4StatusEnum_superseded;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<SelfRevocationStatusDataOneOf4StatusEnum>
_$selfRevocationStatusDataOneOf4StatusEnumValues =
    BuiltSet<SelfRevocationStatusDataOneOf4StatusEnum>(
      const <SelfRevocationStatusDataOneOf4StatusEnum>[
        _$selfRevocationStatusDataOneOf4StatusEnum_superseded,
      ],
    );

Serializer<SelfRevocationStatusDataOneOf4StatusEnum>
_$selfRevocationStatusDataOneOf4StatusEnumSerializer =
    _$SelfRevocationStatusDataOneOf4StatusEnumSerializer();

class _$SelfRevocationStatusDataOneOf4StatusEnumSerializer
    implements PrimitiveSerializer<SelfRevocationStatusDataOneOf4StatusEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'superseded': 'superseded',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'superseded': 'superseded',
  };

  @override
  final Iterable<Type> types = const <Type>[
    SelfRevocationStatusDataOneOf4StatusEnum,
  ];
  @override
  final String wireName = 'SelfRevocationStatusDataOneOf4StatusEnum';

  @override
  Object serialize(
    Serializers serializers,
    SelfRevocationStatusDataOneOf4StatusEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  SelfRevocationStatusDataOneOf4StatusEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => SelfRevocationStatusDataOneOf4StatusEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$SelfRevocationStatusDataOneOf4 extends SelfRevocationStatusDataOneOf4 {
  @override
  final SelfRevocationStatusDataOneOf4StatusEnum status;
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

  factory _$SelfRevocationStatusDataOneOf4([
    void Function(SelfRevocationStatusDataOneOf4Builder)? updates,
  ]) => (SelfRevocationStatusDataOneOf4Builder()..update(updates))._build();

  _$SelfRevocationStatusDataOneOf4._({
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
  SelfRevocationStatusDataOneOf4 rebuild(
    void Function(SelfRevocationStatusDataOneOf4Builder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  SelfRevocationStatusDataOneOf4Builder toBuilder() =>
      SelfRevocationStatusDataOneOf4Builder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SelfRevocationStatusDataOneOf4 &&
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
    return (newBuiltValueToStringHelper(r'SelfRevocationStatusDataOneOf4')
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

class SelfRevocationStatusDataOneOf4Builder
    implements
        Builder<
          SelfRevocationStatusDataOneOf4,
          SelfRevocationStatusDataOneOf4Builder
        > {
  _$SelfRevocationStatusDataOneOf4? _$v;

  SelfRevocationStatusDataOneOf4StatusEnum? _status;
  SelfRevocationStatusDataOneOf4StatusEnum? get status => _$this._status;
  set status(SelfRevocationStatusDataOneOf4StatusEnum? status) =>
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

  SelfRevocationStatusDataOneOf4Builder() {
    SelfRevocationStatusDataOneOf4._defaults(this);
  }

  SelfRevocationStatusDataOneOf4Builder get _$this {
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
  void replace(SelfRevocationStatusDataOneOf4 other) {
    _$v = other as _$SelfRevocationStatusDataOneOf4;
  }

  @override
  void update(void Function(SelfRevocationStatusDataOneOf4Builder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SelfRevocationStatusDataOneOf4 build() => _build();

  _$SelfRevocationStatusDataOneOf4 _build() {
    final _$result =
        _$v ??
        _$SelfRevocationStatusDataOneOf4._(
          status: BuiltValueNullFieldError.checkNotNull(
            status,
            r'SelfRevocationStatusDataOneOf4',
            'status',
          ),
          deviceId: BuiltValueNullFieldError.checkNotNull(
            deviceId,
            r'SelfRevocationStatusDataOneOf4',
            'deviceId',
          ),
          mutationId: BuiltValueNullFieldError.checkNotNull(
            mutationId,
            r'SelfRevocationStatusDataOneOf4',
            'mutationId',
          ),
          operationId: BuiltValueNullFieldError.checkNotNull(
            operationId,
            r'SelfRevocationStatusDataOneOf4',
            'operationId',
          ),
          expectedGeneration: BuiltValueNullFieldError.checkNotNull(
            expectedGeneration,
            r'SelfRevocationStatusDataOneOf4',
            'expectedGeneration',
          ),
          expectedKeyEpoch: BuiltValueNullFieldError.checkNotNull(
            expectedKeyEpoch,
            r'SelfRevocationStatusDataOneOf4',
            'expectedKeyEpoch',
          ),
          expectedMembershipManifestDigest:
              BuiltValueNullFieldError.checkNotNull(
                expectedMembershipManifestDigest,
                r'SelfRevocationStatusDataOneOf4',
                'expectedMembershipManifestDigest',
              ),
          intentDigest: BuiltValueNullFieldError.checkNotNull(
            intentDigest,
            r'SelfRevocationStatusDataOneOf4',
            'intentDigest',
          ),
          intentSignature: BuiltValueNullFieldError.checkNotNull(
            intentSignature,
            r'SelfRevocationStatusDataOneOf4',
            'intentSignature',
          ),
          requestedAt: BuiltValueNullFieldError.checkNotNull(
            requestedAt,
            r'SelfRevocationStatusDataOneOf4',
            'requestedAt',
          ),
          expiresAt: BuiltValueNullFieldError.checkNotNull(
            expiresAt,
            r'SelfRevocationStatusDataOneOf4',
            'expiresAt',
          ),
          receiptExpiresAt: BuiltValueNullFieldError.checkNotNull(
            receiptExpiresAt,
            r'SelfRevocationStatusDataOneOf4',
            'receiptExpiresAt',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
