// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_account_recovery_history_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ListAccountRecoveryHistoryResponse
    extends ListAccountRecoveryHistoryResponse {
  @override
  final AccountRecoveryHistoryListData data;

  factory _$ListAccountRecoveryHistoryResponse([
    void Function(ListAccountRecoveryHistoryResponseBuilder)? updates,
  ]) => (ListAccountRecoveryHistoryResponseBuilder()..update(updates))._build();

  _$ListAccountRecoveryHistoryResponse._({required this.data}) : super._();
  @override
  ListAccountRecoveryHistoryResponse rebuild(
    void Function(ListAccountRecoveryHistoryResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  ListAccountRecoveryHistoryResponseBuilder toBuilder() =>
      ListAccountRecoveryHistoryResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ListAccountRecoveryHistoryResponse && data == other.data;
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
      r'ListAccountRecoveryHistoryResponse',
    )..add('data', data)).toString();
  }
}

class ListAccountRecoveryHistoryResponseBuilder
    implements
        Builder<
          ListAccountRecoveryHistoryResponse,
          ListAccountRecoveryHistoryResponseBuilder
        > {
  _$ListAccountRecoveryHistoryResponse? _$v;

  AccountRecoveryHistoryListDataBuilder? _data;
  AccountRecoveryHistoryListDataBuilder get data =>
      _$this._data ??= AccountRecoveryHistoryListDataBuilder();
  set data(AccountRecoveryHistoryListDataBuilder? data) => _$this._data = data;

  ListAccountRecoveryHistoryResponseBuilder() {
    ListAccountRecoveryHistoryResponse._defaults(this);
  }

  ListAccountRecoveryHistoryResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ListAccountRecoveryHistoryResponse other) {
    _$v = other as _$ListAccountRecoveryHistoryResponse;
  }

  @override
  void update(
    void Function(ListAccountRecoveryHistoryResponseBuilder)? updates,
  ) {
    if (updates != null) updates(this);
  }

  @override
  ListAccountRecoveryHistoryResponse build() => _build();

  _$ListAccountRecoveryHistoryResponse _build() {
    _$ListAccountRecoveryHistoryResponse _$result;
    try {
      _$result =
          _$v ?? _$ListAccountRecoveryHistoryResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'ListAccountRecoveryHistoryResponse',
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
