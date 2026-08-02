// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_self_revocation_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$CreateSelfRevocationRequest extends CreateSelfRevocationRequest {
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
  final DateTime expiresAt;
  @override
  final String continuationToken;
  @override
  final String intentSignature;

  factory _$CreateSelfRevocationRequest([
    void Function(CreateSelfRevocationRequestBuilder)? updates,
  ]) => (CreateSelfRevocationRequestBuilder()..update(updates))._build();

  _$CreateSelfRevocationRequest._({
    required this.mutationId,
    required this.operationId,
    required this.expectedGeneration,
    required this.expectedKeyEpoch,
    required this.expectedMembershipManifestDigest,
    required this.expiresAt,
    required this.continuationToken,
    required this.intentSignature,
  }) : super._();
  @override
  CreateSelfRevocationRequest rebuild(
    void Function(CreateSelfRevocationRequestBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  CreateSelfRevocationRequestBuilder toBuilder() =>
      CreateSelfRevocationRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is CreateSelfRevocationRequest &&
        mutationId == other.mutationId &&
        operationId == other.operationId &&
        expectedGeneration == other.expectedGeneration &&
        expectedKeyEpoch == other.expectedKeyEpoch &&
        expectedMembershipManifestDigest ==
            other.expectedMembershipManifestDigest &&
        expiresAt == other.expiresAt &&
        continuationToken == other.continuationToken &&
        intentSignature == other.intentSignature;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, mutationId.hashCode);
    _$hash = $jc(_$hash, operationId.hashCode);
    _$hash = $jc(_$hash, expectedGeneration.hashCode);
    _$hash = $jc(_$hash, expectedKeyEpoch.hashCode);
    _$hash = $jc(_$hash, expectedMembershipManifestDigest.hashCode);
    _$hash = $jc(_$hash, expiresAt.hashCode);
    _$hash = $jc(_$hash, continuationToken.hashCode);
    _$hash = $jc(_$hash, intentSignature.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'CreateSelfRevocationRequest')
          ..add('mutationId', mutationId)
          ..add('operationId', operationId)
          ..add('expectedGeneration', expectedGeneration)
          ..add('expectedKeyEpoch', expectedKeyEpoch)
          ..add(
            'expectedMembershipManifestDigest',
            expectedMembershipManifestDigest,
          )
          ..add('expiresAt', expiresAt)
          ..add('continuationToken', continuationToken)
          ..add('intentSignature', intentSignature))
        .toString();
  }
}

class CreateSelfRevocationRequestBuilder
    implements
        Builder<
          CreateSelfRevocationRequest,
          CreateSelfRevocationRequestBuilder
        > {
  _$CreateSelfRevocationRequest? _$v;

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

  DateTime? _expiresAt;
  DateTime? get expiresAt => _$this._expiresAt;
  set expiresAt(DateTime? expiresAt) => _$this._expiresAt = expiresAt;

  String? _continuationToken;
  String? get continuationToken => _$this._continuationToken;
  set continuationToken(String? continuationToken) =>
      _$this._continuationToken = continuationToken;

  String? _intentSignature;
  String? get intentSignature => _$this._intentSignature;
  set intentSignature(String? intentSignature) =>
      _$this._intentSignature = intentSignature;

  CreateSelfRevocationRequestBuilder() {
    CreateSelfRevocationRequest._defaults(this);
  }

  CreateSelfRevocationRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _mutationId = $v.mutationId;
      _operationId = $v.operationId;
      _expectedGeneration = $v.expectedGeneration;
      _expectedKeyEpoch = $v.expectedKeyEpoch;
      _expectedMembershipManifestDigest = $v.expectedMembershipManifestDigest;
      _expiresAt = $v.expiresAt;
      _continuationToken = $v.continuationToken;
      _intentSignature = $v.intentSignature;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(CreateSelfRevocationRequest other) {
    _$v = other as _$CreateSelfRevocationRequest;
  }

  @override
  void update(void Function(CreateSelfRevocationRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  CreateSelfRevocationRequest build() => _build();

  _$CreateSelfRevocationRequest _build() {
    final _$result =
        _$v ??
        _$CreateSelfRevocationRequest._(
          mutationId: BuiltValueNullFieldError.checkNotNull(
            mutationId,
            r'CreateSelfRevocationRequest',
            'mutationId',
          ),
          operationId: BuiltValueNullFieldError.checkNotNull(
            operationId,
            r'CreateSelfRevocationRequest',
            'operationId',
          ),
          expectedGeneration: BuiltValueNullFieldError.checkNotNull(
            expectedGeneration,
            r'CreateSelfRevocationRequest',
            'expectedGeneration',
          ),
          expectedKeyEpoch: BuiltValueNullFieldError.checkNotNull(
            expectedKeyEpoch,
            r'CreateSelfRevocationRequest',
            'expectedKeyEpoch',
          ),
          expectedMembershipManifestDigest:
              BuiltValueNullFieldError.checkNotNull(
                expectedMembershipManifestDigest,
                r'CreateSelfRevocationRequest',
                'expectedMembershipManifestDigest',
              ),
          expiresAt: BuiltValueNullFieldError.checkNotNull(
            expiresAt,
            r'CreateSelfRevocationRequest',
            'expiresAt',
          ),
          continuationToken: BuiltValueNullFieldError.checkNotNull(
            continuationToken,
            r'CreateSelfRevocationRequest',
            'continuationToken',
          ),
          intentSignature: BuiltValueNullFieldError.checkNotNull(
            intentSignature,
            r'CreateSelfRevocationRequest',
            'intentSignature',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
