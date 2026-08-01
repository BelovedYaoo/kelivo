// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_recovery_attempt_start_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const AccountRecoveryAttemptStartRequestActionEnum
_$accountRecoveryAttemptStartRequestActionEnum_authorize =
    const AccountRecoveryAttemptStartRequestActionEnum._('authorize');

AccountRecoveryAttemptStartRequestActionEnum
_$accountRecoveryAttemptStartRequestActionEnumValueOf(String name) {
  switch (name) {
    case 'authorize':
      return _$accountRecoveryAttemptStartRequestActionEnum_authorize;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<AccountRecoveryAttemptStartRequestActionEnum>
_$accountRecoveryAttemptStartRequestActionEnumValues =
    BuiltSet<AccountRecoveryAttemptStartRequestActionEnum>(
      const <AccountRecoveryAttemptStartRequestActionEnum>[
        _$accountRecoveryAttemptStartRequestActionEnum_authorize,
      ],
    );

Serializer<AccountRecoveryAttemptStartRequestActionEnum>
_$accountRecoveryAttemptStartRequestActionEnumSerializer =
    _$AccountRecoveryAttemptStartRequestActionEnumSerializer();

class _$AccountRecoveryAttemptStartRequestActionEnumSerializer
    implements
        PrimitiveSerializer<AccountRecoveryAttemptStartRequestActionEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'authorize': 'authorize',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'authorize': 'authorize',
  };

  @override
  final Iterable<Type> types = const <Type>[
    AccountRecoveryAttemptStartRequestActionEnum,
  ];
  @override
  final String wireName = 'AccountRecoveryAttemptStartRequestActionEnum';

  @override
  Object serialize(
    Serializers serializers,
    AccountRecoveryAttemptStartRequestActionEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  AccountRecoveryAttemptStartRequestActionEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => AccountRecoveryAttemptStartRequestActionEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$AccountRecoveryAttemptStartRequest
    extends AccountRecoveryAttemptStartRequest {
  @override
  final OneOf oneOf;

  factory _$AccountRecoveryAttemptStartRequest([
    void Function(AccountRecoveryAttemptStartRequestBuilder)? updates,
  ]) => (AccountRecoveryAttemptStartRequestBuilder()..update(updates))._build();

  _$AccountRecoveryAttemptStartRequest._({required this.oneOf}) : super._();
  @override
  AccountRecoveryAttemptStartRequest rebuild(
    void Function(AccountRecoveryAttemptStartRequestBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  AccountRecoveryAttemptStartRequestBuilder toBuilder() =>
      AccountRecoveryAttemptStartRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AccountRecoveryAttemptStartRequest && oneOf == other.oneOf;
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
      r'AccountRecoveryAttemptStartRequest',
    )..add('oneOf', oneOf)).toString();
  }
}

class AccountRecoveryAttemptStartRequestBuilder
    implements
        Builder<
          AccountRecoveryAttemptStartRequest,
          AccountRecoveryAttemptStartRequestBuilder
        > {
  _$AccountRecoveryAttemptStartRequest? _$v;

  OneOf? _oneOf;
  OneOf? get oneOf => _$this._oneOf;
  set oneOf(OneOf? oneOf) => _$this._oneOf = oneOf;

  AccountRecoveryAttemptStartRequestBuilder() {
    AccountRecoveryAttemptStartRequest._defaults(this);
  }

  AccountRecoveryAttemptStartRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _oneOf = $v.oneOf;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AccountRecoveryAttemptStartRequest other) {
    _$v = other as _$AccountRecoveryAttemptStartRequest;
  }

  @override
  void update(
    void Function(AccountRecoveryAttemptStartRequestBuilder)? updates,
  ) {
    if (updates != null) updates(this);
  }

  @override
  AccountRecoveryAttemptStartRequest build() => _build();

  _$AccountRecoveryAttemptStartRequest _build() {
    final _$result =
        _$v ??
        _$AccountRecoveryAttemptStartRequest._(
          oneOf: BuiltValueNullFieldError.checkNotNull(
            oneOf,
            r'AccountRecoveryAttemptStartRequest',
            'oneOf',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
