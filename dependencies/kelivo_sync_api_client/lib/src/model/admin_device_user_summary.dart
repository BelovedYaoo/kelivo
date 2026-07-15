//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'admin_device_user_summary.g.dart';

/// AdminDeviceUserSummary
///
/// Properties:
/// * [id]
/// * [loginName]
/// * [displayName]
/// * [role]
@BuiltValue()
abstract class AdminDeviceUserSummary
    implements Built<AdminDeviceUserSummary, AdminDeviceUserSummaryBuilder> {
  @BuiltValueField(wireName: r'id')
  String get id;

  @BuiltValueField(wireName: r'loginName')
  String get loginName;

  @BuiltValueField(wireName: r'displayName')
  String get displayName;

  @BuiltValueField(wireName: r'role')
  AdminDeviceUserSummaryRoleEnum get role;
  // enum roleEnum {  owner,  admin,  user,  };

  AdminDeviceUserSummary._();

  factory AdminDeviceUserSummary([
    void updates(AdminDeviceUserSummaryBuilder b),
  ]) = _$AdminDeviceUserSummary;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(AdminDeviceUserSummaryBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AdminDeviceUserSummary> get serializer =>
      _$AdminDeviceUserSummarySerializer();
}

class _$AdminDeviceUserSummarySerializer
    implements PrimitiveSerializer<AdminDeviceUserSummary> {
  @override
  final Iterable<Type> types = const [
    AdminDeviceUserSummary,
    _$AdminDeviceUserSummary,
  ];

  @override
  final String wireName = r'AdminDeviceUserSummary';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AdminDeviceUserSummary object, {
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
      specifiedType: const FullType(AdminDeviceUserSummaryRoleEnum),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    AdminDeviceUserSummary object, {
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
    required AdminDeviceUserSummaryBuilder result,
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
                      AdminDeviceUserSummaryRoleEnum,
                    ),
                  )
                  as AdminDeviceUserSummaryRoleEnum;
          result.role = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  AdminDeviceUserSummary deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = AdminDeviceUserSummaryBuilder();
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

class AdminDeviceUserSummaryRoleEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'owner')
  static const AdminDeviceUserSummaryRoleEnum owner =
      _$adminDeviceUserSummaryRoleEnum_owner;
  @BuiltValueEnumConst(wireName: r'admin')
  static const AdminDeviceUserSummaryRoleEnum admin =
      _$adminDeviceUserSummaryRoleEnum_admin;
  @BuiltValueEnumConst(wireName: r'user')
  static const AdminDeviceUserSummaryRoleEnum user =
      _$adminDeviceUserSummaryRoleEnum_user;

  static Serializer<AdminDeviceUserSummaryRoleEnum> get serializer =>
      _$adminDeviceUserSummaryRoleEnumSerializer;

  const AdminDeviceUserSummaryRoleEnum._(String name) : super(name);

  static BuiltSet<AdminDeviceUserSummaryRoleEnum> get values =>
      _$adminDeviceUserSummaryRoleEnumValues;
  static AdminDeviceUserSummaryRoleEnum valueOf(String name) =>
      _$adminDeviceUserSummaryRoleEnumValueOf(name);
}
