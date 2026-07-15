//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'user_summary.g.dart';

/// UserSummary
///
/// Properties:
/// * [id]
/// * [loginName]
/// * [displayName]
/// * [role]
/// * [attachmentQuotaBytes]
@BuiltValue()
abstract class UserSummary implements Built<UserSummary, UserSummaryBuilder> {
  @BuiltValueField(wireName: r'id')
  String get id;

  @BuiltValueField(wireName: r'loginName')
  String get loginName;

  @BuiltValueField(wireName: r'displayName')
  String get displayName;

  @BuiltValueField(wireName: r'role')
  UserSummaryRoleEnum get role;
  // enum roleEnum {  owner,  admin,  user,  };

  @BuiltValueField(wireName: r'attachmentQuotaBytes')
  int get attachmentQuotaBytes;

  UserSummary._();

  factory UserSummary([void updates(UserSummaryBuilder b)]) = _$UserSummary;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(UserSummaryBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<UserSummary> get serializer => _$UserSummarySerializer();
}

class _$UserSummarySerializer implements PrimitiveSerializer<UserSummary> {
  @override
  final Iterable<Type> types = const [UserSummary, _$UserSummary];

  @override
  final String wireName = r'UserSummary';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    UserSummary object, {
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
      specifiedType: const FullType(UserSummaryRoleEnum),
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
    UserSummary object, {
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
    required UserSummaryBuilder result,
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
                    specifiedType: const FullType(UserSummaryRoleEnum),
                  )
                  as UserSummaryRoleEnum;
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
  UserSummary deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = UserSummaryBuilder();
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

class UserSummaryRoleEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'owner')
  static const UserSummaryRoleEnum owner = _$userSummaryRoleEnum_owner;
  @BuiltValueEnumConst(wireName: r'admin')
  static const UserSummaryRoleEnum admin = _$userSummaryRoleEnum_admin;
  @BuiltValueEnumConst(wireName: r'user')
  static const UserSummaryRoleEnum user = _$userSummaryRoleEnum_user;

  static Serializer<UserSummaryRoleEnum> get serializer =>
      _$userSummaryRoleEnumSerializer;

  const UserSummaryRoleEnum._(String name) : super(name);

  static BuiltSet<UserSummaryRoleEnum> get values =>
      _$userSummaryRoleEnumValues;
  static UserSummaryRoleEnum valueOf(String name) =>
      _$userSummaryRoleEnumValueOf(name);
}
