// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_admin_user_quota_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$UpdateAdminUserQuotaRequest extends UpdateAdminUserQuotaRequest {
  @override
  final String userId;
  @override
  final int attachmentQuotaBytes;

  factory _$UpdateAdminUserQuotaRequest([
    void Function(UpdateAdminUserQuotaRequestBuilder)? updates,
  ]) => (UpdateAdminUserQuotaRequestBuilder()..update(updates))._build();

  _$UpdateAdminUserQuotaRequest._({
    required this.userId,
    required this.attachmentQuotaBytes,
  }) : super._();
  @override
  UpdateAdminUserQuotaRequest rebuild(
    void Function(UpdateAdminUserQuotaRequestBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  UpdateAdminUserQuotaRequestBuilder toBuilder() =>
      UpdateAdminUserQuotaRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is UpdateAdminUserQuotaRequest &&
        userId == other.userId &&
        attachmentQuotaBytes == other.attachmentQuotaBytes;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, userId.hashCode);
    _$hash = $jc(_$hash, attachmentQuotaBytes.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'UpdateAdminUserQuotaRequest')
          ..add('userId', userId)
          ..add('attachmentQuotaBytes', attachmentQuotaBytes))
        .toString();
  }
}

class UpdateAdminUserQuotaRequestBuilder
    implements
        Builder<
          UpdateAdminUserQuotaRequest,
          UpdateAdminUserQuotaRequestBuilder
        > {
  _$UpdateAdminUserQuotaRequest? _$v;

  String? _userId;
  String? get userId => _$this._userId;
  set userId(String? userId) => _$this._userId = userId;

  int? _attachmentQuotaBytes;
  int? get attachmentQuotaBytes => _$this._attachmentQuotaBytes;
  set attachmentQuotaBytes(int? attachmentQuotaBytes) =>
      _$this._attachmentQuotaBytes = attachmentQuotaBytes;

  UpdateAdminUserQuotaRequestBuilder() {
    UpdateAdminUserQuotaRequest._defaults(this);
  }

  UpdateAdminUserQuotaRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _userId = $v.userId;
      _attachmentQuotaBytes = $v.attachmentQuotaBytes;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(UpdateAdminUserQuotaRequest other) {
    _$v = other as _$UpdateAdminUserQuotaRequest;
  }

  @override
  void update(void Function(UpdateAdminUserQuotaRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  UpdateAdminUserQuotaRequest build() => _build();

  _$UpdateAdminUserQuotaRequest _build() {
    final _$result =
        _$v ??
        _$UpdateAdminUserQuotaRequest._(
          userId: BuiltValueNullFieldError.checkNotNull(
            userId,
            r'UpdateAdminUserQuotaRequest',
            'userId',
          ),
          attachmentQuotaBytes: BuiltValueNullFieldError.checkNotNull(
            attachmentQuotaBytes,
            r'UpdateAdminUserQuotaRequest',
            'attachmentQuotaBytes',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
