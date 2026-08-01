// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'commit_account_recovery_resume_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$CommitAccountRecoveryResumeResponse
    extends CommitAccountRecoveryResumeResponse {
  @override
  final AccountRecoveryMembershipCommitData data;

  factory _$CommitAccountRecoveryResumeResponse([
    void Function(CommitAccountRecoveryResumeResponseBuilder)? updates,
  ]) =>
      (CommitAccountRecoveryResumeResponseBuilder()..update(updates))._build();

  _$CommitAccountRecoveryResumeResponse._({required this.data}) : super._();
  @override
  CommitAccountRecoveryResumeResponse rebuild(
    void Function(CommitAccountRecoveryResumeResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  CommitAccountRecoveryResumeResponseBuilder toBuilder() =>
      CommitAccountRecoveryResumeResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is CommitAccountRecoveryResumeResponse && data == other.data;
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
      r'CommitAccountRecoveryResumeResponse',
    )..add('data', data)).toString();
  }
}

class CommitAccountRecoveryResumeResponseBuilder
    implements
        Builder<
          CommitAccountRecoveryResumeResponse,
          CommitAccountRecoveryResumeResponseBuilder
        > {
  _$CommitAccountRecoveryResumeResponse? _$v;

  AccountRecoveryMembershipCommitDataBuilder? _data;
  AccountRecoveryMembershipCommitDataBuilder get data =>
      _$this._data ??= AccountRecoveryMembershipCommitDataBuilder();
  set data(AccountRecoveryMembershipCommitDataBuilder? data) =>
      _$this._data = data;

  CommitAccountRecoveryResumeResponseBuilder() {
    CommitAccountRecoveryResumeResponse._defaults(this);
  }

  CommitAccountRecoveryResumeResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(CommitAccountRecoveryResumeResponse other) {
    _$v = other as _$CommitAccountRecoveryResumeResponse;
  }

  @override
  void update(
    void Function(CommitAccountRecoveryResumeResponseBuilder)? updates,
  ) {
    if (updates != null) updates(this);
  }

  @override
  CommitAccountRecoveryResumeResponse build() => _build();

  _$CommitAccountRecoveryResumeResponse _build() {
    _$CommitAccountRecoveryResumeResponse _$result;
    try {
      _$result =
          _$v ?? _$CommitAccountRecoveryResumeResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'CommitAccountRecoveryResumeResponse',
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
