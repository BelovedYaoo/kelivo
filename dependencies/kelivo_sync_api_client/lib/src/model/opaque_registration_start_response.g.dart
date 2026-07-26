// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'opaque_registration_start_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$OpaqueRegistrationStartResponse
    extends OpaqueRegistrationStartResponse {
  @override
  final OpaqueRegistrationStartData data;

  factory _$OpaqueRegistrationStartResponse([
    void Function(OpaqueRegistrationStartResponseBuilder)? updates,
  ]) => (OpaqueRegistrationStartResponseBuilder()..update(updates))._build();

  _$OpaqueRegistrationStartResponse._({required this.data}) : super._();
  @override
  OpaqueRegistrationStartResponse rebuild(
    void Function(OpaqueRegistrationStartResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  OpaqueRegistrationStartResponseBuilder toBuilder() =>
      OpaqueRegistrationStartResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is OpaqueRegistrationStartResponse && data == other.data;
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
      r'OpaqueRegistrationStartResponse',
    )..add('data', data)).toString();
  }
}

class OpaqueRegistrationStartResponseBuilder
    implements
        Builder<
          OpaqueRegistrationStartResponse,
          OpaqueRegistrationStartResponseBuilder
        > {
  _$OpaqueRegistrationStartResponse? _$v;

  OpaqueRegistrationStartDataBuilder? _data;
  OpaqueRegistrationStartDataBuilder get data =>
      _$this._data ??= OpaqueRegistrationStartDataBuilder();
  set data(OpaqueRegistrationStartDataBuilder? data) => _$this._data = data;

  OpaqueRegistrationStartResponseBuilder() {
    OpaqueRegistrationStartResponse._defaults(this);
  }

  OpaqueRegistrationStartResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(OpaqueRegistrationStartResponse other) {
    _$v = other as _$OpaqueRegistrationStartResponse;
  }

  @override
  void update(void Function(OpaqueRegistrationStartResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  OpaqueRegistrationStartResponse build() => _build();

  _$OpaqueRegistrationStartResponse _build() {
    _$OpaqueRegistrationStartResponse _$result;
    try {
      _$result = _$v ?? _$OpaqueRegistrationStartResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'OpaqueRegistrationStartResponse',
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
