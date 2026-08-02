// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pending_self_revocation_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$PendingSelfRevocationRequest extends PendingSelfRevocationRequest {
  @override
  final String deviceId;
  @override
  final String deviceName;
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

  factory _$PendingSelfRevocationRequest([
    void Function(PendingSelfRevocationRequestBuilder)? updates,
  ]) => (PendingSelfRevocationRequestBuilder()..update(updates))._build();

  _$PendingSelfRevocationRequest._({
    required this.deviceId,
    required this.deviceName,
    required this.mutationId,
    required this.operationId,
    required this.expectedGeneration,
    required this.expectedKeyEpoch,
    required this.expectedMembershipManifestDigest,
    required this.intentDigest,
    required this.intentSignature,
    required this.requestedAt,
    required this.expiresAt,
  }) : super._();
  @override
  PendingSelfRevocationRequest rebuild(
    void Function(PendingSelfRevocationRequestBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  PendingSelfRevocationRequestBuilder toBuilder() =>
      PendingSelfRevocationRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PendingSelfRevocationRequest &&
        deviceId == other.deviceId &&
        deviceName == other.deviceName &&
        mutationId == other.mutationId &&
        operationId == other.operationId &&
        expectedGeneration == other.expectedGeneration &&
        expectedKeyEpoch == other.expectedKeyEpoch &&
        expectedMembershipManifestDigest ==
            other.expectedMembershipManifestDigest &&
        intentDigest == other.intentDigest &&
        intentSignature == other.intentSignature &&
        requestedAt == other.requestedAt &&
        expiresAt == other.expiresAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, deviceId.hashCode);
    _$hash = $jc(_$hash, deviceName.hashCode);
    _$hash = $jc(_$hash, mutationId.hashCode);
    _$hash = $jc(_$hash, operationId.hashCode);
    _$hash = $jc(_$hash, expectedGeneration.hashCode);
    _$hash = $jc(_$hash, expectedKeyEpoch.hashCode);
    _$hash = $jc(_$hash, expectedMembershipManifestDigest.hashCode);
    _$hash = $jc(_$hash, intentDigest.hashCode);
    _$hash = $jc(_$hash, intentSignature.hashCode);
    _$hash = $jc(_$hash, requestedAt.hashCode);
    _$hash = $jc(_$hash, expiresAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'PendingSelfRevocationRequest')
          ..add('deviceId', deviceId)
          ..add('deviceName', deviceName)
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
          ..add('expiresAt', expiresAt))
        .toString();
  }
}

class PendingSelfRevocationRequestBuilder
    implements
        Builder<
          PendingSelfRevocationRequest,
          PendingSelfRevocationRequestBuilder
        > {
  _$PendingSelfRevocationRequest? _$v;

  String? _deviceId;
  String? get deviceId => _$this._deviceId;
  set deviceId(String? deviceId) => _$this._deviceId = deviceId;

  String? _deviceName;
  String? get deviceName => _$this._deviceName;
  set deviceName(String? deviceName) => _$this._deviceName = deviceName;

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

  PendingSelfRevocationRequestBuilder() {
    PendingSelfRevocationRequest._defaults(this);
  }

  PendingSelfRevocationRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _deviceId = $v.deviceId;
      _deviceName = $v.deviceName;
      _mutationId = $v.mutationId;
      _operationId = $v.operationId;
      _expectedGeneration = $v.expectedGeneration;
      _expectedKeyEpoch = $v.expectedKeyEpoch;
      _expectedMembershipManifestDigest = $v.expectedMembershipManifestDigest;
      _intentDigest = $v.intentDigest;
      _intentSignature = $v.intentSignature;
      _requestedAt = $v.requestedAt;
      _expiresAt = $v.expiresAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(PendingSelfRevocationRequest other) {
    _$v = other as _$PendingSelfRevocationRequest;
  }

  @override
  void update(void Function(PendingSelfRevocationRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  PendingSelfRevocationRequest build() => _build();

  _$PendingSelfRevocationRequest _build() {
    final _$result =
        _$v ??
        _$PendingSelfRevocationRequest._(
          deviceId: BuiltValueNullFieldError.checkNotNull(
            deviceId,
            r'PendingSelfRevocationRequest',
            'deviceId',
          ),
          deviceName: BuiltValueNullFieldError.checkNotNull(
            deviceName,
            r'PendingSelfRevocationRequest',
            'deviceName',
          ),
          mutationId: BuiltValueNullFieldError.checkNotNull(
            mutationId,
            r'PendingSelfRevocationRequest',
            'mutationId',
          ),
          operationId: BuiltValueNullFieldError.checkNotNull(
            operationId,
            r'PendingSelfRevocationRequest',
            'operationId',
          ),
          expectedGeneration: BuiltValueNullFieldError.checkNotNull(
            expectedGeneration,
            r'PendingSelfRevocationRequest',
            'expectedGeneration',
          ),
          expectedKeyEpoch: BuiltValueNullFieldError.checkNotNull(
            expectedKeyEpoch,
            r'PendingSelfRevocationRequest',
            'expectedKeyEpoch',
          ),
          expectedMembershipManifestDigest:
              BuiltValueNullFieldError.checkNotNull(
                expectedMembershipManifestDigest,
                r'PendingSelfRevocationRequest',
                'expectedMembershipManifestDigest',
              ),
          intentDigest: BuiltValueNullFieldError.checkNotNull(
            intentDigest,
            r'PendingSelfRevocationRequest',
            'intentDigest',
          ),
          intentSignature: BuiltValueNullFieldError.checkNotNull(
            intentSignature,
            r'PendingSelfRevocationRequest',
            'intentSignature',
          ),
          requestedAt: BuiltValueNullFieldError.checkNotNull(
            requestedAt,
            r'PendingSelfRevocationRequest',
            'requestedAt',
          ),
          expiresAt: BuiltValueNullFieldError.checkNotNull(
            expiresAt,
            r'PendingSelfRevocationRequest',
            'expiresAt',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
