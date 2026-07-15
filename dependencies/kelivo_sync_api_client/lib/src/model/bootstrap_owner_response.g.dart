// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bootstrap_owner_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$BootstrapOwnerResponse extends BootstrapOwnerResponse {
  @override
  final BootstrapOwnerData data;

  factory _$BootstrapOwnerResponse([
    void Function(BootstrapOwnerResponseBuilder)? updates,
  ]) => (BootstrapOwnerResponseBuilder()..update(updates))._build();

  _$BootstrapOwnerResponse._({required this.data}) : super._();
  @override
  BootstrapOwnerResponse rebuild(
    void Function(BootstrapOwnerResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  BootstrapOwnerResponseBuilder toBuilder() =>
      BootstrapOwnerResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is BootstrapOwnerResponse && data == other.data;
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
      r'BootstrapOwnerResponse',
    )..add('data', data)).toString();
  }
}

class BootstrapOwnerResponseBuilder
    implements Builder<BootstrapOwnerResponse, BootstrapOwnerResponseBuilder> {
  _$BootstrapOwnerResponse? _$v;

  BootstrapOwnerDataBuilder? _data;
  BootstrapOwnerDataBuilder get data =>
      _$this._data ??= BootstrapOwnerDataBuilder();
  set data(BootstrapOwnerDataBuilder? data) => _$this._data = data;

  BootstrapOwnerResponseBuilder() {
    BootstrapOwnerResponse._defaults(this);
  }

  BootstrapOwnerResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(BootstrapOwnerResponse other) {
    _$v = other as _$BootstrapOwnerResponse;
  }

  @override
  void update(void Function(BootstrapOwnerResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  BootstrapOwnerResponse build() => _build();

  _$BootstrapOwnerResponse _build() {
    _$BootstrapOwnerResponse _$result;
    try {
      _$result = _$v ?? _$BootstrapOwnerResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'BootstrapOwnerResponse',
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
