// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_admin_user_status_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const UpdateAdminUserStatusRequestStatusEnum
_$updateAdminUserStatusRequestStatusEnum_active =
    const UpdateAdminUserStatusRequestStatusEnum._('active');
const UpdateAdminUserStatusRequestStatusEnum
_$updateAdminUserStatusRequestStatusEnum_disabled =
    const UpdateAdminUserStatusRequestStatusEnum._('disabled');

UpdateAdminUserStatusRequestStatusEnum
_$updateAdminUserStatusRequestStatusEnumValueOf(String name) {
  switch (name) {
    case 'active':
      return _$updateAdminUserStatusRequestStatusEnum_active;
    case 'disabled':
      return _$updateAdminUserStatusRequestStatusEnum_disabled;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<UpdateAdminUserStatusRequestStatusEnum>
_$updateAdminUserStatusRequestStatusEnumValues =
    BuiltSet<UpdateAdminUserStatusRequestStatusEnum>(
      const <UpdateAdminUserStatusRequestStatusEnum>[
        _$updateAdminUserStatusRequestStatusEnum_active,
        _$updateAdminUserStatusRequestStatusEnum_disabled,
      ],
    );

Serializer<UpdateAdminUserStatusRequestStatusEnum>
_$updateAdminUserStatusRequestStatusEnumSerializer =
    _$UpdateAdminUserStatusRequestStatusEnumSerializer();

class _$UpdateAdminUserStatusRequestStatusEnumSerializer
    implements PrimitiveSerializer<UpdateAdminUserStatusRequestStatusEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'active': 'active',
    'disabled': 'disabled',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'active': 'active',
    'disabled': 'disabled',
  };

  @override
  final Iterable<Type> types = const <Type>[
    UpdateAdminUserStatusRequestStatusEnum,
  ];
  @override
  final String wireName = 'UpdateAdminUserStatusRequestStatusEnum';

  @override
  Object serialize(
    Serializers serializers,
    UpdateAdminUserStatusRequestStatusEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  UpdateAdminUserStatusRequestStatusEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => UpdateAdminUserStatusRequestStatusEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$UpdateAdminUserStatusRequest extends UpdateAdminUserStatusRequest {
  @override
  final String userId;
  @override
  final UpdateAdminUserStatusRequestStatusEnum status;

  factory _$UpdateAdminUserStatusRequest([
    void Function(UpdateAdminUserStatusRequestBuilder)? updates,
  ]) => (UpdateAdminUserStatusRequestBuilder()..update(updates))._build();

  _$UpdateAdminUserStatusRequest._({required this.userId, required this.status})
    : super._();
  @override
  UpdateAdminUserStatusRequest rebuild(
    void Function(UpdateAdminUserStatusRequestBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  UpdateAdminUserStatusRequestBuilder toBuilder() =>
      UpdateAdminUserStatusRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is UpdateAdminUserStatusRequest &&
        userId == other.userId &&
        status == other.status;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, userId.hashCode);
    _$hash = $jc(_$hash, status.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'UpdateAdminUserStatusRequest')
          ..add('userId', userId)
          ..add('status', status))
        .toString();
  }
}

class UpdateAdminUserStatusRequestBuilder
    implements
        Builder<
          UpdateAdminUserStatusRequest,
          UpdateAdminUserStatusRequestBuilder
        > {
  _$UpdateAdminUserStatusRequest? _$v;

  String? _userId;
  String? get userId => _$this._userId;
  set userId(String? userId) => _$this._userId = userId;

  UpdateAdminUserStatusRequestStatusEnum? _status;
  UpdateAdminUserStatusRequestStatusEnum? get status => _$this._status;
  set status(UpdateAdminUserStatusRequestStatusEnum? status) =>
      _$this._status = status;

  UpdateAdminUserStatusRequestBuilder() {
    UpdateAdminUserStatusRequest._defaults(this);
  }

  UpdateAdminUserStatusRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _userId = $v.userId;
      _status = $v.status;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(UpdateAdminUserStatusRequest other) {
    _$v = other as _$UpdateAdminUserStatusRequest;
  }

  @override
  void update(void Function(UpdateAdminUserStatusRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  UpdateAdminUserStatusRequest build() => _build();

  _$UpdateAdminUserStatusRequest _build() {
    final _$result =
        _$v ??
        _$UpdateAdminUserStatusRequest._(
          userId: BuiltValueNullFieldError.checkNotNull(
            userId,
            r'UpdateAdminUserStatusRequest',
            'userId',
          ),
          status: BuiltValueNullFieldError.checkNotNull(
            status,
            r'UpdateAdminUserStatusRequest',
            'status',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
