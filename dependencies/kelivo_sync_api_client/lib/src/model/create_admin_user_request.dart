//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'create_admin_user_request.g.dart';

/// CreateAdminUserRequest
///
/// Properties:
/// * [loginName]
/// * [displayName]
/// * [password]
/// * [role]
/// * [attachmentQuotaBytes] - 附件配额字节数，0 表示禁止占用附件存储
@BuiltValue()
abstract class CreateAdminUserRequest
    implements Built<CreateAdminUserRequest, CreateAdminUserRequestBuilder> {
  @BuiltValueField(wireName: r'loginName')
  String get loginName;

  @BuiltValueField(wireName: r'displayName')
  String get displayName;

  @BuiltValueField(wireName: r'password')
  String get password;

  @BuiltValueField(wireName: r'role')
  CreateAdminUserRequestRoleEnum? get role;
  // enum roleEnum {  admin,  user,  };

  /// 附件配额字节数，0 表示禁止占用附件存储
  @BuiltValueField(wireName: r'attachmentQuotaBytes')
  int? get attachmentQuotaBytes;

  CreateAdminUserRequest._();

  factory CreateAdminUserRequest([
    void updates(CreateAdminUserRequestBuilder b),
  ]) = _$CreateAdminUserRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(CreateAdminUserRequestBuilder b) =>
      b..role = CreateAdminUserRequestRoleEnum.valueOf('user');

  @BuiltValueSerializer(custom: true)
  static Serializer<CreateAdminUserRequest> get serializer =>
      _$CreateAdminUserRequestSerializer();
}

class _$CreateAdminUserRequestSerializer
    implements PrimitiveSerializer<CreateAdminUserRequest> {
  @override
  final Iterable<Type> types = const [
    CreateAdminUserRequest,
    _$CreateAdminUserRequest,
  ];

  @override
  final String wireName = r'CreateAdminUserRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    CreateAdminUserRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'loginName';
    yield serializers.serialize(
      object.loginName,
      specifiedType: const FullType(String),
    );
    yield r'displayName';
    yield serializers.serialize(
      object.displayName,
      specifiedType: const FullType(String),
    );
    yield r'password';
    yield serializers.serialize(
      object.password,
      specifiedType: const FullType(String),
    );
    if (object.role != null) {
      yield r'role';
      yield serializers.serialize(
        object.role,
        specifiedType: const FullType(CreateAdminUserRequestRoleEnum),
      );
    }
    if (object.attachmentQuotaBytes != null) {
      yield r'attachmentQuotaBytes';
      yield serializers.serialize(
        object.attachmentQuotaBytes,
        specifiedType: const FullType(int),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    CreateAdminUserRequest object, {
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
    required CreateAdminUserRequestBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'loginName':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.loginName = valueDes;
          break;
        case r'displayName':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.displayName = valueDes;
          break;
        case r'password':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.password = valueDes;
          break;
        case r'role':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      CreateAdminUserRequestRoleEnum,
                    ),
                  )
                  as CreateAdminUserRequestRoleEnum;
          result.role = valueDes;
          break;
        case r'attachmentQuotaBytes':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.attachmentQuotaBytes = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  CreateAdminUserRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = CreateAdminUserRequestBuilder();
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

class CreateAdminUserRequestRoleEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'admin')
  static const CreateAdminUserRequestRoleEnum admin =
      _$createAdminUserRequestRoleEnum_admin;
  @BuiltValueEnumConst(wireName: r'user')
  static const CreateAdminUserRequestRoleEnum user =
      _$createAdminUserRequestRoleEnum_user;

  static Serializer<CreateAdminUserRequestRoleEnum> get serializer =>
      _$createAdminUserRequestRoleEnumSerializer;

  const CreateAdminUserRequestRoleEnum._(String name) : super(name);

  static BuiltSet<CreateAdminUserRequestRoleEnum> get values =>
      _$createAdminUserRequestRoleEnumValues;
  static CreateAdminUserRequestRoleEnum valueOf(String name) =>
      _$createAdminUserRequestRoleEnumValueOf(name);
}
