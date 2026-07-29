// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_account_security_state_history_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ListAccountSecurityStateHistoryRequest
    extends ListAccountSecurityStateHistoryRequest {
  @override
  final int afterGeneration;
  @override
  final int pageSize;

  factory _$ListAccountSecurityStateHistoryRequest([
    void Function(ListAccountSecurityStateHistoryRequestBuilder)? updates,
  ]) => (ListAccountSecurityStateHistoryRequestBuilder()..update(updates))
      ._build();

  _$ListAccountSecurityStateHistoryRequest._({
    required this.afterGeneration,
    required this.pageSize,
  }) : super._();
  @override
  ListAccountSecurityStateHistoryRequest rebuild(
    void Function(ListAccountSecurityStateHistoryRequestBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  ListAccountSecurityStateHistoryRequestBuilder toBuilder() =>
      ListAccountSecurityStateHistoryRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ListAccountSecurityStateHistoryRequest &&
        afterGeneration == other.afterGeneration &&
        pageSize == other.pageSize;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, afterGeneration.hashCode);
    _$hash = $jc(_$hash, pageSize.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(
            r'ListAccountSecurityStateHistoryRequest',
          )
          ..add('afterGeneration', afterGeneration)
          ..add('pageSize', pageSize))
        .toString();
  }
}

class ListAccountSecurityStateHistoryRequestBuilder
    implements
        Builder<
          ListAccountSecurityStateHistoryRequest,
          ListAccountSecurityStateHistoryRequestBuilder
        > {
  _$ListAccountSecurityStateHistoryRequest? _$v;

  int? _afterGeneration;
  int? get afterGeneration => _$this._afterGeneration;
  set afterGeneration(int? afterGeneration) =>
      _$this._afterGeneration = afterGeneration;

  int? _pageSize;
  int? get pageSize => _$this._pageSize;
  set pageSize(int? pageSize) => _$this._pageSize = pageSize;

  ListAccountSecurityStateHistoryRequestBuilder() {
    ListAccountSecurityStateHistoryRequest._defaults(this);
  }

  ListAccountSecurityStateHistoryRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _afterGeneration = $v.afterGeneration;
      _pageSize = $v.pageSize;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ListAccountSecurityStateHistoryRequest other) {
    _$v = other as _$ListAccountSecurityStateHistoryRequest;
  }

  @override
  void update(
    void Function(ListAccountSecurityStateHistoryRequestBuilder)? updates,
  ) {
    if (updates != null) updates(this);
  }

  @override
  ListAccountSecurityStateHistoryRequest build() => _build();

  _$ListAccountSecurityStateHistoryRequest _build() {
    final _$result =
        _$v ??
        _$ListAccountSecurityStateHistoryRequest._(
          afterGeneration: BuiltValueNullFieldError.checkNotNull(
            afterGeneration,
            r'ListAccountSecurityStateHistoryRequest',
            'afterGeneration',
          ),
          pageSize: BuiltValueNullFieldError.checkNotNull(
            pageSize,
            r'ListAccountSecurityStateHistoryRequest',
            'pageSize',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
