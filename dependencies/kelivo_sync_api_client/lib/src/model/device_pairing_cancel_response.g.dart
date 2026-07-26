// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_pairing_cancel_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$DevicePairingCancelResponse extends DevicePairingCancelResponse {
  @override
  final DevicePairingCancelData data;

  factory _$DevicePairingCancelResponse([
    void Function(DevicePairingCancelResponseBuilder)? updates,
  ]) => (DevicePairingCancelResponseBuilder()..update(updates))._build();

  _$DevicePairingCancelResponse._({required this.data}) : super._();
  @override
  DevicePairingCancelResponse rebuild(
    void Function(DevicePairingCancelResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  DevicePairingCancelResponseBuilder toBuilder() =>
      DevicePairingCancelResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DevicePairingCancelResponse && data == other.data;
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
      r'DevicePairingCancelResponse',
    )..add('data', data)).toString();
  }
}

class DevicePairingCancelResponseBuilder
    implements
        Builder<
          DevicePairingCancelResponse,
          DevicePairingCancelResponseBuilder
        > {
  _$DevicePairingCancelResponse? _$v;

  DevicePairingCancelDataBuilder? _data;
  DevicePairingCancelDataBuilder get data =>
      _$this._data ??= DevicePairingCancelDataBuilder();
  set data(DevicePairingCancelDataBuilder? data) => _$this._data = data;

  DevicePairingCancelResponseBuilder() {
    DevicePairingCancelResponse._defaults(this);
  }

  DevicePairingCancelResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DevicePairingCancelResponse other) {
    _$v = other as _$DevicePairingCancelResponse;
  }

  @override
  void update(void Function(DevicePairingCancelResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DevicePairingCancelResponse build() => _build();

  _$DevicePairingCancelResponse _build() {
    _$DevicePairingCancelResponse _$result;
    try {
      _$result = _$v ?? _$DevicePairingCancelResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'DevicePairingCancelResponse',
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
