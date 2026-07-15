//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'list_admin_users_request.g.dart';

/// ListAdminUsersRequest
///
/// Properties:
/// * [keyword]
/// * [role]
/// * [status]
/// * [pageIndex]
/// * [pageSize]
@BuiltValue()
abstract class ListAdminUsersRequest
    implements Built<ListAdminUsersRequest, ListAdminUsersRequestBuilder> {
  @BuiltValueField(wireName: r'keyword')
  String? get keyword;

  @BuiltValueField(wireName: r'role')
  ListAdminUsersRequestRoleEnum? get role;
  // enum roleEnum {  owner,  admin,  user,  };

  @BuiltValueField(wireName: r'status')
  ListAdminUsersRequestStatusEnum? get status;
  // enum statusEnum {  active,  disabled,  };

  @BuiltValueField(wireName: r'pageIndex')
  int? get pageIndex;

  @BuiltValueField(wireName: r'pageSize')
  int? get pageSize;

  ListAdminUsersRequest._();

  factory ListAdminUsersRequest([
    void updates(ListAdminUsersRequestBuilder b),
  ]) = _$ListAdminUsersRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ListAdminUsersRequestBuilder b) => b
    ..pageIndex = 1
    ..pageSize = 20;

  @BuiltValueSerializer(custom: true)
  static Serializer<ListAdminUsersRequest> get serializer =>
      _$ListAdminUsersRequestSerializer();
}

class _$ListAdminUsersRequestSerializer
    implements PrimitiveSerializer<ListAdminUsersRequest> {
  @override
  final Iterable<Type> types = const [
    ListAdminUsersRequest,
    _$ListAdminUsersRequest,
  ];

  @override
  final String wireName = r'ListAdminUsersRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ListAdminUsersRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    if (object.keyword != null) {
      yield r'keyword';
      yield serializers.serialize(
        object.keyword,
        specifiedType: const FullType(String),
      );
    }
    if (object.role != null) {
      yield r'role';
      yield serializers.serialize(
        object.role,
        specifiedType: const FullType(ListAdminUsersRequestRoleEnum),
      );
    }
    if (object.status != null) {
      yield r'status';
      yield serializers.serialize(
        object.status,
        specifiedType: const FullType(ListAdminUsersRequestStatusEnum),
      );
    }
    if (object.pageIndex != null) {
      yield r'pageIndex';
      yield serializers.serialize(
        object.pageIndex,
        specifiedType: const FullType(int),
      );
    }
    if (object.pageSize != null) {
      yield r'pageSize';
      yield serializers.serialize(
        object.pageSize,
        specifiedType: const FullType(int),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    ListAdminUsersRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(
      serializers,
      object,
      specifiedType: specifiedType,
    ).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ListAdminUsersRequestBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'keyword':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.keyword = valueDes;
          break;
        case r'role':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      ListAdminUsersRequestRoleEnum,
                    ),
                  )
                  as ListAdminUsersRequestRoleEnum;
          result.role = valueDes;
          break;
        case r'status':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      ListAdminUsersRequestStatusEnum,
                    ),
                  )
                  as ListAdminUsersRequestStatusEnum;
          result.status = valueDes;
          break;
        case r'pageIndex':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.pageIndex = valueDes;
          break;
        case r'pageSize':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.pageSize = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ListAdminUsersRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ListAdminUsersRequestBuilder();
    final serializedList = (serialized as Iterable<Object?>).toList();
    final unhandled = <Object?>[];
    _deserializeProperties(
      serializers,
      serialized,
      specifiedType: specifiedType,
      serializedList: serializedList,
      unhandled: unhandled,
      result: result,
    );
    return result.build();
  }
}

class ListAdminUsersRequestRoleEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'owner')
  static const ListAdminUsersRequestRoleEnum owner =
      _$listAdminUsersRequestRoleEnum_owner;
  @BuiltValueEnumConst(wireName: r'admin')
  static const ListAdminUsersRequestRoleEnum admin =
      _$listAdminUsersRequestRoleEnum_admin;
  @BuiltValueEnumConst(wireName: r'user')
  static const ListAdminUsersRequestRoleEnum user =
      _$listAdminUsersRequestRoleEnum_user;

  static Serializer<ListAdminUsersRequestRoleEnum> get serializer =>
      _$listAdminUsersRequestRoleEnumSerializer;

  const ListAdminUsersRequestRoleEnum._(String name) : super(name);

  static BuiltSet<ListAdminUsersRequestRoleEnum> get values =>
      _$listAdminUsersRequestRoleEnumValues;
  static ListAdminUsersRequestRoleEnum valueOf(String name) =>
      _$listAdminUsersRequestRoleEnumValueOf(name);
}

class ListAdminUsersRequestStatusEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'active')
  static const ListAdminUsersRequestStatusEnum active =
      _$listAdminUsersRequestStatusEnum_active;
  @BuiltValueEnumConst(wireName: r'disabled')
  static const ListAdminUsersRequestStatusEnum disabled =
      _$listAdminUsersRequestStatusEnum_disabled;

  static Serializer<ListAdminUsersRequestStatusEnum> get serializer =>
      _$listAdminUsersRequestStatusEnumSerializer;

  const ListAdminUsersRequestStatusEnum._(String name) : super(name);

  static BuiltSet<ListAdminUsersRequestStatusEnum> get values =>
      _$listAdminUsersRequestStatusEnumValues;
  static ListAdminUsersRequestStatusEnum valueOf(String name) =>
      _$listAdminUsersRequestStatusEnumValueOf(name);
}
