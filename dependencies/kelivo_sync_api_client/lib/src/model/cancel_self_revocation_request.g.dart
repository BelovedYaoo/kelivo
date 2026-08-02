// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cancel_self_revocation_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$CancelSelfRevocationRequest extends CancelSelfRevocationRequest {
  @override
  final String mutationId;

  factory _$CancelSelfRevocationRequest([
    void Function(CancelSelfRevocationRequestBuilder)? updates,
  ]) => (CancelSelfRevocationRequestBuilder()..update(updates))._build();

  _$CancelSelfRevocationRequest._({required this.mutationId}) : super._();
  @override
  CancelSelfRevocationRequest rebuild(
    void Function(CancelSelfRevocationRequestBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  CancelSelfRevocationRequestBuilder toBuilder() =>
      CancelSelfRevocationRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is CancelSelfRevocationRequest &&
        mutationId == other.mutationId;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, mutationId.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(
      r'CancelSelfRevocationRequest',
    )..add('mutationId', mutationId)).toString();
  }
}

class CancelSelfRevocationRequestBuilder
    implements
        Builder<
          CancelSelfRevocationRequest,
          CancelSelfRevocationRequestBuilder
        > {
  _$CancelSelfRevocationRequest? _$v;

  String? _mutationId;
  String? get mutationId => _$this._mutationId;
  set mutationId(String? mutationId) => _$this._mutationId = mutationId;

  CancelSelfRevocationRequestBuilder() {
    CancelSelfRevocationRequest._defaults(this);
  }

  CancelSelfRevocationRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _mutationId = $v.mutationId;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(CancelSelfRevocationRequest other) {
    _$v = other as _$CancelSelfRevocationRequest;
  }

  @override
  void update(void Function(CancelSelfRevocationRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  CancelSelfRevocationRequest build() => _build();

  _$CancelSelfRevocationRequest _build() {
    final _$result =
        _$v ??
        _$CancelSelfRevocationRequest._(
          mutationId: BuiltValueNullFieldError.checkNotNull(
            mutationId,
            r'CancelSelfRevocationRequest',
            'mutationId',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
