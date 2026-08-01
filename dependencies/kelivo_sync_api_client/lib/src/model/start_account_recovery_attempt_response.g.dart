// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'start_account_recovery_attempt_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$StartAccountRecoveryAttemptResponse
    extends StartAccountRecoveryAttemptResponse {
  @override
  final AccountRecoveryAttemptStartData data;

  factory _$StartAccountRecoveryAttemptResponse([
    void Function(StartAccountRecoveryAttemptResponseBuilder)? updates,
  ]) =>
      (StartAccountRecoveryAttemptResponseBuilder()..update(updates))._build();

  _$StartAccountRecoveryAttemptResponse._({required this.data}) : super._();
  @override
  StartAccountRecoveryAttemptResponse rebuild(
    void Function(StartAccountRecoveryAttemptResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  StartAccountRecoveryAttemptResponseBuilder toBuilder() =>
      StartAccountRecoveryAttemptResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is StartAccountRecoveryAttemptResponse && data == other.data;
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
      r'StartAccountRecoveryAttemptResponse',
    )..add('data', data)).toString();
  }
}

class StartAccountRecoveryAttemptResponseBuilder
    implements
        Builder<
          StartAccountRecoveryAttemptResponse,
          StartAccountRecoveryAttemptResponseBuilder
        > {
  _$StartAccountRecoveryAttemptResponse? _$v;

  AccountRecoveryAttemptStartDataBuilder? _data;
  AccountRecoveryAttemptStartDataBuilder get data =>
      _$this._data ??= AccountRecoveryAttemptStartDataBuilder();
  set data(AccountRecoveryAttemptStartDataBuilder? data) => _$this._data = data;

  StartAccountRecoveryAttemptResponseBuilder() {
    StartAccountRecoveryAttemptResponse._defaults(this);
  }

  StartAccountRecoveryAttemptResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(StartAccountRecoveryAttemptResponse other) {
    _$v = other as _$StartAccountRecoveryAttemptResponse;
  }

  @override
  void update(
    void Function(StartAccountRecoveryAttemptResponseBuilder)? updates,
  ) {
    if (updates != null) updates(this);
  }

  @override
  StartAccountRecoveryAttemptResponse build() => _build();

  _$StartAccountRecoveryAttemptResponse _build() {
    _$StartAccountRecoveryAttemptResponse _$result;
    try {
      _$result =
          _$v ?? _$StartAccountRecoveryAttemptResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'StartAccountRecoveryAttemptResponse',
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
