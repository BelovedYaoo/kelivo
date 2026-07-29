// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'commit_device_rotation_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$CommitDeviceRotationRequest extends CommitDeviceRotationRequest {
  @override
  final int expectedGeneration;
  @override
  final int expectedKeyEpoch;
  @override
  final String expectedMembershipManifestDigest;
  @override
  final String operationId;
  @override
  final String revokeDeviceId;
  @override
  final String nextMembershipManifest;
  @override
  final String nextMembershipManifestDigest;
  @override
  final int nextRecoveryCapsuleVersion;
  @override
  final String nextRecoveryCapsule;
  @override
  final BuiltList<UnsignedAccountSecurityStateEnvelope> envelopes;

  factory _$CommitDeviceRotationRequest([
    void Function(CommitDeviceRotationRequestBuilder)? updates,
  ]) => (CommitDeviceRotationRequestBuilder()..update(updates))._build();

  _$CommitDeviceRotationRequest._({
    required this.expectedGeneration,
    required this.expectedKeyEpoch,
    required this.expectedMembershipManifestDigest,
    required this.operationId,
    required this.revokeDeviceId,
    required this.nextMembershipManifest,
    required this.nextMembershipManifestDigest,
    required this.nextRecoveryCapsuleVersion,
    required this.nextRecoveryCapsule,
    required this.envelopes,
  }) : super._();
  @override
  CommitDeviceRotationRequest rebuild(
    void Function(CommitDeviceRotationRequestBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  CommitDeviceRotationRequestBuilder toBuilder() =>
      CommitDeviceRotationRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is CommitDeviceRotationRequest &&
        expectedGeneration == other.expectedGeneration &&
        expectedKeyEpoch == other.expectedKeyEpoch &&
        expectedMembershipManifestDigest ==
            other.expectedMembershipManifestDigest &&
        operationId == other.operationId &&
        revokeDeviceId == other.revokeDeviceId &&
        nextMembershipManifest == other.nextMembershipManifest &&
        nextMembershipManifestDigest == other.nextMembershipManifestDigest &&
        nextRecoveryCapsuleVersion == other.nextRecoveryCapsuleVersion &&
        nextRecoveryCapsule == other.nextRecoveryCapsule &&
        envelopes == other.envelopes;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, expectedGeneration.hashCode);
    _$hash = $jc(_$hash, expectedKeyEpoch.hashCode);
    _$hash = $jc(_$hash, expectedMembershipManifestDigest.hashCode);
    _$hash = $jc(_$hash, operationId.hashCode);
    _$hash = $jc(_$hash, revokeDeviceId.hashCode);
    _$hash = $jc(_$hash, nextMembershipManifest.hashCode);
    _$hash = $jc(_$hash, nextMembershipManifestDigest.hashCode);
    _$hash = $jc(_$hash, nextRecoveryCapsuleVersion.hashCode);
    _$hash = $jc(_$hash, nextRecoveryCapsule.hashCode);
    _$hash = $jc(_$hash, envelopes.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'CommitDeviceRotationRequest')
          ..add('expectedGeneration', expectedGeneration)
          ..add('expectedKeyEpoch', expectedKeyEpoch)
          ..add(
            'expectedMembershipManifestDigest',
            expectedMembershipManifestDigest,
          )
          ..add('operationId', operationId)
          ..add('revokeDeviceId', revokeDeviceId)
          ..add('nextMembershipManifest', nextMembershipManifest)
          ..add('nextMembershipManifestDigest', nextMembershipManifestDigest)
          ..add('nextRecoveryCapsuleVersion', nextRecoveryCapsuleVersion)
          ..add('nextRecoveryCapsule', nextRecoveryCapsule)
          ..add('envelopes', envelopes))
        .toString();
  }
}

