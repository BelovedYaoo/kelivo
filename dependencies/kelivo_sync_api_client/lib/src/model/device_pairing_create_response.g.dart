// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_pairing_create_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$DevicePairingCreateResponse extends DevicePairingCreateResponse {
  @override
  final DevicePairingCreateData data;

  factory _$DevicePairingCreateResponse([
    void Function(DevicePairingCreateResponseBuilder)? updates,
  ]) => (DevicePairingCreateResponseBuilder()..update(updates))._build();

  _$DevicePairingCreateResponse._({required this.data}) : super._();
  @override
  DevicePairingCreateResponse rebuild(
    void Function(DevicePairingCreateResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  DevicePairingCreateResponseBuilder toBuilder() =>
      DevicePairingCreateResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DevicePairingCreateResponse && data == other.data;
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
      r'DevicePairingCreateResponse',
    )..add('data', data)).toString();
  }
}

class DevicePairingCreateResponseBuilder
    implements
        Builder<
          DevicePairingCreateResponse,
          DevicePairingCreateResponseBuilder
        > {
  _$DevicePairingCreateResponse? _$v;

  DevicePairingCreateDataBuilder? _data;
  DevicePairingCreateDataBuilder get data =>
      _$this._data ??= DevicePairingCreateDataBuilder();
  set data(DevicePairingCreateDataBuilder? data) => _$this._data = data;

  DevicePairingCreateResponseBuilder() {
    DevicePairingCreateResponse._defaults(this);
  }

  DevicePairingCreateResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DevicePairingCreateResponse other) {
    _$v = other as _$DevicePairingCreateResponse;
  }

  @override
  void update(void Function(DevicePairingCreateResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DevicePairingCreateResponse build() => _build();

  _$DevicePairingCreateResponse _build() {
    _$DevicePairingCreateResponse _$result;
    try {
      _$result = _$v ?? _$DevicePairingCreateResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'DevicePairingCreateResponse',
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
