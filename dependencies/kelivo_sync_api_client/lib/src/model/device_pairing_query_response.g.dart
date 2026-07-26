// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_pairing_query_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$DevicePairingQueryResponse extends DevicePairingQueryResponse {
  @override
  final DevicePairingQueryData data;

  factory _$DevicePairingQueryResponse([
    void Function(DevicePairingQueryResponseBuilder)? updates,
  ]) => (DevicePairingQueryResponseBuilder()..update(updates))._build();

  _$DevicePairingQueryResponse._({required this.data}) : super._();
  @override
  DevicePairingQueryResponse rebuild(
    void Function(DevicePairingQueryResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  DevicePairingQueryResponseBuilder toBuilder() =>
      DevicePairingQueryResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DevicePairingQueryResponse && data == other.data;
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
      r'DevicePairingQueryResponse',
    )..add('data', data)).toString();
  }
}

class DevicePairingQueryResponseBuilder
    implements
        Builder<DevicePairingQueryResponse, DevicePairingQueryResponseBuilder> {
  _$DevicePairingQueryResponse? _$v;

  DevicePairingQueryDataBuilder? _data;
  DevicePairingQueryDataBuilder get data =>
      _$this._data ??= DevicePairingQueryDataBuilder();
  set data(DevicePairingQueryDataBuilder? data) => _$this._data = data;

  DevicePairingQueryResponseBuilder() {
    DevicePairingQueryResponse._defaults(this);
  }

  DevicePairingQueryResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DevicePairingQueryResponse other) {
    _$v = other as _$DevicePairingQueryResponse;
  }

  @override
  void update(void Function(DevicePairingQueryResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DevicePairingQueryResponse build() => _build();

  _$DevicePairingQueryResponse _build() {
    _$DevicePairingQueryResponse _$result;
    try {
      _$result = _$v ?? _$DevicePairingQueryResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'DevicePairingQueryResponse',
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
