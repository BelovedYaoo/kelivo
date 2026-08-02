// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_recovery_replacement_commit_request_authorization_one_of1.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const AccountRecoveryReplacementCommitRequestAuthorizationOneOf1KindEnum
_$accountRecoveryReplacementCommitRequestAuthorizationOneOf1KindEnum_replacementChallenge =
    const AccountRecoveryReplacementCommitRequestAuthorizationOneOf1KindEnum._(
      'replacementChallenge',
    );

AccountRecoveryReplacementCommitRequestAuthorizationOneOf1KindEnum
_$accountRecoveryReplacementCommitRequestAuthorizationOneOf1KindEnumValueOf(
  String name,
) {
  switch (name) {
    case 'replacementChallenge':
      return _$accountRecoveryReplacementCommitRequestAuthorizationOneOf1KindEnum_replacementChallenge;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<
  AccountRecoveryReplacementCommitRequestAuthorizationOneOf1KindEnum
>
_$accountRecoveryReplacementCommitRequestAuthorizationOneOf1KindEnumValues =
    BuiltSet<
      AccountRecoveryReplacementCommitRequestAuthorizationOneOf1KindEnum
    >(const <
      AccountRecoveryReplacementCommitRequestAuthorizationOneOf1KindEnum
    >[
      _$accountRecoveryReplacementCommitRequestAuthorizationOneOf1KindEnum_replacementChallenge,
    ]);

Serializer<AccountRecoveryReplacementCommitRequestAuthorizationOneOf1KindEnum>
_$accountRecoveryReplacementCommitRequestAuthorizationOneOf1KindEnumSerializer =
    _$AccountRecoveryReplacementCommitRequestAuthorizationOneOf1KindEnumSerializer();

class _$AccountRecoveryReplacementCommitRequestAuthorizationOneOf1KindEnumSerializer
    implements
        PrimitiveSerializer<
          AccountRecoveryReplacementCommitRequestAuthorizationOneOf1KindEnum
        > {
  static const Map<String, Object> _toWire = const <String, Object>{
    'replacementChallenge': 'replacement-challenge',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'replacement-challenge': 'replacementChallenge',
  };

  @override
  final Iterable<Type> types = const <Type>[
    AccountRecoveryReplacementCommitRequestAuthorizationOneOf1KindEnum,
  ];
  @override
  final String wireName =
      'AccountRecoveryReplacementCommitRequestAuthorizationOneOf1KindEnum';

  @override
  Object serialize(
    Serializers serializers,
    AccountRecoveryReplacementCommitRequestAuthorizationOneOf1KindEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  AccountRecoveryReplacementCommitRequestAuthorizationOneOf1KindEnum
  deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) =>
      AccountRecoveryReplacementCommitRequestAuthorizationOneOf1KindEnum.valueOf(
        _fromWire[serialized] ?? (serialized is String ? serialized : ''),
      );
}

class _$AccountRecoveryReplacementCommitRequestAuthorizationOneOf1
    extends AccountRecoveryReplacementCommitRequestAuthorizationOneOf1 {
  @override
  final AccountRecoveryReplacementCommitRequestAuthorizationOneOf1KindEnum kind;
  @override
  final String challengeId;
  @override
  final String challengeRequestDigest;
  @override
  final String nonceProof;
  @override
  final String trustSignature;

  factory _$AccountRecoveryReplacementCommitRequestAuthorizationOneOf1([
    void Function(
      AccountRecoveryReplacementCommitRequestAuthorizationOneOf1Builder,
    )?
    updates,
  ]) =>
      (AccountRecoveryReplacementCommitRequestAuthorizationOneOf1Builder()
            ..update(updates))
          ._build();

  _$AccountRecoveryReplacementCommitRequestAuthorizationOneOf1._({
    required this.kind,
    required this.challengeId,
    required this.challengeRequestDigest,
    required this.nonceProof,
    required this.trustSignature,
  }) : super._();
  @override
  AccountRecoveryReplacementCommitRequestAuthorizationOneOf1 rebuild(
    void Function(
      AccountRecoveryReplacementCommitRequestAuthorizationOneOf1Builder,
    )
    updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  AccountRecoveryReplacementCommitRequestAuthorizationOneOf1Builder
  toBuilder() =>
      AccountRecoveryReplacementCommitRequestAuthorizationOneOf1Builder()
        ..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other
            is AccountRecoveryReplacementCommitRequestAuthorizationOneOf1 &&
        kind == other.kind &&
        challengeId == other.challengeId &&
        challengeRequestDigest == other.challengeRequestDigest &&
        nonceProof == other.nonceProof &&
        trustSignature == other.trustSignature;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, kind.hashCode);
    _$hash = $jc(_$hash, challengeId.hashCode);
    _$hash = $jc(_$hash, challengeRequestDigest.hashCode);
    _$hash = $jc(_$hash, nonceProof.hashCode);
    _$hash = $jc(_$hash, trustSignature.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(
            r'AccountRecoveryReplacementCommitRequestAuthorizationOneOf1',
          )
          ..add('kind', kind)
          ..add('challengeId', challengeId)
          ..add('challengeRequestDigest', challengeRequestDigest)
          ..add('nonceProof', nonceProof)
          ..add('trustSignature', trustSignature))
        .toString();
  }
}

class AccountRecoveryReplacementCommitRequestAuthorizationOneOf1Builder
    implements
        Builder<
          AccountRecoveryReplacementCommitRequestAuthorizationOneOf1,
          AccountRecoveryReplacementCommitRequestAuthorizationOneOf1Builder
        > {
  _$AccountRecoveryReplacementCommitRequestAuthorizationOneOf1? _$v;

  AccountRecoveryReplacementCommitRequestAuthorizationOneOf1KindEnum? _kind;
  AccountRecoveryReplacementCommitRequestAuthorizationOneOf1KindEnum?
  get kind => _$this._kind;
  set kind(
    AccountRecoveryReplacementCommitRequestAuthorizationOneOf1KindEnum? kind,
  ) => _$this._kind = kind;

  String? _challengeId;
  String? get challengeId => _$this._challengeId;
  set challengeId(String? challengeId) => _$this._challengeId = challengeId;

  String? _challengeRequestDigest;
  String? get challengeRequestDigest => _$this._challengeRequestDigest;
  set challengeRequestDigest(String? challengeRequestDigest) =>
      _$this._challengeRequestDigest = challengeRequestDigest;

  String? _nonceProof;
  String? get nonceProof => _$this._nonceProof;
  set nonceProof(String? nonceProof) => _$this._nonceProof = nonceProof;

  String? _trustSignature;
  String? get trustSignature => _$this._trustSignature;
  set trustSignature(String? trustSignature) =>
      _$this._trustSignature = trustSignature;

  AccountRecoveryReplacementCommitRequestAuthorizationOneOf1Builder() {
    AccountRecoveryReplacementCommitRequestAuthorizationOneOf1._defaults(this);
  }

  AccountRecoveryReplacementCommitRequestAuthorizationOneOf1Builder get _$this {
    final $v = _$v;
    if ($v != null) {
      _kind = $v.kind;
      _challengeId = $v.challengeId;
      _challengeRequestDigest = $v.challengeRequestDigest;
      _nonceProof = $v.nonceProof;
      _trustSignature = $v.trustSignature;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(
    AccountRecoveryReplacementCommitRequestAuthorizationOneOf1 other,
  ) {
    _$v = other as _$AccountRecoveryReplacementCommitRequestAuthorizationOneOf1;
  }

  @override
  void update(
    void Function(
      AccountRecoveryReplacementCommitRequestAuthorizationOneOf1Builder,
    )?
    updates,
  ) {
    if (updates != null) updates(this);
  }

  @override
  AccountRecoveryReplacementCommitRequestAuthorizationOneOf1 build() =>
      _build();

  _$AccountRecoveryReplacementCommitRequestAuthorizationOneOf1 _build() {
    final _$result =
        _$v ??
        _$AccountRecoveryReplacementCommitRequestAuthorizationOneOf1._(
          kind: BuiltValueNullFieldError.checkNotNull(
            kind,
            r'AccountRecoveryReplacementCommitRequestAuthorizationOneOf1',
            'kind',
          ),
          challengeId: BuiltValueNullFieldError.checkNotNull(
            challengeId,
            r'AccountRecoveryReplacementCommitRequestAuthorizationOneOf1',
            'challengeId',
          ),
          challengeRequestDigest: BuiltValueNullFieldError.checkNotNull(
            challengeRequestDigest,
            r'AccountRecoveryReplacementCommitRequestAuthorizationOneOf1',
            'challengeRequestDigest',
          ),
          nonceProof: BuiltValueNullFieldError.checkNotNull(
            nonceProof,
            r'AccountRecoveryReplacementCommitRequestAuthorizationOneOf1',
            'nonceProof',
          ),
          trustSignature: BuiltValueNullFieldError.checkNotNull(
            trustSignature,
            r'AccountRecoveryReplacementCommitRequestAuthorizationOneOf1',
            'trustSignature',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
