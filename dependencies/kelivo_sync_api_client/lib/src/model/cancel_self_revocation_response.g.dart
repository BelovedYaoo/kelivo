// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cancel_self_revocation_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$CancelSelfRevocationResponse extends CancelSelfRevocationResponse {
  @override
  final SelfRevocationStatusData data;

  factory _$CancelSelfRevocationResponse([
    void Function(CancelSelfRevocationResponseBuilder)? updates,
  ]) => (CancelSelfRevocationResponseBuilder()..update(updates))._build();

  _$CancelSelfRevocationResponse._({required this.data}) : super._();
  @override
  CancelSelfRevocationResponse rebuild(
    void Function(CancelSelfRevocationResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  CancelSelfRevocationResponseBuilder toBuilder() =>
      CancelSelfRevocationResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is CancelSelfRevocationResponse && data == other.data;
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
      r'CancelSelfRevocationResponse',
    )..add('data', data)).toString();
  }
}

class CancelSelfRevocationResponseBuilder
    implements
        Builder<
          CancelSelfRevocationResponse,
          CancelSelfRevocationResponseBuilder
        > {
  _$CancelSelfRevocationResponse? _$v;

  SelfRevocationStatusDataBuilder? _data;
  SelfRevocationStatusDataBuilder get data =>
      _$this._data ??= SelfRevocationStatusDataBuilder();
  set data(SelfRevocationStatusDataBuilder? data) => _$this._data = data;

  CancelSelfRevocationResponseBuilder() {
    CancelSelfRevocationResponse._defaults(this);
  }

  CancelSelfRevocationResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(CancelSelfRevocationResponse other) {
    _$v = other as _$CancelSelfRevocationResponse;
  }

  @override
  void update(void Function(CancelSelfRevocationResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  CancelSelfRevocationResponse build() => _build();

  _$CancelSelfRevocationResponse _build() {
    _$CancelSelfRevocationResponse _$result;
    try {
      _$result = _$v ?? _$CancelSelfRevocationResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'CancelSelfRevocationResponse',
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
