//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'opaque_registration_finish_data_user.g.dart';

/// OpaqueRegistrationFinishDataUser
///
/// Properties:
/// * [id]
/// * [loginName]
/// * [displayName]
/// * [role]
/// * [attachmentQuotaBytes]
@BuiltValue()
abstract class OpaqueRegistrationFinishDataUser
    implements
        Built<
          OpaqueRegistrationFinishDataUser,
          OpaqueRegistrationFinishDataUserBuilder
        > {
  @BuiltValueField(wireName: r'id')
  String get id;

  @BuiltValueField(wireName: r'loginName')
  String get loginName;

  @BuiltValueField(wireName: r'displayName')
  String get displayName;

  @BuiltValueField(wireName: r'role')
  OpaqueRegistrationFinishDataUserRoleEnum get role;
  // enum roleEnum {  owner,  admin,  user,  };

  @BuiltValueField(wireName: r'attachmentQuotaBytes')
  int get attachmentQuotaBytes;

  OpaqueRegistrationFinishDataUser._();

  factory OpaqueRegistrationFinishDataUser([
    void updates(OpaqueRegistrationFinishDataUserBuilder b),
  ]) = _$OpaqueRegistrationFinishDataUser;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(OpaqueRegistrationFinishDataUserBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<OpaqueRegistrationFinishDataUser> get serializer =>
      _$OpaqueRegistrationFinishDataUserSerializer();
}

class _$OpaqueRegistrationFinishDataUserSerializer
    implements PrimitiveSerializer<OpaqueRegistrationFinishDataUser> {
  @override
  final Iterable<Type> types = const [
    OpaqueRegistrationFinishDataUser,
    _$OpaqueRegistrationFinishDataUser,
  ];

  @override
  final String wireName = r'OpaqueRegistrationFinishDataUser';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    OpaqueRegistrationFinishDataUser object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'id';
    yield serializers.serialize(
      object.id,
      specifiedType: const FullType(String),
    );
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
    yield r'role';
    yield serializers.serialize(
      object.role,
      specifiedType: const FullType(OpaqueRegistrationFinishDataUserRoleEnum),
    );
    yield r'attachmentQuotaBytes';
    yield serializers.serialize(
      object.attachmentQuotaBytes,
      specifiedType: const FullType(int),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    OpaqueRegistrationFinishDataUser object, {
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
    required OpaqueRegistrationFinishDataUserBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'id':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.id = valueDes;
          break;
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
        case r'role':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      OpaqueRegistrationFinishDataUserRoleEnum,
                    ),
                  )
                  as OpaqueRegistrationFinishDataUserRoleEnum;
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
  OpaqueRegistrationFinishDataUser deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = OpaqueRegistrationFinishDataUserBuilder();
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

class OpaqueRegistrationFinishDataUserRoleEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'owner')
  static const OpaqueRegistrationFinishDataUserRoleEnum owner =
      _$opaqueRegistrationFinishDataUserRoleEnum_owner;
  @BuiltValueEnumConst(wireName: r'admin')
  static const OpaqueRegistrationFinishDataUserRoleEnum admin =
      _$opaqueRegistrationFinishDataUserRoleEnum_admin;
  @BuiltValueEnumConst(wireName: r'user')
  static const OpaqueRegistrationFinishDataUserRoleEnum user =
      _$opaqueRegistrationFinishDataUserRoleEnum_user;

  static Serializer<OpaqueRegistrationFinishDataUserRoleEnum> get serializer =>
      _$opaqueRegistrationFinishDataUserRoleEnumSerializer;

  const OpaqueRegistrationFinishDataUserRoleEnum._(String name) : super(name);

  static BuiltSet<OpaqueRegistrationFinishDataUserRoleEnum> get values =>
      _$opaqueRegistrationFinishDataUserRoleEnumValues;
  static OpaqueRegistrationFinishDataUserRoleEnum valueOf(String name) =>
      _$opaqueRegistrationFinishDataUserRoleEnumValueOf(name);
}
