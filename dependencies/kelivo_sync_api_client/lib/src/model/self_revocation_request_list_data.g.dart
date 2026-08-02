// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'self_revocation_request_list_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$SelfRevocationRequestListData extends SelfRevocationRequestListData {
  @override
  final BuiltList<PendingSelfRevocationRequest> requests;

  factory _$SelfRevocationRequestListData([
    void Function(SelfRevocationRequestListDataBuilder)? updates,
  ]) => (SelfRevocationRequestListDataBuilder()..update(updates))._build();

  _$SelfRevocationRequestListData._({required this.requests}) : super._();
  @override
  SelfRevocationRequestListData rebuild(
    void Function(SelfRevocationRequestListDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  SelfRevocationRequestListDataBuilder toBuilder() =>
      SelfRevocationRequestListDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SelfRevocationRequestListData && requests == other.requests;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, requests.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(
      r'SelfRevocationRequestListData',
    )..add('requests', requests)).toString();
  }
}

class SelfRevocationRequestListDataBuilder
    implements
        Builder<
          SelfRevocationRequestListData,
          SelfRevocationRequestListDataBuilder
        > {
  _$SelfRevocationRequestListData? _$v;

  ListBuilder<PendingSelfRevocationRequest>? _requests;
  ListBuilder<PendingSelfRevocationRequest> get requests =>
      _$this._requests ??= ListBuilder<PendingSelfRevocationRequest>();
  set requests(ListBuilder<PendingSelfRevocationRequest>? requests) =>
      _$this._requests = requests;

  SelfRevocationRequestListDataBuilder() {
    SelfRevocationRequestListData._defaults(this);
  }

  SelfRevocationRequestListDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _requests = $v.requests.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SelfRevocationRequestListData other) {
    _$v = other as _$SelfRevocationRequestListData;
  }

  @override
  void update(void Function(SelfRevocationRequestListDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SelfRevocationRequestListData build() => _build();

  _$SelfRevocationRequestListData _build() {
    _$SelfRevocationRequestListData _$result;
    try {
      _$result =
          _$v ?? _$SelfRevocationRequestListData._(requests: requests.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'requests';
        requests.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'SelfRevocationRequestListData',
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
