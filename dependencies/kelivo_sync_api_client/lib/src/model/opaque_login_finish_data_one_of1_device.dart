//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'opaque_login_finish_data_one_of1_device.g.dart';

/// OpaqueLoginFinishDataOneOf1Device
///
/// Properties:
/// * [id]
/// * [name]
/// * [platform]
/// * [clientVersion]
/// * [status]
/// * [createdAt]
@BuiltValue()
abstract class OpaqueLoginFinishDataOneOf1Device
    implements
        Built<
          OpaqueLoginFinishDataOneOf1Device,
          OpaqueLoginFinishDataOneOf1DeviceBuilder
        > {
  @BuiltValueField(wireName: r'id')
  String get id;

  @BuiltValueField(wireName: r'name')
  String get name;

  @BuiltValueField(wireName: r'platform')
  OpaqueLoginFinishDataOneOf1DevicePlatformEnum get platform;
  // enum platformEnum {  android,  ios,  macos,  windows,  linux,  };

  @BuiltValueField(wireName: r'clientVersion')
  String get clientVersion;

  @BuiltValueField(wireName: r'status')
  OpaqueLoginFinishDataOneOf1DeviceStatusEnum get status;
  // enum statusEnum {  pending,  };

  @BuiltValueField(wireName: r'createdAt')
  DateTime get createdAt;

  OpaqueLoginFinishDataOneOf1Device._();

  factory OpaqueLoginFinishDataOneOf1Device([
    void updates(OpaqueLoginFinishDataOneOf1DeviceBuilder b),
  ]) = _$OpaqueLoginFinishDataOneOf1Device;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(OpaqueLoginFinishDataOneOf1DeviceBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<OpaqueLoginFinishDataOneOf1Device> get serializer =>
      _$OpaqueLoginFinishDataOneOf1DeviceSerializer();
}

class _$OpaqueLoginFinishDataOneOf1DeviceSerializer
    implements PrimitiveSerializer<OpaqueLoginFinishDataOneOf1Device> {
  @override
  final Iterable<Type> types = const [
    OpaqueLoginFinishDataOneOf1Device,
    _$OpaqueLoginFinishDataOneOf1Device,
  ];

  @override
  final String wireName = r'OpaqueLoginFinishDataOneOf1Device';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    OpaqueLoginFinishDataOneOf1Device object, {
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
        OpaqueLoginFinishDataOneOf1DevicePlatformEnum,
      ),
    );
    yield r'clientVersion';
    yield serializers.serialize(
      object.clientVersion,
      specifiedType: const FullType(String),
    );
    yield r'status';
    yield serializers.serialize(
      object.status,
      specifiedType: const FullType(
        OpaqueLoginFinishDataOneOf1DeviceStatusEnum,
      ),
    );
    yield r'createdAt';
    yield serializers.serialize(
      object.createdAt,
      specifiedType: const FullType(DateTime),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    OpaqueLoginFinishDataOneOf1Device object, {
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
    required OpaqueLoginFinishDataOneOf1DeviceBuilder result,
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
                      OpaqueLoginFinishDataOneOf1DevicePlatformEnum,
                    ),
                  )
                  as OpaqueLoginFinishDataOneOf1DevicePlatformEnum;
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
                      OpaqueLoginFinishDataOneOf1DeviceStatusEnum,
                    ),
                  )
                  as OpaqueLoginFinishDataOneOf1DeviceStatusEnum;
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
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  OpaqueLoginFinishDataOneOf1Device deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = OpaqueLoginFinishDataOneOf1DeviceBuilder();
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

class OpaqueLoginFinishDataOneOf1DevicePlatformEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'android')
  static const OpaqueLoginFinishDataOneOf1DevicePlatformEnum android =
      _$opaqueLoginFinishDataOneOf1DevicePlatformEnum_android;
  @BuiltValueEnumConst(wireName: r'ios')
  static const OpaqueLoginFinishDataOneOf1DevicePlatformEnum ios =
      _$opaqueLoginFinishDataOneOf1DevicePlatformEnum_ios;
  @BuiltValueEnumConst(wireName: r'macos')
  static const OpaqueLoginFinishDataOneOf1DevicePlatformEnum macos =
      _$opaqueLoginFinishDataOneOf1DevicePlatformEnum_macos;
  @BuiltValueEnumConst(wireName: r'windows')
  static const OpaqueLoginFinishDataOneOf1DevicePlatformEnum windows =
      _$opaqueLoginFinishDataOneOf1DevicePlatformEnum_windows;
  @BuiltValueEnumConst(wireName: r'linux')
  static const OpaqueLoginFinishDataOneOf1DevicePlatformEnum linux =
      _$opaqueLoginFinishDataOneOf1DevicePlatformEnum_linux;

  static Serializer<OpaqueLoginFinishDataOneOf1DevicePlatformEnum>
  get serializer => _$opaqueLoginFinishDataOneOf1DevicePlatformEnumSerializer;

  const OpaqueLoginFinishDataOneOf1DevicePlatformEnum._(String name)
    : super(name);

  static BuiltSet<OpaqueLoginFinishDataOneOf1DevicePlatformEnum> get values =>
      _$opaqueLoginFinishDataOneOf1DevicePlatformEnumValues;
  static OpaqueLoginFinishDataOneOf1DevicePlatformEnum valueOf(String name) =>
      _$opaqueLoginFinishDataOneOf1DevicePlatformEnumValueOf(name);
}

class OpaqueLoginFinishDataOneOf1DeviceStatusEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'pending')
  static const OpaqueLoginFinishDataOneOf1DeviceStatusEnum pending =
      _$opaqueLoginFinishDataOneOf1DeviceStatusEnum_pending;

  static Serializer<OpaqueLoginFinishDataOneOf1DeviceStatusEnum>
  get serializer => _$opaqueLoginFinishDataOneOf1DeviceStatusEnumSerializer;

  const OpaqueLoginFinishDataOneOf1DeviceStatusEnum._(String name)
    : super(name);

  static BuiltSet<OpaqueLoginFinishDataOneOf1DeviceStatusEnum> get values =>
      _$opaqueLoginFinishDataOneOf1DeviceStatusEnumValues;
  static OpaqueLoginFinishDataOneOf1DeviceStatusEnum valueOf(String name) =>
      _$opaqueLoginFinishDataOneOf1DeviceStatusEnumValueOf(name);
}
