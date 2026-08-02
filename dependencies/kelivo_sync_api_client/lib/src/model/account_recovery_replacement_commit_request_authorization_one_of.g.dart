// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_recovery_replacement_commit_request_authorization_one_of.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const AccountRecoveryReplacementCommitRequestAuthorizationOneOfKindEnum
_$accountRecoveryReplacementCommitRequestAuthorizationOneOfKindEnum_initial =
    const AccountRecoveryReplacementCommitRequestAuthorizationOneOfKindEnum._(
      'initial',
    );

AccountRecoveryReplacementCommitRequestAuthorizationOneOfKindEnum
_$accountRecoveryReplacementCommitRequestAuthorizationOneOfKindEnumValueOf(
  String name,
) {
  switch (name) {
    case 'initial':
      return _$accountRecoveryReplacementCommitRequestAuthorizationOneOfKindEnum_initial;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<
  AccountRecoveryReplacementCommitRequestAuthorizationOneOfKindEnum
>
_$accountRecoveryReplacementCommitRequestAuthorizationOneOfKindEnumValues =
    BuiltSet<
      AccountRecoveryReplacementCommitRequestAuthorizationOneOfKindEnum
    >(const <AccountRecoveryReplacementCommitRequestAuthorizationOneOfKindEnum>[
      _$accountRecoveryReplacementCommitRequestAuthorizationOneOfKindEnum_initial,
    ]);

Serializer<AccountRecoveryReplacementCommitRequestAuthorizationOneOfKindEnum>
_$accountRecoveryReplacementCommitRequestAuthorizationOneOfKindEnumSerializer =
    _$AccountRecoveryReplacementCommitRequestAuthorizationOneOfKindEnumSerializer();

class _$AccountRecoveryReplacementCommitRequestAuthorizationOneOfKindEnumSerializer
    implements
        PrimitiveSerializer<
          AccountRecoveryReplacementCommitRequestAuthorizationOneOfKindEnum
        > {
  static const Map<String, Object> _toWire = const <String, Object>{
    'initial': 'initial',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'initial': 'initial',
  };

  @override
  final Iterable<Type> types = const <Type>[
    AccountRecoveryReplacementCommitRequestAuthorizationOneOfKindEnum,
  ];
  @override
  final String wireName =
      'AccountRecoveryReplacementCommitRequestAuthorizationOneOfKindEnum';

  @override
  Object serialize(
    Serializers serializers,
    AccountRecoveryReplacementCommitRequestAuthorizationOneOfKindEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  AccountRecoveryReplacementCommitRequestAuthorizationOneOfKindEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) =>
      AccountRecoveryReplacementCommitRequestAuthorizationOneOfKindEnum.valueOf(
        _fromWire[serialized] ?? (serialized is String ? serialized : ''),
      );
}

class _$AccountRecoveryReplacementCommitRequestAuthorizationOneOf
    extends AccountRecoveryReplacementCommitRequestAuthorizationOneOf {
  @override
  final AccountRecoveryReplacementCommitRequestAuthorizationOneOfKindEnum kind;
  @override
  final String challengeRequestDigest;

  factory _$AccountRecoveryReplacementCommitRequestAuthorizationOneOf([
    void Function(
      AccountRecoveryReplacementCommitRequestAuthorizationOneOfBuilder,
    )?
    updates,
  ]) =>
      (AccountRecoveryReplacementCommitRequestAuthorizationOneOfBuilder()
            ..update(updates))
          ._build();

  _$AccountRecoveryReplacementCommitRequestAuthorizationOneOf._({
    required this.kind,
    required this.challengeRequestDigest,
  }) : super._();
  @override
  AccountRecoveryReplacementCommitRequestAuthorizationOneOf rebuild(
    void Function(
      AccountRecoveryReplacementCommitRequestAuthorizationOneOfBuilder,
    )
    updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  AccountRecoveryReplacementCommitRequestAuthorizationOneOfBuilder
  toBuilder() =>
      AccountRecoveryReplacementCommitRequestAuthorizationOneOfBuilder()
        ..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AccountRecoveryReplacementCommitRequestAuthorizationOneOf &&
        kind == other.kind &&
        challengeRequestDigest == other.challengeRequestDigest;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, kind.hashCode);
    _$hash = $jc(_$hash, challengeRequestDigest.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(
            r'AccountRecoveryReplacementCommitRequestAuthorizationOneOf',
          )
          ..add('kind', kind)
          ..add('challengeRequestDigest', challengeRequestDigest))
        .toString();
  }
}

class AccountRecoveryReplacementCommitRequestAuthorizationOneOfBuilder
    implements
        Builder<
          AccountRecoveryReplacementCommitRequestAuthorizationOneOf,
          AccountRecoveryReplacementCommitRequestAuthorizationOneOfBuilder
        > {
  _$AccountRecoveryReplacementCommitRequestAuthorizationOneOf? _$v;

  AccountRecoveryReplacementCommitRequestAuthorizationOneOfKindEnum? _kind;
  AccountRecoveryReplacementCommitRequestAuthorizationOneOfKindEnum? get kind =>
      _$this._kind;
  set kind(
    AccountRecoveryReplacementCommitRequestAuthorizationOneOfKindEnum? kind,
  ) => _$this._kind = kind;

  String? _challengeRequestDigest;
  String? get challengeRequestDigest => _$this._challengeRequestDigest;
  set challengeRequestDigest(String? challengeRequestDigest) =>
      _$this._challengeRequestDigest = challengeRequestDigest;

  AccountRecoveryReplacementCommitRequestAuthorizationOneOfBuilder() {
    AccountRecoveryReplacementCommitRequestAuthorizationOneOf._defaults(this);
  }

  AccountRecoveryReplacementCommitRequestAuthorizationOneOfBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _kind = $v.kind;
      _challengeRequestDigest = $v.challengeRequestDigest;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(
    AccountRecoveryReplacementCommitRequestAuthorizationOneOf other,
  ) {
    _$v = other as _$AccountRecoveryReplacementCommitRequestAuthorizationOneOf;
  }

  @override
  void update(
    void Function(
      AccountRecoveryReplacementCommitRequestAuthorizationOneOfBuilder,
    )?
    updates,
  ) {
    if (updates != null) updates(this);
  }

  @override
  AccountRecoveryReplacementCommitRequestAuthorizationOneOf build() => _build();

  _$AccountRecoveryReplacementCommitRequestAuthorizationOneOf _build() {
    final _$result =
        _$v ??
        _$AccountRecoveryReplacementCommitRequestAuthorizationOneOf._(
          kind: BuiltValueNullFieldError.checkNotNull(
            kind,
            r'AccountRecoveryReplacementCommitRequestAuthorizationOneOf',
            'kind',
          ),
          challengeRequestDigest: BuiltValueNullFieldError.checkNotNull(
            challengeRequestDigest,
            r'AccountRecoveryReplacementCommitRequestAuthorizationOneOf',
            'challengeRequestDigest',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
