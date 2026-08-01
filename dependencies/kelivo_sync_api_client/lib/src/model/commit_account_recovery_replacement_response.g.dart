// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'commit_account_recovery_replacement_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$CommitAccountRecoveryReplacementResponse
    extends CommitAccountRecoveryReplacementResponse {
  @override
  final AccountRecoveryMembershipCommitData data;

  factory _$CommitAccountRecoveryReplacementResponse([
    void Function(CommitAccountRecoveryReplacementResponseBuilder)? updates,
  ]) => (CommitAccountRecoveryReplacementResponseBuilder()..update(updates))
      ._build();

  _$CommitAccountRecoveryReplacementResponse._({required this.data})
    : super._();
  @override
  CommitAccountRecoveryReplacementResponse rebuild(
    void Function(CommitAccountRecoveryReplacementResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  CommitAccountRecoveryReplacementResponseBuilder toBuilder() =>
      CommitAccountRecoveryReplacementResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is CommitAccountRecoveryReplacementResponse &&
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
      r'CommitAccountRecoveryReplacementResponse',
    )..add('data', data)).toString();
  }
}

class CommitAccountRecoveryReplacementResponseBuilder
    implements
        Builder<
          CommitAccountRecoveryReplacementResponse,
          CommitAccountRecoveryReplacementResponseBuilder
        > {
  _$CommitAccountRecoveryReplacementResponse? _$v;

  AccountRecoveryMembershipCommitDataBuilder? _data;
  AccountRecoveryMembershipCommitDataBuilder get data =>
      _$this._data ??= AccountRecoveryMembershipCommitDataBuilder();
  set data(AccountRecoveryMembershipCommitDataBuilder? data) =>
      _$this._data = data;

  CommitAccountRecoveryReplacementResponseBuilder() {
    CommitAccountRecoveryReplacementResponse._defaults(this);
  }

  CommitAccountRecoveryReplacementResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(CommitAccountRecoveryReplacementResponse other) {
    _$v = other as _$CommitAccountRecoveryReplacementResponse;
  }

  @override
  void update(
    void Function(CommitAccountRecoveryReplacementResponseBuilder)? updates,
  ) {
    if (updates != null) updates(this);
  }

  @override
  CommitAccountRecoveryReplacementResponse build() => _build();

  _$CommitAccountRecoveryReplacementResponse _build() {
    _$CommitAccountRecoveryReplacementResponse _$result;
    try {
      _$result =
          _$v ??
          _$CommitAccountRecoveryReplacementResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'CommitAccountRecoveryReplacementResponse',
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