class CommitDeviceRotationRequestBuilder
    implements
        Builder<
          CommitDeviceRotationRequest,
          CommitDeviceRotationRequestBuilder
        > {
  _$CommitDeviceRotationRequest? _$v;

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

  String? _operationId;
  String? get operationId => _$this._operationId;
  set operationId(String? operationId) => _$this._operationId = operationId;

  String? _revokeDeviceId;
  String? get revokeDeviceId => _$this._revokeDeviceId;
  set revokeDeviceId(String? revokeDeviceId) =>
      _$this._revokeDeviceId = revokeDeviceId;

  String? _nextMembershipManifest;
  String? get nextMembershipManifest => _$this._nextMembershipManifest;
  set nextMembershipManifest(String? nextMembershipManifest) =>
      _$this._nextMembershipManifest = nextMembershipManifest;

  String? _nextMembershipManifestDigest;
  String? get nextMembershipManifestDigest =>
      _$this._nextMembershipManifestDigest;
  set nextMembershipManifestDigest(String? nextMembershipManifestDigest) =>
      _$this._nextMembershipManifestDigest = nextMembershipManifestDigest;

  int? _nextRecoveryCapsuleVersion;
  int? get nextRecoveryCapsuleVersion => _$this._nextRecoveryCapsuleVersion;
  set nextRecoveryCapsuleVersion(int? nextRecoveryCapsuleVersion) =>
      _$this._nextRecoveryCapsuleVersion = nextRecoveryCapsuleVersion;

  String? _nextRecoveryCapsule;
  String? get nextRecoveryCapsule => _$this._nextRecoveryCapsule;
  set nextRecoveryCapsule(String? nextRecoveryCapsule) =>
      _$this._nextRecoveryCapsule = nextRecoveryCapsule;

  ListBuilder<UnsignedAccountSecurityStateEnvelope>? _envelopes;
  ListBuilder<UnsignedAccountSecurityStateEnvelope> get envelopes =>
      _$this._envelopes ??= ListBuilder<UnsignedAccountSecurityStateEnvelope>();
  set envelopes(ListBuilder<UnsignedAccountSecurityStateEnvelope>? envelopes) =>
      _$this._envelopes = envelopes;

  CommitDeviceRotationRequestBuilder() {
    CommitDeviceRotationRequest._defaults(this);
  }

  CommitDeviceRotationRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _expectedGeneration = $v.expectedGeneration;
      _expectedKeyEpoch = $v.expectedKeyEpoch;
      _expectedMembershipManifestDigest = $v.expectedMembershipManifestDigest;
      _operationId = $v.operationId;
      _revokeDeviceId = $v.revokeDeviceId;
      _nextMembershipManifest = $v.nextMembershipManifest;
      _nextMembershipManifestDigest = $v.nextMembershipManifestDigest;
      _nextRecoveryCapsuleVersion = $v.nextRecoveryCapsuleVersion;
      _nextRecoveryCapsule = $v.nextRecoveryCapsule;
      _envelopes = $v.envelopes.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(CommitDeviceRotationRequest other) {
    _$v = other as _$CommitDeviceRotationRequest;
  }

  @override
  void update(void Function(CommitDeviceRotationRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  CommitDeviceRotationRequest build() => _build();

  _$CommitDeviceRotationRequest _build() {
    _$CommitDeviceRotationRequest _$result;
    try {
      _$result =
          _$v ??
          _$CommitDeviceRotationRequest._(
            expectedGeneration: BuiltValueNullFieldError.checkNotNull(
              expectedGeneration,
              r'CommitDeviceRotationRequest',
              'expectedGeneration',
            ),
            expectedKeyEpoch: BuiltValueNullFieldError.checkNotNull(
              expectedKeyEpoch,
              r'CommitDeviceRotationRequest',
              'expectedKeyEpoch',
            ),
            expectedMembershipManifestDigest:
                BuiltValueNullFieldError.checkNotNull(
                  expectedMembershipManifestDigest,
                  r'CommitDeviceRotationRequest',
                  'expectedMembershipManifestDigest',
                ),
            operationId: BuiltValueNullFieldError.checkNotNull(
              operationId,
              r'CommitDeviceRotationRequest',
              'operationId',
            ),
            revokeDeviceId: BuiltValueNullFieldError.checkNotNull(
              revokeDeviceId,
              r'CommitDeviceRotationRequest',
              'revokeDeviceId',
            ),
            nextMembershipManifest: BuiltValueNullFieldError.checkNotNull(
              nextMembershipManifest,
              r'CommitDeviceRotationRequest',
              'nextMembershipManifest',
            ),
            nextMembershipManifestDigest: BuiltValueNullFieldError.checkNotNull(
              nextMembershipManifestDigest,
              r'CommitDeviceRotationRequest',
              'nextMembershipManifestDigest',
            ),
            nextRecoveryCapsuleVersion: BuiltValueNullFieldError.checkNotNull(
              nextRecoveryCapsuleVersion,
              r'CommitDeviceRotationRequest',
              'nextRecoveryCapsuleVersion',
            ),
            nextRecoveryCapsule: BuiltValueNullFieldError.checkNotNull(
              nextRecoveryCapsule,
              r'CommitDeviceRotationRequest',
              'nextRecoveryCapsule',
            ),
            envelopes: envelopes.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'envelopes';
        envelopes.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'CommitDeviceRotationRequest',
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
