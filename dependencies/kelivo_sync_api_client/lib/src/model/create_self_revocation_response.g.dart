// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_self_revocation_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$CreateSelfRevocationResponse extends CreateSelfRevocationResponse {
  @override
  final SelfRevocationRequestData data;

  factory _$CreateSelfRevocationResponse([
    void Function(CreateSelfRevocationResponseBuilder)? updates,
  ]) => (CreateSelfRevocationResponseBuilder()..update(updates))._build();

  _$CreateSelfRevocationResponse._({required this.data}) : super._();
  @override
  CreateSelfRevocationResponse rebuild(
    void Function(CreateSelfRevocationResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  CreateSelfRevocationResponseBuilder toBuilder() =>
      CreateSelfRevocationResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is CreateSelfRevocationResponse && data == other.data;
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
      r'CreateSelfRevocationResponse',
    )..add('data', data)).toString();
  }
}

class CreateSelfRevocationResponseBuilder
    implements
        Builder<
          CreateSelfRevocationResponse,
          CreateSelfRevocationResponseBuilder
        > {
  _$CreateSelfRevocationResponse? _$v;

  SelfRevocationRequestDataBuilder? _data;
  SelfRevocationRequestDataBuilder get data =>
      _$this._data ??= SelfRevocationRequestDataBuilder();
  set data(SelfRevocationRequestDataBuilder? data) => _$this._data = data;

  CreateSelfRevocationResponseBuilder() {
    CreateSelfRevocationResponse._defaults(this);
  }

  CreateSelfRevocationResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(CreateSelfRevocationResponse other) {
    _$v = other as _$CreateSelfRevocationResponse;
  }

  @override
  void update(void Function(CreateSelfRevocationResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  CreateSelfRevocationResponse build() => _build();

  _$CreateSelfRevocationResponse _build() {
    _$CreateSelfRevocationResponse _$result;
    try {
      _$result = _$v ?? _$CreateSelfRevocationResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'CreateSelfRevocationResponse',
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
