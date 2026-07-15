//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:kelivo_sync_api_client/src/model/admin_device_user_summary.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'admin_device_summary.g.dart';

/// AdminDeviceSummary
///
/// Properties:
/// * [id]
/// * [name]
/// * [platform]
/// * [clientVersion]
/// * [status]
/// * [createdAt]
/// * [lastSeenAt]
/// * [revokedAt]
/// * [isCurrent]
/// * [user]
@BuiltValue()
abstract class AdminDeviceSummary
    implements Built<AdminDeviceSummary, AdminDeviceSummaryBuilder> {
  @BuiltValueField(wireName: r'id')
  String get id;

  @BuiltValueField(wireName: r'name')
  String get name;

  @BuiltValueField(wireName: r'platform')
  AdminDeviceSummaryPlatformEnum get platform;
  // enum platformEnum {  android,  ios,  macos,  windows,  linux,  };

  @BuiltValueField(wireName: r'clientVersion')
  String get clientVersion;

  @BuiltValueField(wireName: r'status')
  AdminDeviceSummaryStatusEnum get status;
  // enum statusEnum {  active,  revoked,  };

  @BuiltValueField(wireName: r'createdAt')
  DateTime get createdAt;

  @BuiltValueField(wireName: r'lastSeenAt')
  DateTime? get lastSeenAt;

  @BuiltValueField(wireName: r'revokedAt')
  DateTime? get revokedAt;

  @BuiltValueField(wireName: r'isCurrent')
  bool get isCurrent;

  @BuiltValueField(wireName: r'user')
  AdminDeviceUserSummary get user;

  AdminDeviceSummary._();

  factory AdminDeviceSummary([void updates(AdminDeviceSummaryBuilder b)]) =
      _$AdminDeviceSummary;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(AdminDeviceSummaryBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AdminDeviceSummary> get serializer =>
      _$AdminDeviceSummarySerializer();
}

class _$AdminDeviceSummarySerializer
    implements PrimitiveSerializer<AdminDeviceSummary> {
  @override
  final Iterable<Type> types = const [AdminDeviceSummary, _$AdminDeviceSummary];

  @override
  final String wireName = r'AdminDeviceSummary';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AdminDeviceSummary object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'id';
    yield serializers.serialize(
      object.id,
      specifiedType: const FullType(String),
    );
    yield r'name';
    yield serializers.serialize(
      object.name,
      specifiedType: const FullType(String),
    );
    yield r'platform';
    yield serializers.serialize(
      object.platform,
      specifiedType: const FullType(AdminDeviceSummaryPlatformEnum),
    );
    yield r'clientVersion';
    yield serializers.serialize(
      object.clientVersion,
      specifiedType: const FullType(String),
    );
    yield r'status';
    yield serializers.serialize(
      object.status,
      specifiedType: const FullType(AdminDeviceSummaryStatusEnum),
    );
    yield r'createdAt';
    yield serializers.serialize(
      object.createdAt,
      specifiedType: const FullType(DateTime),
    );
    yield r'lastSeenAt';
    yield object.lastSeenAt == null
        ? null
        : serializers.serialize(
            object.lastSeenAt,
            specifiedType: const FullType.nullable(DateTime),
          );
    yield r'revokedAt';
    yield object.revokedAt == null
        ? null
        : serializers.serialize(
            object.revokedAt,
            specifiedType: const FullType.nullable(DateTime),
          );
    yield r'isCurrent';
    yield serializers.serialize(
      object.isCurrent,
      specifiedType: const FullType(bool),
    );
    yield r'user';
    yield serializers.serialize(
      object.user,
      specifiedType: const FullType(AdminDeviceUserSummary),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    AdminDeviceSummary object, {
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
    required AdminDeviceSummaryBuilder result,
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
        case r'name':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.name = valueDes;
          break;
        case r'platform':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      AdminDeviceSummaryPlatformEnum,
                    ),
                  )
                  as AdminDeviceSummaryPlatformEnum;
          result.platform = valueDes;
          break;
        case r'clientVersion':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.clientVersion = valueDes;
          break;
        case r'status':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(AdminDeviceSummaryStatusEnum),
                  )
                  as AdminDeviceSummaryStatusEnum;
          result.status = valueDes;
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
        case r'lastSeenAt':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType.nullable(DateTime),
                  )
                  as DateTime?;
          if (valueDes == null) continue;
          result.lastSeenAt = valueDes;
          break;
        case r'revokedAt':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType.nullable(DateTime),
                  )
                  as DateTime?;
          if (valueDes == null) continue;
          result.revokedAt = valueDes;
          break;
        case r'isCurrent':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(bool),
                  )
                  as bool;
          result.isCurrent = valueDes;
          break;
        case r'user':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(AdminDeviceUserSummary),
                  )
                  as AdminDeviceUserSummary;
          result.user.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  AdminDeviceSummary deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = AdminDeviceSummaryBuilder();
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

class AdminDeviceSummaryPlatformEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'android')
  static const AdminDeviceSummaryPlatformEnum android =
      _$adminDeviceSummaryPlatformEnum_android;
  @BuiltValueEnumConst(wireName: r'ios')
  static const AdminDeviceSummaryPlatformEnum ios =
      _$adminDeviceSummaryPlatformEnum_ios;
  @BuiltValueEnumConst(wireName: r'macos')
  static const AdminDeviceSummaryPlatformEnum macos =
      _$adminDeviceSummaryPlatformEnum_macos;
  @BuiltValueEnumConst(wireName: r'windows')
  static const AdminDeviceSummaryPlatformEnum windows =
      _$adminDeviceSummaryPlatformEnum_windows;
  @BuiltValueEnumConst(wireName: r'linux')
  static const AdminDeviceSummaryPlatformEnum linux =
      _$adminDeviceSummaryPlatformEnum_linux;

  static Serializer<AdminDeviceSummaryPlatformEnum> get serializer =>
      _$adminDeviceSummaryPlatformEnumSerializer;

  const AdminDeviceSummaryPlatformEnum._(String name) : super(name);

  static BuiltSet<AdminDeviceSummaryPlatformEnum> get values =>
      _$adminDeviceSummaryPlatformEnumValues;
  static AdminDeviceSummaryPlatformEnum valueOf(String name) =>
      _$adminDeviceSummaryPlatformEnumValueOf(name);
}

class AdminDeviceSummaryStatusEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'active')
  static const AdminDeviceSummaryStatusEnum active =
      _$adminDeviceSummaryStatusEnum_active;
  @BuiltValueEnumConst(wireName: r'revoked')
  static const AdminDeviceSummaryStatusEnum revoked =
      _$adminDeviceSummaryStatusEnum_revoked;

  static Serializer<AdminDeviceSummaryStatusEnum> get serializer =>
      _$adminDeviceSummaryStatusEnumSerializer;

  const AdminDeviceSummaryStatusEnum._(String name) : super(name);

  static BuiltSet<AdminDeviceSummaryStatusEnum> get values =>
      _$adminDeviceSummaryStatusEnumValues;
  static AdminDeviceSummaryStatusEnum valueOf(String name) =>
      _$adminDeviceSummaryStatusEnumValueOf(name);
}
