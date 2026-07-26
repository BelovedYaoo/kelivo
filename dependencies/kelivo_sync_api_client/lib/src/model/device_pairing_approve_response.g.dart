// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_pairing_approve_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$DevicePairingApproveResponse extends DevicePairingApproveResponse {
  @override
  final DevicePairingApproveData data;

  factory _$DevicePairingApproveResponse([
    void Function(DevicePairingApproveResponseBuilder)? updates,
  ]) => (DevicePairingApproveResponseBuilder()..update(updates))._build();

  _$DevicePairingApproveResponse._({required this.data}) : super._();
  @override
  DevicePairingApproveResponse rebuild(
    void Function(DevicePairingApproveResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  DevicePairingApproveResponseBuilder toBuilder() =>
      DevicePairingApproveResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DevicePairingApproveResponse && data == other.data;
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
      r'DevicePairingApproveResponse',
    )..add('data', data)).toString();
  }
}

class DevicePairingApproveResponseBuilder
    implements
        Builder<
          DevicePairingApproveResponse,
          DevicePairingApproveResponseBuilder
        > {
  _$DevicePairingApproveResponse? _$v;

  DevicePairingApproveDataBuilder? _data;
  DevicePairingApproveDataBuilder get data =>
      _$this._data ??= DevicePairingApproveDataBuilder();
  set data(DevicePairingApproveDataBuilder? data) => _$this._data = data;

  DevicePairingApproveResponseBuilder() {
    DevicePairingApproveResponse._defaults(this);
  }

  DevicePairingApproveResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DevicePairingApproveResponse other) {
    _$v = other as _$DevicePairingApproveResponse;
  }

  @override
  void update(void Function(DevicePairingApproveResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DevicePairingApproveResponse build() => _build();

  _$DevicePairingApproveResponse _build() {
    _$DevicePairingApproveResponse _$result;
    try {
      _$result = _$v ?? _$DevicePairingApproveResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'DevicePairingApproveResponse',
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
