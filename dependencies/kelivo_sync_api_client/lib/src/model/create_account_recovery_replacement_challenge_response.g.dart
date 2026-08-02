// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_account_recovery_replacement_challenge_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$CreateAccountRecoveryReplacementChallengeResponse
    extends CreateAccountRecoveryReplacementChallengeResponse {
  @override
  final AccountRecoveryReplacementChallengeData data;

  factory _$CreateAccountRecoveryReplacementChallengeResponse([
    void Function(CreateAccountRecoveryReplacementChallengeResponseBuilder)?
    updates,
  ]) =>
      (CreateAccountRecoveryReplacementChallengeResponseBuilder()
            ..update(updates))
          ._build();

  _$CreateAccountRecoveryReplacementChallengeResponse._({required this.data})
    : super._();
  @override
  CreateAccountRecoveryReplacementChallengeResponse rebuild(
    void Function(CreateAccountRecoveryReplacementChallengeResponseBuilder)
    updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  CreateAccountRecoveryReplacementChallengeResponseBuilder toBuilder() =>
      CreateAccountRecoveryReplacementChallengeResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is CreateAccountRecoveryReplacementChallengeResponse &&
        data == other.data;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, data.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(
      r'CreateAccountRecoveryReplacementChallengeResponse',
    )..add('data', data)).toString();
  }
}

class CreateAccountRecoveryReplacementChallengeResponseBuilder
    implements
        Builder<
          CreateAccountRecoveryReplacementChallengeResponse,
          CreateAccountRecoveryReplacementChallengeResponseBuilder
        > {
  _$CreateAccountRecoveryReplacementChallengeResponse? _$v;

  AccountRecoveryReplacementChallengeDataBuilder? _data;
  AccountRecoveryReplacementChallengeDataBuilder get data =>
      _$this._data ??= AccountRecoveryReplacementChallengeDataBuilder();
  set data(AccountRecoveryReplacementChallengeDataBuilder? data) =>
      _$this._data = data;

  CreateAccountRecoveryReplacementChallengeResponseBuilder() {
    CreateAccountRecoveryReplacementChallengeResponse._defaults(this);
  }

  CreateAccountRecoveryReplacementChallengeResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(CreateAccountRecoveryReplacementChallengeResponse other) {
    _$v = other as _$CreateAccountRecoveryReplacementChallengeResponse;
  }

  @override
  void update(
    void Function(CreateAccountRecoveryReplacementChallengeResponseBuilder)?
    updates,
  ) {
    if (updates != null) updates(this);
  }

  @override
  CreateAccountRecoveryReplacementChallengeResponse build() => _build();

  _$CreateAccountRecoveryReplacementChallengeResponse _build() {
    _$CreateAccountRecoveryReplacementChallengeResponse _$result;
    try {
      _$result =
          _$v ??
          _$CreateAccountRecoveryReplacementChallengeResponse._(
            data: data.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'CreateAccountRecoveryReplacementChallengeResponse',
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
