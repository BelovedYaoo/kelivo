// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_push_response_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$SyncPushResponseData extends SyncPushResponseData {
  @override
  final BuiltList<SyncMutationResult> results;

  factory _$SyncPushResponseData([
    void Function(SyncPushResponseDataBuilder)? updates,
  ]) => (SyncPushResponseDataBuilder()..update(updates))._build();

  _$SyncPushResponseData._({required this.results}) : super._();
  @override
  SyncPushResponseData rebuild(
    void Function(SyncPushResponseDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  SyncPushResponseDataBuilder toBuilder() =>
      SyncPushResponseDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SyncPushResponseData && results == other.results;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, results.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(
      r'SyncPushResponseData',
    )..add('results', results)).toString();
  }
}

class SyncPushResponseDataBuilder
    implements Builder<SyncPushResponseData, SyncPushResponseDataBuilder> {
  _$SyncPushResponseData? _$v;

  ListBuilder<SyncMutationResult>? _results;
  ListBuilder<SyncMutationResult> get results =>
      _$this._results ??= ListBuilder<SyncMutationResult>();
  set results(ListBuilder<SyncMutationResult>? results) =>
      _$this._results = results;

  SyncPushResponseDataBuilder() {
    SyncPushResponseData._defaults(this);
  }

  SyncPushResponseDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _results = $v.results.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SyncPushResponseData other) {
    _$v = other as _$SyncPushResponseData;
  }

  @override
  void update(void Function(SyncPushResponseDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SyncPushResponseData build() => _build();

  _$SyncPushResponseData _build() {
    _$SyncPushResponseData _$result;
    try {
      _$result = _$v ?? _$SyncPushResponseData._(results: results.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'results';
        results.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'SyncPushResponseData',
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
