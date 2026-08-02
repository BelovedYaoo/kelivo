// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_recovery_replacement_commit_request_authorization.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const AccountRecoveryReplacementCommitRequestAuthorizationKindEnum
_$accountRecoveryReplacementCommitRequestAuthorizationKindEnum_replacementChallenge =
    const AccountRecoveryReplacementCommitRequestAuthorizationKindEnum._(
      'replacementChallenge',
    );

AccountRecoveryReplacementCommitRequestAuthorizationKindEnum
_$accountRecoveryReplacementCommitRequestAuthorizationKindEnumValueOf(
  String name,
) {
  switch (name) {
    case 'replacementChallenge':
      return _$accountRecoveryReplacementCommitRequestAuthorizationKindEnum_replacementChallenge;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<AccountRecoveryReplacementCommitRequestAuthorizationKindEnum>
_$accountRecoveryReplacementCommitRequestAuthorizationKindEnumValues =
    BuiltSet<
      AccountRecoveryReplacementCommitRequestAuthorizationKindEnum
    >(const <AccountRecoveryReplacementCommitRequestAuthorizationKindEnum>[
      _$accountRecoveryReplacementCommitRequestAuthorizationKindEnum_replacementChallenge,
    ]);

Serializer<AccountRecoveryReplacementCommitRequestAuthorizationKindEnum>
_$accountRecoveryReplacementCommitRequestAuthorizationKindEnumSerializer =
    _$AccountRecoveryReplacementCommitRequestAuthorizationKindEnumSerializer();

class _$AccountRecoveryReplacementCommitRequestAuthorizationKindEnumSerializer
    implements
        PrimitiveSerializer<
          AccountRecoveryReplacementCommitRequestAuthorizationKindEnum
        > {
  static const Map<String, Object> _toWire = const <String, Object>{
    'replacementChallenge': 'replacement-challenge',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'replacement-challenge': 'replacementChallenge',
  };

  @override
  final Iterable<Type> types = const <Type>[
    AccountRecoveryReplacementCommitRequestAuthorizationKindEnum,
  ];
  @override
  final String wireName =
      'AccountRecoveryReplacementCommitRequestAuthorizationKindEnum';

  @override
  Object serialize(
    Serializers serializers,
    AccountRecoveryReplacementCommitRequestAuthorizationKindEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  AccountRecoveryReplacementCommitRequestAuthorizationKindEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => AccountRecoveryReplacementCommitRequestAuthorizationKindEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$AccountRecoveryReplacementCommitRequestAuthorization
    extends AccountRecoveryReplacementCommitRequestAuthorization {
  @override
  final OneOf oneOf;

  factory _$AccountRecoveryReplacementCommitRequestAuthorization([
    void Function(AccountRecoveryReplacementCommitRequestAuthorizationBuilder)?
    updates,
  ]) =>
      (AccountRecoveryReplacementCommitRequestAuthorizationBuilder()
            ..update(updates))
          ._build();

  _$AccountRecoveryReplacementCommitRequestAuthorization._({
    required this.oneOf,
  }) : super._();
  @override
  AccountRecoveryReplacementCommitRequestAuthorization rebuild(
    void Function(AccountRecoveryReplacementCommitRequestAuthorizationBuilder)
    updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  AccountRecoveryReplacementCommitRequestAuthorizationBuilder toBuilder() =>
      AccountRecoveryReplacementCommitRequestAuthorizationBuilder()
        ..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AccountRecoveryReplacementCommitRequestAuthorization &&
        oneOf == other.oneOf;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, oneOf.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(
      r'AccountRecoveryReplacementCommitRequestAuthorization',
    )..add('oneOf', oneOf)).toString();
  }
}

class AccountRecoveryReplacementCommitRequestAuthorizationBuilder
    implements
        Builder<
          AccountRecoveryReplacementCommitRequestAuthorization,
          AccountRecoveryReplacementCommitRequestAuthorizationBuilder
        > {
  _$AccountRecoveryReplacementCommitRequestAuthorization? _$v;

  OneOf? _oneOf;
  OneOf? get oneOf => _$this._oneOf;
  set oneOf(OneOf? oneOf) => _$this._oneOf = oneOf;

  AccountRecoveryReplacementCommitRequestAuthorizationBuilder() {
    AccountRecoveryReplacementCommitRequestAuthorization._defaults(this);
  }

  AccountRecoveryReplacementCommitRequestAuthorizationBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _oneOf = $v.oneOf;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AccountRecoveryReplacementCommitRequestAuthorization other) {
    _$v = other as _$AccountRecoveryReplacementCommitRequestAuthorization;
  }

  @override
  void update(
    void Function(AccountRecoveryReplacementCommitRequestAuthorizationBuilder)?
    updates,
  ) {
    if (updates != null) updates(this);
  }

  @override
  AccountRecoveryReplacementCommitRequestAuthorization build() => _build();

  _$AccountRecoveryReplacementCommitRequestAuthorization _build() {
    final _$result =
        _$v ??
        _$AccountRecoveryReplacementCommitRequestAuthorization._(
          oneOf: BuiltValueNullFieldError.checkNotNull(
            oneOf,
            r'AccountRecoveryReplacementCommitRequestAuthorization',
            'oneOf',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
