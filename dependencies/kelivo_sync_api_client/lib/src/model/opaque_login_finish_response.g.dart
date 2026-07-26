// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'opaque_login_finish_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$OpaqueLoginFinishResponse extends OpaqueLoginFinishResponse {
  @override
  final OpaqueLoginFinishData data;

  factory _$OpaqueLoginFinishResponse([
    void Function(OpaqueLoginFinishResponseBuilder)? updates,
  ]) => (OpaqueLoginFinishResponseBuilder()..update(updates))._build();

  _$OpaqueLoginFinishResponse._({required this.data}) : super._();
  @override
  OpaqueLoginFinishResponse rebuild(
    void Function(OpaqueLoginFinishResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  OpaqueLoginFinishResponseBuilder toBuilder() =>
      OpaqueLoginFinishResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is OpaqueLoginFinishResponse && data == other.data;
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
      r'OpaqueLoginFinishResponse',
    )..add('data', data)).toString();
  }
}

class OpaqueLoginFinishResponseBuilder
    implements
        Builder<OpaqueLoginFinishResponse, OpaqueLoginFinishResponseBuilder> {
  _$OpaqueLoginFinishResponse? _$v;

  OpaqueLoginFinishDataBuilder? _data;
  OpaqueLoginFinishDataBuilder get data =>
      _$this._data ??= OpaqueLoginFinishDataBuilder();
  set data(OpaqueLoginFinishDataBuilder? data) => _$this._data = data;

  OpaqueLoginFinishResponseBuilder() {
    OpaqueLoginFinishResponse._defaults(this);
  }

  OpaqueLoginFinishResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(OpaqueLoginFinishResponse other) {
    _$v = other as _$OpaqueLoginFinishResponse;
  }

  @override
  void update(void Function(OpaqueLoginFinishResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  OpaqueLoginFinishResponse build() => _build();

  _$OpaqueLoginFinishResponse _build() {
    _$OpaqueLoginFinishResponse _$result;
    try {
      _$result = _$v ?? _$OpaqueLoginFinishResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'OpaqueLoginFinishResponse',
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
