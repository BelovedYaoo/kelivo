// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'self_revocation_request_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const SelfRevocationRequestDataResultEnum
_$selfRevocationRequestDataResultEnum_requested =
    const SelfRevocationRequestDataResultEnum._('requested');

SelfRevocationRequestDataResultEnum
_$selfRevocationRequestDataResultEnumValueOf(String name) {
  switch (name) {
    case 'requested':
      return _$selfRevocationRequestDataResultEnum_requested;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<SelfRevocationRequestDataResultEnum>
_$selfRevocationRequestDataResultEnumValues =
    BuiltSet<SelfRevocationRequestDataResultEnum>(
      const <SelfRevocationRequestDataResultEnum>[
        _$selfRevocationRequestDataResultEnum_requested,
      ],
    );

const SelfRevocationRequestDataStatusEnum
_$selfRevocationRequestDataStatusEnum_pending =
    const SelfRevocationRequestDataStatusEnum._('pending');

SelfRevocationRequestDataStatusEnum
_$selfRevocationRequestDataStatusEnumValueOf(String name) {
  switch (name) {
    case 'pending':
      return _$selfRevocationRequestDataStatusEnum_pending;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<SelfRevocationRequestDataStatusEnum>
_$selfRevocationRequestDataStatusEnumValues =
    BuiltSet<SelfRevocationRequestDataStatusEnum>(
      const <SelfRevocationRequestDataStatusEnum>[
        _$selfRevocationRequestDataStatusEnum_pending,
      ],
    );

Serializer<SelfRevocationRequestDataResultEnum>
_$selfRevocationRequestDataResultEnumSerializer =
    _$SelfRevocationRequestDataResultEnumSerializer();
Serializer<SelfRevocationRequestDataStatusEnum>
_$selfRevocationRequestDataStatusEnumSerializer =
    _$SelfRevocationRequestDataStatusEnumSerializer();

class _$SelfRevocationRequestDataResultEnumSerializer
    implements PrimitiveSerializer<SelfRevocationRequestDataResultEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'requested': 'requested',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'requested': 'requested',
  };

  @override
  final Iterable<Type> types = const <Type>[
    SelfRevocationRequestDataResultEnum,
  ];
  @override
  final String wireName = 'SelfRevocationRequestDataResultEnum';

  @override
  Object serialize(
    Serializers serializers,
    SelfRevocationRequestDataResultEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  SelfRevocationRequestDataResultEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => SelfRevocationRequestDataResultEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$SelfRevocationRequestDataStatusEnumSerializer
    implements PrimitiveSerializer<SelfRevocationRequestDataStatusEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'pending': 'pending',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'pending': 'pending',
  };

  @override
  final Iterable<Type> types = const <Type>[
    SelfRevocationRequestDataStatusEnum,
  ];
  @override
  final String wireName = 'SelfRevocationRequestDataStatusEnum';

  @override
  Object serialize(
    Serializers serializers,
    SelfRevocationRequestDataStatusEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  SelfRevocationRequestDataStatusEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => SelfRevocationRequestDataStatusEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$SelfRevocationRequestData extends SelfRevocationRequestData {
  @override
  final SelfRevocationRequestDataResultEnum result;
  @override
  final SelfRevocationRequestDataStatusEnum status;
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

  factory _$SelfRevocationRequestData([
    void Function(SelfRevocationRequestDataBuilder)? updates,
  ]) => (SelfRevocationRequestDataBuilder()..update(updates))._build();

  _$SelfRevocationRequestData._({
    required this.result,
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
  SelfRevocationRequestData rebuild(
    void Function(SelfRevocationRequestDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  SelfRevocationRequestDataBuilder toBuilder() =>
      SelfRevocationRequestDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SelfRevocationRequestData &&
        result == other.result &&
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
    _$hash = $jc(_$hash, result.hashCode);
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
    return (newBuiltValueToStringHelper(r'SelfRevocationRequestData')
          ..add('result', result)
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

class SelfRevocationRequestDataBuilder
    implements
        Builder<SelfRevocationRequestData, SelfRevocationRequestDataBuilder> {
  _$SelfRevocationRequestData? _$v;

  SelfRevocationRequestDataResultEnum? _result;
  SelfRevocationRequestDataResultEnum? get result => _$this._result;
  set result(SelfRevocationRequestDataResultEnum? result) =>
      _$this._result = result;

  SelfRevocationRequestDataStatusEnum? _status;
  SelfRevocationRequestDataStatusEnum? get status => _$this._status;
  set status(SelfRevocationRequestDataStatusEnum? status) =>
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

  SelfRevocationRequestDataBuilder() {
    SelfRevocationRequestData._defaults(this);
  }

  SelfRevocationRequestDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _result = $v.result;
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
  void replace(SelfRevocationRequestData other) {
    _$v = other as _$SelfRevocationRequestData;
  }

  @override
  void update(void Function(SelfRevocationRequestDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SelfRevocationRequestData build() => _build();

  _$SelfRevocationRequestData _build() {
    final _$result =
        _$v ??
        _$SelfRevocationRequestData._(
          result: BuiltValueNullFieldError.checkNotNull(
            result,
            r'SelfRevocationRequestData',
            'result',
          ),
          status: BuiltValueNullFieldError.checkNotNull(
            status,
            r'SelfRevocationRequestData',
            'status',
          ),
          deviceId: BuiltValueNullFieldError.checkNotNull(
            deviceId,
            r'SelfRevocationRequestData',
            'deviceId',
          ),
          mutationId: BuiltValueNullFieldError.checkNotNull(
            mutationId,
            r'SelfRevocationRequestData',
            'mutationId',
          ),
          operationId: BuiltValueNullFieldError.checkNotNull(
            operationId,
            r'SelfRevocationRequestData',
            'operationId',
          ),
          expectedGeneration: BuiltValueNullFieldError.checkNotNull(
            expectedGeneration,
            r'SelfRevocationRequestData',
            'expectedGeneration',
          ),
          expectedKeyEpoch: BuiltValueNullFieldError.checkNotNull(
            expectedKeyEpoch,
            r'SelfRevocationRequestData',
            'expectedKeyEpoch',
          ),
          expectedMembershipManifestDigest:
              BuiltValueNullFieldError.checkNotNull(
                expectedMembershipManifestDigest,
                r'SelfRevocationRequestData',
                'expectedMembershipManifestDigest',
              ),
          intentDigest: BuiltValueNullFieldError.checkNotNull(
            intentDigest,
            r'SelfRevocationRequestData',
            'intentDigest',
          ),
          intentSignature: BuiltValueNullFieldError.checkNotNull(
            intentSignature,
            r'SelfRevocationRequestData',
            'intentSignature',
          ),
          requestedAt: BuiltValueNullFieldError.checkNotNull(
            requestedAt,
            r'SelfRevocationRequestData',
            'requestedAt',
          ),
          expiresAt: BuiltValueNullFieldError.checkNotNull(
            expiresAt,
            r'SelfRevocationRequestData',
            'expiresAt',
          ),
          receiptExpiresAt: BuiltValueNullFieldError.checkNotNull(
            receiptExpiresAt,
            r'SelfRevocationRequestData',
            'receiptExpiresAt',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
