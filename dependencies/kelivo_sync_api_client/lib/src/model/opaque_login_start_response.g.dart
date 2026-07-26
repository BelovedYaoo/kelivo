// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'opaque_login_start_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$OpaqueLoginStartResponse extends OpaqueLoginStartResponse {
  @override
  final OpaqueLoginStartData data;

  factory _$OpaqueLoginStartResponse([
    void Function(OpaqueLoginStartResponseBuilder)? updates,
  ]) => (OpaqueLoginStartResponseBuilder()..update(updates))._build();

  _$OpaqueLoginStartResponse._({required this.data}) : super._();
  @override
  OpaqueLoginStartResponse rebuild(
    void Function(OpaqueLoginStartResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  OpaqueLoginStartResponseBuilder toBuilder() =>
      OpaqueLoginStartResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is OpaqueLoginStartResponse && data == other.data;
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
      r'OpaqueLoginStartResponse',
    )..add('data', data)).toString();
  }
}

class OpaqueLoginStartResponseBuilder
    implements
        Builder<OpaqueLoginStartResponse, OpaqueLoginStartResponseBuilder> {
  _$OpaqueLoginStartResponse? _$v;

  OpaqueLoginStartDataBuilder? _data;
  OpaqueLoginStartDataBuilder get data =>
      _$this._data ??= OpaqueLoginStartDataBuilder();
  set data(OpaqueLoginStartDataBuilder? data) => _$this._data = data;

  OpaqueLoginStartResponseBuilder() {
    OpaqueLoginStartResponse._defaults(this);
  }

  OpaqueLoginStartResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(OpaqueLoginStartResponse other) {
    _$v = other as _$OpaqueLoginStartResponse;
  }

  @override
  void update(void Function(OpaqueLoginStartResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  OpaqueLoginStartResponse build() => _build();

  _$OpaqueLoginStartResponse _build() {
    _$OpaqueLoginStartResponse _$result;
    try {
      _$result = _$v ?? _$OpaqueLoginStartResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'OpaqueLoginStartResponse',
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
