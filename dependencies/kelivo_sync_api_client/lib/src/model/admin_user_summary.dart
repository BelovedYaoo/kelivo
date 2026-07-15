//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'admin_user_summary.g.dart';

/// AdminUserSummary
///
/// Properties:
/// * [id]
/// * [loginName]
/// * [displayName]
/// * [role]
/// * [status]
/// * [attachmentQuotaBytes] - 附件配额字节数，0 表示禁止占用附件存储
/// * [createdAt]
/// * [updatedAt]
/// * [disabledAt]
@BuiltValue()
abstract class AdminUserSummary
    implements Built<AdminUserSummary, AdminUserSummaryBuilder> {
  @BuiltValueField(wireName: r'id')
  String get id;

  @BuiltValueField(wireName: r'loginName')
  String get loginName;

  @BuiltValueField(wireName: r'displayName')
  String get displayName;

  @BuiltValueField(wireName: r'role')
  AdminUserSummaryRoleEnum get role;
  // enum roleEnum {  owner,  admin,  user,  };

  @BuiltValueField(wireName: r'status')
  AdminUserSummaryStatusEnum get status;
  // enum statusEnum {  active,  disabled,  };

  /// 附件配额字节数，0 表示禁止占用附件存储
  @BuiltValueField(wireName: r'attachmentQuotaBytes')
  int get attachmentQuotaBytes;

  @BuiltValueField(wireName: r'createdAt')
  DateTime get createdAt;

  @BuiltValueField(wireName: r'updatedAt')
  DateTime get updatedAt;

  @BuiltValueField(wireName: r'disabledAt')
  DateTime? get disabledAt;

  AdminUserSummary._();

  factory AdminUserSummary([void updates(AdminUserSummaryBuilder b)]) =
      _$AdminUserSummary;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(AdminUserSummaryBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AdminUserSummary> get serializer =>
      _$AdminUserSummarySerializer();
}

class _$AdminUserSummarySerializer
    implements PrimitiveSerializer<AdminUserSummary> {
  @override
  final Iterable<Type> types = const [AdminUserSummary, _$AdminUserSummary];

  @override
  final String wireName = r'AdminUserSummary';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AdminUserSummary object, {
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
      specifiedType: const FullType(AdminUserSummaryRoleEnum),
    );
    yield r'status';
    yield serializers.serialize(
      object.status,
      specifiedType: const FullType(AdminUserSummaryStatusEnum),
    );
    yield r'attachmentQuotaBytes';
    yield serializers.serialize(
      object.attachmentQuotaBytes,
      specifiedType: const FullType(int),
    );
    yield r'createdAt';
    yield serializers.serialize(
      object.createdAt,
      specifiedType: const FullType(DateTime),
    );
    yield r'updatedAt';
    yield serializers.serialize(
      object.updatedAt,
      specifiedType: const FullType(DateTime),
    );
    yield r'disabledAt';
    yield object.disabledAt == null
        ? null
        : serializers.serialize(
            object.disabledAt,
            specifiedType: const FullType.nullable(DateTime),
          );
  }

  @override
  Object serialize(
    Serializers serializers,
    AdminUserSummary object, {
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
    required AdminUserSummaryBuilder result,
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
                    specifiedType: const FullType(AdminUserSummaryRoleEnum),
                  )
                  as AdminUserSummaryRoleEnum;
          result.role = valueDes;
          break;
        case r'status':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(AdminUserSummaryStatusEnum),
                  )
                  as AdminUserSummaryStatusEnum;
          result.status = valueDes;
          break;
        case r'attachmentQuotaBytes':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.attachmentQuotaBytes = valueDes;
          break;
        case r'createdAt':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(DateTime),
                  )
                  as DateTime;
          result.createdAt = valueDes;
          break;
        case r'updatedAt':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(DateTime),
                  )
                  as DateTime;
          result.updatedAt = valueDes;
          break;
        case r'disabledAt':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType.nullable(DateTime),
                  )
                  as DateTime?;
          if (valueDes == null) continue;
          result.disabledAt = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  AdminUserSummary deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = AdminUserSummaryBuilder();
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

class AdminUserSummaryRoleEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'owner')
  static const AdminUserSummaryRoleEnum owner =
      _$adminUserSummaryRoleEnum_owner;
  @BuiltValueEnumConst(wireName: r'admin')
  static const AdminUserSummaryRoleEnum admin =
      _$adminUserSummaryRoleEnum_admin;
  @BuiltValueEnumConst(wireName: r'user')
  static const AdminUserSummaryRoleEnum user = _$adminUserSummaryRoleEnum_user;

  static Serializer<AdminUserSummaryRoleEnum> get serializer =>
      _$adminUserSummaryRoleEnumSerializer;

  const AdminUserSummaryRoleEnum._(String name) : super(name);

  static BuiltSet<AdminUserSummaryRoleEnum> get values =>
      _$adminUserSummaryRoleEnumValues;
  static AdminUserSummaryRoleEnum valueOf(String name) =>
      _$adminUserSummaryRoleEnumValueOf(name);
}

class AdminUserSummaryStatusEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'active')
  static const AdminUserSummaryStatusEnum active =
      _$adminUserSummaryStatusEnum_active;
  @BuiltValueEnumConst(wireName: r'disabled')
  static const AdminUserSummaryStatusEnum disabled =
      _$adminUserSummaryStatusEnum_disabled;

  static Serializer<AdminUserSummaryStatusEnum> get serializer =>
      _$adminUserSummaryStatusEnumSerializer;

  const AdminUserSummaryStatusEnum._(String name) : super(name);

  static BuiltSet<AdminUserSummaryStatusEnum> get values =>
      _$adminUserSummaryStatusEnumValues;
  static AdminUserSummaryStatusEnum valueOf(String name) =>
      _$adminUserSummaryStatusEnumValueOf(name);
}
