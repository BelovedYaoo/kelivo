// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'opaque_registration_finish_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$OpaqueRegistrationFinishResponse
    extends OpaqueRegistrationFinishResponse {
  @override
  final OpaqueRegistrationFinishData data;

  factory _$OpaqueRegistrationFinishResponse([
    void Function(OpaqueRegistrationFinishResponseBuilder)? updates,
  ]) => (OpaqueRegistrationFinishResponseBuilder()..update(updates))._build();

  _$OpaqueRegistrationFinishResponse._({required this.data}) : super._();
  @override
  OpaqueRegistrationFinishResponse rebuild(
    void Function(OpaqueRegistrationFinishResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  OpaqueRegistrationFinishResponseBuilder toBuilder() =>
      OpaqueRegistrationFinishResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is OpaqueRegistrationFinishResponse && data == other.data;
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
      r'OpaqueRegistrationFinishResponse',
    )..add('data', data)).toString();
  }
}

class OpaqueRegistrationFinishResponseBuilder
    implements
        Builder<
          OpaqueRegistrationFinishResponse,
          OpaqueRegistrationFinishResponseBuilder
        > {
  _$OpaqueRegistrationFinishResponse? _$v;

  OpaqueRegistrationFinishDataBuilder? _data;
  OpaqueRegistrationFinishDataBuilder get data =>
      _$this._data ??= OpaqueRegistrationFinishDataBuilder();
  set data(OpaqueRegistrationFinishDataBuilder? data) => _$this._data = data;

  OpaqueRegistrationFinishResponseBuilder() {
    OpaqueRegistrationFinishResponse._defaults(this);
  }

  OpaqueRegistrationFinishResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(OpaqueRegistrationFinishResponse other) {
    _$v = other as _$OpaqueRegistrationFinishResponse;
  }

  @override
  void update(void Function(OpaqueRegistrationFinishResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  OpaqueRegistrationFinishResponse build() => _build();

  _$OpaqueRegistrationFinishResponse _build() {
    _$OpaqueRegistrationFinishResponse _$result;
    try {
      _$result =
          _$v ?? _$OpaqueRegistrationFinishResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'OpaqueRegistrationFinishResponse',
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
