// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_pairing_consume_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$DevicePairingConsumeResponse extends DevicePairingConsumeResponse {
  @override
  final DevicePairingConsumeData data;

  factory _$DevicePairingConsumeResponse([
    void Function(DevicePairingConsumeResponseBuilder)? updates,
  ]) => (DevicePairingConsumeResponseBuilder()..update(updates))._build();

  _$DevicePairingConsumeResponse._({required this.data}) : super._();
  @override
  DevicePairingConsumeResponse rebuild(
    void Function(DevicePairingConsumeResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  DevicePairingConsumeResponseBuilder toBuilder() =>
      DevicePairingConsumeResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DevicePairingConsumeResponse && data == other.data;
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
      r'DevicePairingConsumeResponse',
    )..add('data', data)).toString();
  }
}

class DevicePairingConsumeResponseBuilder
    implements
        Builder<
          DevicePairingConsumeResponse,
          DevicePairingConsumeResponseBuilder
        > {
  _$DevicePairingConsumeResponse? _$v;

  DevicePairingConsumeDataBuilder? _data;
  DevicePairingConsumeDataBuilder get data =>
      _$this._data ??= DevicePairingConsumeDataBuilder();
  set data(DevicePairingConsumeDataBuilder? data) => _$this._data = data;

  DevicePairingConsumeResponseBuilder() {
    DevicePairingConsumeResponse._defaults(this);
  }

  DevicePairingConsumeResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DevicePairingConsumeResponse other) {
    _$v = other as _$DevicePairingConsumeResponse;
  }

  @override
  void update(void Function(DevicePairingConsumeResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DevicePairingConsumeResponse build() => _build();

  _$DevicePairingConsumeResponse _build() {
    _$DevicePairingConsumeResponse _$result;
    try {
      _$result = _$v ?? _$DevicePairingConsumeResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'DevicePairingConsumeResponse',
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
