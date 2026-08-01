// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_recovery_history_list_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$AccountRecoveryHistoryListRequest
    extends AccountRecoveryHistoryListRequest {
  @override
  final int afterGeneration;
  @override
  final int pageSize;
  @override
  final String attemptId;
  @override
  final String challengeRequestDigest;

  factory _$AccountRecoveryHistoryListRequest([
    void Function(AccountRecoveryHistoryListRequestBuilder)? updates,
  ]) => (AccountRecoveryHistoryListRequestBuilder()..update(updates))._build();

  _$AccountRecoveryHistoryListRequest._({
    required this.afterGeneration,
    required this.pageSize,
    required this.attemptId,
    required this.challengeRequestDigest,
  }) : super._();
  @override
  AccountRecoveryHistoryListRequest rebuild(
    void Function(AccountRecoveryHistoryListRequestBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  AccountRecoveryHistoryListRequestBuilder toBuilder() =>
      AccountRecoveryHistoryListRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AccountRecoveryHistoryListRequest &&
        afterGeneration == other.afterGeneration &&
        pageSize == other.pageSize &&
        attemptId == other.attemptId &&
        challengeRequestDigest == other.challengeRequestDigest;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, afterGeneration.hashCode);
    _$hash = $jc(_$hash, pageSize.hashCode);
    _$hash = $jc(_$hash, attemptId.hashCode);
    _$hash = $jc(_$hash, challengeRequestDigest.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'AccountRecoveryHistoryListRequest')
          ..add('afterGeneration', afterGeneration)
          ..add('pageSize', pageSize)
          ..add('attemptId', attemptId)
          ..add('challengeRequestDigest', challengeRequestDigest))
        .toString();
  }
}

class AccountRecoveryHistoryListRequestBuilder
    implements
        Builder<
          AccountRecoveryHistoryListRequest,
          AccountRecoveryHistoryListRequestBuilder
        > {
  _$AccountRecoveryHistoryListRequest? _$v;

  int? _afterGeneration;
  int? get afterGeneration => _$this._afterGeneration;
  set afterGeneration(int? afterGeneration) =>
      _$this._afterGeneration = afterGeneration;

  int? _pageSize;
  int? get pageSize => _$this._pageSize;
  set pageSize(int? pageSize) => _$this._pageSize = pageSize;

  String? _attemptId;
  String? get attemptId => _$this._attemptId;
  set attemptId(String? attemptId) => _$this._attemptId = attemptId;

  String? _challengeRequestDigest;
  String? get challengeRequestDigest => _$this._challengeRequestDigest;
  set challengeRequestDigest(String? challengeRequestDigest) =>
      _$this._challengeRequestDigest = challengeRequestDigest;

  AccountRecoveryHistoryListRequestBuilder() {
    AccountRecoveryHistoryListRequest._defaults(this);
  }

  AccountRecoveryHistoryListRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _afterGeneration = $v.afterGeneration;
      _pageSize = $v.pageSize;
      _attemptId = $v.attemptId;
      _challengeRequestDigest = $v.challengeRequestDigest;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AccountRecoveryHistoryListRequest other) {
    _$v = other as _$AccountRecoveryHistoryListRequest;
  }

  @override
  void update(
    void Function(AccountRecoveryHistoryListRequestBuilder)? updates,
  ) {
    if (updates != null) updates(this);
  }

  @override
  AccountRecoveryHistoryListRequest build() => _build();

  _$AccountRecoveryHistoryListRequest _build() {
    final _$result =
        _$v ??
        _$AccountRecoveryHistoryListRequest._(
          afterGeneration: BuiltValueNullFieldError.checkNotNull(
            afterGeneration,
            r'AccountRecoveryHistoryListRequest',
            'afterGeneration',
          ),
          pageSize: BuiltValueNullFieldError.checkNotNull(
            pageSize,
            r'AccountRecoveryHistoryListRequest',
            'pageSize',
          ),
          attemptId: BuiltValueNullFieldError.checkNotNull(
            attemptId,
            r'AccountRecoveryHistoryListRequest',
            'attemptId',
          ),
          challengeRequestDigest: BuiltValueNullFieldError.checkNotNull(
            challengeRequestDigest,
            r'AccountRecoveryHistoryListRequest',
            'challengeRequestDigest',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
