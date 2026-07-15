// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'revoke_device_session_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$RevokeDeviceSessionResponse extends RevokeDeviceSessionResponse {
  @override
  final RevokeDeviceSessionData data;

  factory _$RevokeDeviceSessionResponse([
    void Function(RevokeDeviceSessionResponseBuilder)? updates,
  ]) => (RevokeDeviceSessionResponseBuilder()..update(updates))._build();

  _$RevokeDeviceSessionResponse._({required this.data}) : super._();
  @override
  RevokeDeviceSessionResponse rebuild(
    void Function(RevokeDeviceSessionResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  RevokeDeviceSessionResponseBuilder toBuilder() =>
      RevokeDeviceSessionResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is RevokeDeviceSessionResponse && data == other.data;
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
      r'RevokeDeviceSessionResponse',
    )..add('data', data)).toString();
  }
}

class RevokeDeviceSessionResponseBuilder
    implements
        Builder<
          RevokeDeviceSessionResponse,
          RevokeDeviceSessionResponseBuilder
        > {
  _$RevokeDeviceSessionResponse? _$v;

  RevokeDeviceSessionDataBuilder? _data;
  RevokeDeviceSessionDataBuilder get data =>
      _$this._data ??= RevokeDeviceSessionDataBuilder();
  set data(RevokeDeviceSessionDataBuilder? data) => _$this._data = data;

  RevokeDeviceSessionResponseBuilder() {
    RevokeDeviceSessionResponse._defaults(this);
  }

  RevokeDeviceSessionResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(RevokeDeviceSessionResponse other) {
    _$v = other as _$RevokeDeviceSessionResponse;
  }

  @override
  void update(void Function(RevokeDeviceSessionResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  RevokeDeviceSessionResponse build() => _build();

  _$RevokeDeviceSessionResponse _build() {
    _$RevokeDeviceSessionResponse _$result;
    try {
      _$result = _$v ?? _$RevokeDeviceSessionResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'RevokeDeviceSessionResponse',
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
