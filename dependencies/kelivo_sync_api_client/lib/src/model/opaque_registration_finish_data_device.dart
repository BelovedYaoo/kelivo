//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'opaque_registration_finish_data_device.g.dart';

/// OpaqueRegistrationFinishDataDevice
///
/// Properties:
/// * [id]
/// * [name]
/// * [platform]
/// * [clientVersion]
/// * [authGeneration]
/// * [status]
/// * [createdAt]
/// * [sessionGeneration]
@BuiltValue()
abstract class OpaqueRegistrationFinishDataDevice
    implements
        Built<
          OpaqueRegistrationFinishDataDevice,
          OpaqueRegistrationFinishDataDeviceBuilder
        > {
  @BuiltValueField(wireName: r'id')
  String get id;

  @BuiltValueField(wireName: r'name')
  String get name;

  @BuiltValueField(wireName: r'platform')
  OpaqueRegistrationFinishDataDevicePlatformEnum get platform;
  // enum platformEnum {  android,  ios,  macos,  windows,  linux,  };

  @BuiltValueField(wireName: r'clientVersion')
  String get clientVersion;

  @BuiltValueField(wireName: r'authGeneration')
  int get authGeneration;

  @BuiltValueField(wireName: r'status')
  OpaqueRegistrationFinishDataDeviceStatusEnum get status;
  // enum statusEnum {  active,  };

  @BuiltValueField(wireName: r'createdAt')
  DateTime get createdAt;

  @BuiltValueField(wireName: r'sessionGeneration')
  int get sessionGeneration;

  OpaqueRegistrationFinishDataDevice._();

  factory OpaqueRegistrationFinishDataDevice([
    void updates(OpaqueRegistrationFinishDataDeviceBuilder b),
  ]) = _$OpaqueRegistrationFinishDataDevice;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(OpaqueRegistrationFinishDataDeviceBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<OpaqueRegistrationFinishDataDevice> get serializer =>
      _$OpaqueRegistrationFinishDataDeviceSerializer();
}

class _$OpaqueRegistrationFinishDataDeviceSerializer
    implements PrimitiveSerializer<OpaqueRegistrationFinishDataDevice> {
  @override
  final Iterable<Type> types = const [
    OpaqueRegistrationFinishDataDevice,
    _$OpaqueRegistrationFinishDataDevice,
  ];

  @override
  final String wireName = r'OpaqueRegistrationFinishDataDevice';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    OpaqueRegistrationFinishDataDevice object, {
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
      specifiedType: const FullType(
        OpaqueRegistrationFinishDataDevicePlatformEnum,
      ),
    );
    yield r'clientVersion';
    yield serializers.serialize(
      object.clientVersion,
      specifiedType: const FullType(String),
    );
    yield r'authGeneration';
    yield serializers.serialize(
      object.authGeneration,
      specifiedType: const FullType(int),
    );
    yield r'status';
    yield serializers.serialize(
      object.status,
      specifiedType: const FullType(
        OpaqueRegistrationFinishDataDeviceStatusEnum,
      ),
    );
    yield r'createdAt';
    yield serializers.serialize(
      object.createdAt,
      specifiedType: const FullType(DateTime),
    );
    yield r'sessionGeneration';
    yield serializers.serialize(
      object.sessionGeneration,
      specifiedType: const FullType(int),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    OpaqueRegistrationFinishDataDevice object, {
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
    required OpaqueRegistrationFinishDataDeviceBuilder result,
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
                      OpaqueRegistrationFinishDataDevicePlatformEnum,
                    ),
                  )
                  as OpaqueRegistrationFinishDataDevicePlatformEnum;
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
        case r'authGeneration':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.authGeneration = valueDes;
          break;
        case r'status':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      OpaqueRegistrationFinishDataDeviceStatusEnum,
                    ),
                  )
                  as OpaqueRegistrationFinishDataDeviceStatusEnum;
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
        case r'sessionGeneration':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.sessionGeneration = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  OpaqueRegistrationFinishDataDevice deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = OpaqueRegistrationFinishDataDeviceBuilder();
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

class OpaqueRegistrationFinishDataDevicePlatformEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'android')
  static const OpaqueRegistrationFinishDataDevicePlatformEnum android =
      _$opaqueRegistrationFinishDataDevicePlatformEnum_android;
  @BuiltValueEnumConst(wireName: r'ios')
  static const OpaqueRegistrationFinishDataDevicePlatformEnum ios =
      _$opaqueRegistrationFinishDataDevicePlatformEnum_ios;
  @BuiltValueEnumConst(wireName: r'macos')
  static const OpaqueRegistrationFinishDataDevicePlatformEnum macos =
      _$opaqueRegistrationFinishDataDevicePlatformEnum_macos;
  @BuiltValueEnumConst(wireName: r'windows')
  static const OpaqueRegistrationFinishDataDevicePlatformEnum windows =
      _$opaqueRegistrationFinishDataDevicePlatformEnum_windows;
  @BuiltValueEnumConst(wireName: r'linux')
  static const OpaqueRegistrationFinishDataDevicePlatformEnum linux =
      _$opaqueRegistrationFinishDataDevicePlatformEnum_linux;

  static Serializer<OpaqueRegistrationFinishDataDevicePlatformEnum>
  get serializer => _$opaqueRegistrationFinishDataDevicePlatformEnumSerializer;

  const OpaqueRegistrationFinishDataDevicePlatformEnum._(String name)
    : super(name);

  static BuiltSet<OpaqueRegistrationFinishDataDevicePlatformEnum> get values =>
      _$opaqueRegistrationFinishDataDevicePlatformEnumValues;
  static OpaqueRegistrationFinishDataDevicePlatformEnum valueOf(String name) =>
      _$opaqueRegistrationFinishDataDevicePlatformEnumValueOf(name);
}

class OpaqueRegistrationFinishDataDeviceStatusEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'active')
  static const OpaqueRegistrationFinishDataDeviceStatusEnum active =
      _$opaqueRegistrationFinishDataDeviceStatusEnum_active;

  static Serializer<OpaqueRegistrationFinishDataDeviceStatusEnum>
  get serializer => _$opaqueRegistrationFinishDataDeviceStatusEnumSerializer;

  const OpaqueRegistrationFinishDataDeviceStatusEnum._(String name)
    : super(name);

  static BuiltSet<OpaqueRegistrationFinishDataDeviceStatusEnum> get values =>
      _$opaqueRegistrationFinishDataDeviceStatusEnumValues;
  static OpaqueRegistrationFinishDataDeviceStatusEnum valueOf(String name) =>
      _$opaqueRegistrationFinishDataDeviceStatusEnumValueOf(name);
}
