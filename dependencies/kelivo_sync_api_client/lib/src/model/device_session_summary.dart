//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'device_session_summary.g.dart';

/// DeviceSessionSummary
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
@BuiltValue()
abstract class DeviceSessionSummary
    implements Built<DeviceSessionSummary, DeviceSessionSummaryBuilder> {
  @BuiltValueField(wireName: r'id')
  String get id;

  @BuiltValueField(wireName: r'name')
  String get name;

  @BuiltValueField(wireName: r'platform')
  DeviceSessionSummaryPlatformEnum get platform;
  // enum platformEnum {  android,  ios,  macos,  windows,  linux,  };

  @BuiltValueField(wireName: r'clientVersion')
  String get clientVersion;

  @BuiltValueField(wireName: r'status')
  DeviceSessionSummaryStatusEnum get status;
  // enum statusEnum {  active,  revoked,  };

  @BuiltValueField(wireName: r'createdAt')
  DateTime get createdAt;

  @BuiltValueField(wireName: r'lastSeenAt')
  DateTime? get lastSeenAt;

  @BuiltValueField(wireName: r'revokedAt')
  DateTime? get revokedAt;

  @BuiltValueField(wireName: r'isCurrent')
  bool get isCurrent;

  DeviceSessionSummary._();

  factory DeviceSessionSummary([void updates(DeviceSessionSummaryBuilder b)]) =
      _$DeviceSessionSummary;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DeviceSessionSummaryBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DeviceSessionSummary> get serializer =>
      _$DeviceSessionSummarySerializer();
}

class _$DeviceSessionSummarySerializer
    implements PrimitiveSerializer<DeviceSessionSummary> {
  @override
  final Iterable<Type> types = const [
    DeviceSessionSummary,
    _$DeviceSessionSummary,
  ];

  @override
  final String wireName = r'DeviceSessionSummary';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DeviceSessionSummary object, {
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
      specifiedType: const FullType(DeviceSessionSummaryPlatformEnum),
    );
    yield r'clientVersion';
    yield serializers.serialize(
      object.clientVersion,
      specifiedType: const FullType(String),
    );
    yield r'status';
    yield serializers.serialize(
      object.status,
      specifiedType: const FullType(DeviceSessionSummaryStatusEnum),
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
  }

  @override
  Object serialize(
    Serializers serializers,
    DeviceSessionSummary object, {
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
    required DeviceSessionSummaryBuilder result,
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
                      DeviceSessionSummaryPlatformEnum,
                    ),
                  )
                  as DeviceSessionSummaryPlatformEnum;
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
                    specifiedType: const FullType(
                      DeviceSessionSummaryStatusEnum,
                    ),
                  )
                  as DeviceSessionSummaryStatusEnum;
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
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  DeviceSessionSummary deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DeviceSessionSummaryBuilder();
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

class DeviceSessionSummaryPlatformEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'android')
  static const DeviceSessionSummaryPlatformEnum android =
      _$deviceSessionSummaryPlatformEnum_android;
  @BuiltValueEnumConst(wireName: r'ios')
  static const DeviceSessionSummaryPlatformEnum ios =
      _$deviceSessionSummaryPlatformEnum_ios;
  @BuiltValueEnumConst(wireName: r'macos')
  static const DeviceSessionSummaryPlatformEnum macos =
      _$deviceSessionSummaryPlatformEnum_macos;
  @BuiltValueEnumConst(wireName: r'windows')
  static const DeviceSessionSummaryPlatformEnum windows =
      _$deviceSessionSummaryPlatformEnum_windows;
  @BuiltValueEnumConst(wireName: r'linux')
  static const DeviceSessionSummaryPlatformEnum linux =
      _$deviceSessionSummaryPlatformEnum_linux;

  static Serializer<DeviceSessionSummaryPlatformEnum> get serializer =>
      _$deviceSessionSummaryPlatformEnumSerializer;

  const DeviceSessionSummaryPlatformEnum._(String name) : super(name);

  static BuiltSet<DeviceSessionSummaryPlatformEnum> get values =>
      _$deviceSessionSummaryPlatformEnumValues;
  static DeviceSessionSummaryPlatformEnum valueOf(String name) =>
      _$deviceSessionSummaryPlatformEnumValueOf(name);
}

class DeviceSessionSummaryStatusEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'active')
  static const DeviceSessionSummaryStatusEnum active =
      _$deviceSessionSummaryStatusEnum_active;
  @BuiltValueEnumConst(wireName: r'revoked')
  static const DeviceSessionSummaryStatusEnum revoked =
      _$deviceSessionSummaryStatusEnum_revoked;

  static Serializer<DeviceSessionSummaryStatusEnum> get serializer =>
      _$deviceSessionSummaryStatusEnumSerializer;

  const DeviceSessionSummaryStatusEnum._(String name) : super(name);

  static BuiltSet<DeviceSessionSummaryStatusEnum> get values =>
      _$deviceSessionSummaryStatusEnumValues;
  static DeviceSessionSummaryStatusEnum valueOf(String name) =>
      _$deviceSessionSummaryStatusEnumValueOf(name);
}
