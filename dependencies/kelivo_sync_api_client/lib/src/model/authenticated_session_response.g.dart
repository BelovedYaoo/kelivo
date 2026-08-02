// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'authenticated_session_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$AuthenticatedSessionResponse extends AuthenticatedSessionResponse {
  @override
  final AuthenticatedSessionData data;

  factory _$AuthenticatedSessionResponse([
    void Function(AuthenticatedSessionResponseBuilder)? updates,
  ]) => (AuthenticatedSessionResponseBuilder()..update(updates))._build();

  _$AuthenticatedSessionResponse._({required this.data}) : super._();
  @override
  AuthenticatedSessionResponse rebuild(
    void Function(AuthenticatedSessionResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  AuthenticatedSessionResponseBuilder toBuilder() =>
      AuthenticatedSessionResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AuthenticatedSessionResponse && data == other.data;
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
      r'AuthenticatedSessionResponse',
    )..add('data', data)).toString();
  }
}

class AuthenticatedSessionResponseBuilder
    implements
        Builder<
          AuthenticatedSessionResponse,
          AuthenticatedSessionResponseBuilder
        > {
  _$AuthenticatedSessionResponse? _$v;

  AuthenticatedSessionDataBuilder? _data;
  AuthenticatedSessionDataBuilder get data =>
      _$this._data ??= AuthenticatedSessionDataBuilder();
  set data(AuthenticatedSessionDataBuilder? data) => _$this._data = data;

  AuthenticatedSessionResponseBuilder() {
    AuthenticatedSessionResponse._defaults(this);
  }

  AuthenticatedSessionResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AuthenticatedSessionResponse other) {
    _$v = other as _$AuthenticatedSessionResponse;
  }

  @override
  void update(void Function(AuthenticatedSessionResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  AuthenticatedSessionResponse build() => _build();

  _$AuthenticatedSessionResponse _build() {
    _$AuthenticatedSessionResponse _$result;
    try {
      _$result = _$v ?? _$AuthenticatedSessionResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'AuthenticatedSessionResponse',
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
