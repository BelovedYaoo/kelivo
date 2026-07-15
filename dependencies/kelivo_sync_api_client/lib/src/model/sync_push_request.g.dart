// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_push_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$SyncPushRequest extends SyncPushRequest {
  @override
  final BuiltList<SyncMutation> mutations;

  factory _$SyncPushRequest([void Function(SyncPushRequestBuilder)? updates]) =>
      (SyncPushRequestBuilder()..update(updates))._build();

  _$SyncPushRequest._({required this.mutations}) : super._();
  @override
  SyncPushRequest rebuild(void Function(SyncPushRequestBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  SyncPushRequestBuilder toBuilder() => SyncPushRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SyncPushRequest && mutations == other.mutations;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, mutations.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(
      r'SyncPushRequest',
    )..add('mutations', mutations)).toString();
  }
}

class SyncPushRequestBuilder
    implements Builder<SyncPushRequest, SyncPushRequestBuilder> {
  _$SyncPushRequest? _$v;

  ListBuilder<SyncMutation>? _mutations;
  ListBuilder<SyncMutation> get mutations =>
      _$this._mutations ??= ListBuilder<SyncMutation>();
  set mutations(ListBuilder<SyncMutation>? mutations) =>
      _$this._mutations = mutations;

  SyncPushRequestBuilder() {
    SyncPushRequest._defaults(this);
  }

  SyncPushRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _mutations = $v.mutations.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SyncPushRequest other) {
    _$v = other as _$SyncPushRequest;
  }

  @override
  void update(void Function(SyncPushRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SyncPushRequest build() => _build();

  _$SyncPushRequest _build() {
    _$SyncPushRequest _$result;
    try {
      _$result = _$v ?? _$SyncPushRequest._(mutations: mutations.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'mutations';
        mutations.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'SyncPushRequest',
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
