// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'system_health_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$SystemHealthResponse extends SystemHealthResponse {
  @override
  final SystemHealthData data;

  factory _$SystemHealthResponse([
    void Function(SystemHealthResponseBuilder)? updates,
  ]) => (SystemHealthResponseBuilder()..update(updates))._build();

  _$SystemHealthResponse._({required this.data}) : super._();
  @override
  SystemHealthResponse rebuild(
    void Function(SystemHealthResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  SystemHealthResponseBuilder toBuilder() =>
      SystemHealthResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SystemHealthResponse && data == other.data;
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
      r'SystemHealthResponse',
    )..add('data', data)).toString();
  }
}

class SystemHealthResponseBuilder
    implements Builder<SystemHealthResponse, SystemHealthResponseBuilder> {
  _$SystemHealthResponse? _$v;

  SystemHealthDataBuilder? _data;
  SystemHealthDataBuilder get data =>
      _$this._data ??= SystemHealthDataBuilder();
  set data(SystemHealthDataBuilder? data) => _$this._data = data;

  SystemHealthResponseBuilder() {
    SystemHealthResponse._defaults(this);
  }

  SystemHealthResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SystemHealthResponse other) {
    _$v = other as _$SystemHealthResponse;
  }

  @override
  void update(void Function(SystemHealthResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SystemHealthResponse build() => _build();

  _$SystemHealthResponse _build() {
    _$SystemHealthResponse _$result;
    try {
      _$result = _$v ?? _$SystemHealthResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'SystemHealthResponse',
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
