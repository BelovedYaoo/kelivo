//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'device_pairing_create_data_target_device.g.dart';

/// DevicePairingCreateDataTargetDevice
///
/// Properties:
/// * [id]
/// * [name]
/// * [platform]
/// * [clientVersion]
/// * [keyVersion]
/// * [authGeneration]
/// * [signingPublicKey]
/// * [keyAgreementPublicKey]
@BuiltValue()
abstract class DevicePairingCreateDataTargetDevice
    implements
        Built<
          DevicePairingCreateDataTargetDevice,
          DevicePairingCreateDataTargetDeviceBuilder
        > {
  @BuiltValueField(wireName: r'id')
  String get id;

  @BuiltValueField(wireName: r'name')
  String get name;

  @BuiltValueField(wireName: r'platform')
  DevicePairingCreateDataTargetDevicePlatformEnum get platform;
  // enum platformEnum {  android,  ios,  macos,  windows,  linux,  };

  @BuiltValueField(wireName: r'clientVersion')
  String get clientVersion;

  @BuiltValueField(wireName: r'keyVersion')
  int get keyVersion;

  @BuiltValueField(wireName: r'authGeneration')
  int get authGeneration;

  @BuiltValueField(wireName: r'signingPublicKey')
  String get signingPublicKey;

  @BuiltValueField(wireName: r'keyAgreementPublicKey')
  String get keyAgreementPublicKey;

  DevicePairingCreateDataTargetDevice._();

  factory DevicePairingCreateDataTargetDevice([
    void updates(DevicePairingCreateDataTargetDeviceBuilder b),
  ]) = _$DevicePairingCreateDataTargetDevice;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DevicePairingCreateDataTargetDeviceBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DevicePairingCreateDataTargetDevice> get serializer =>
      _$DevicePairingCreateDataTargetDeviceSerializer();
}

class _$DevicePairingCreateDataTargetDeviceSerializer
    implements PrimitiveSerializer<DevicePairingCreateDataTargetDevice> {
  @override
  final Iterable<Type> types = const [
    DevicePairingCreateDataTargetDevice,
    _$DevicePairingCreateDataTargetDevice,
  ];

  @override
  final String wireName = r'DevicePairingCreateDataTargetDevice';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DevicePairingCreateDataTargetDevice object, {
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
        DevicePairingCreateDataTargetDevicePlatformEnum,
      ),
    );
    yield r'clientVersion';
    yield serializers.serialize(
      object.clientVersion,
      specifiedType: const FullType(String),
    );
    yield r'keyVersion';
    yield serializers.serialize(
      object.keyVersion,
      specifiedType: const FullType(int),
    );
    yield r'authGeneration';
    yield serializers.serialize(
      object.authGeneration,
      specifiedType: const FullType(int),
    );
    yield r'signingPublicKey';
    yield serializers.serialize(
      object.signingPublicKey,
      specifiedType: const FullType(String),
    );
    yield r'keyAgreementPublicKey';
    yield serializers.serialize(
      object.keyAgreementPublicKey,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    DevicePairingCreateDataTargetDevice object, {
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
    required DevicePairingCreateDataTargetDeviceBuilder result,
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
                      DevicePairingCreateDataTargetDevicePlatformEnum,
                    ),
                  )
                  as DevicePairingCreateDataTargetDevicePlatformEnum;
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
        case r'keyVersion':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.keyVersion = valueDes;
          break;
        case r'authGeneration':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.authGeneration = valueDes;
          break;
        case r'signingPublicKey':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.signingPublicKey = valueDes;
          break;
        case r'keyAgreementPublicKey':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.keyAgreementPublicKey = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  DevicePairingCreateDataTargetDevice deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DevicePairingCreateDataTargetDeviceBuilder();
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

class DevicePairingCreateDataTargetDevicePlatformEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'android')
  static const DevicePairingCreateDataTargetDevicePlatformEnum android =
      _$devicePairingCreateDataTargetDevicePlatformEnum_android;
  @BuiltValueEnumConst(wireName: r'ios')
  static const DevicePairingCreateDataTargetDevicePlatformEnum ios =
      _$devicePairingCreateDataTargetDevicePlatformEnum_ios;
  @BuiltValueEnumConst(wireName: r'macos')
  static const DevicePairingCreateDataTargetDevicePlatformEnum macos =
      _$devicePairingCreateDataTargetDevicePlatformEnum_macos;
  @BuiltValueEnumConst(wireName: r'windows')
  static const DevicePairingCreateDataTargetDevicePlatformEnum windows =
      _$devicePairingCreateDataTargetDevicePlatformEnum_windows;
  @BuiltValueEnumConst(wireName: r'linux')
  static const DevicePairingCreateDataTargetDevicePlatformEnum linux =
      _$devicePairingCreateDataTargetDevicePlatformEnum_linux;

  static Serializer<DevicePairingCreateDataTargetDevicePlatformEnum>
  get serializer => _$devicePairingCreateDataTargetDevicePlatformEnumSerializer;

  const DevicePairingCreateDataTargetDevicePlatformEnum._(String name)
    : super(name);

  static BuiltSet<DevicePairingCreateDataTargetDevicePlatformEnum> get values =>
      _$devicePairingCreateDataTargetDevicePlatformEnumValues;
  static DevicePairingCreateDataTargetDevicePlatformEnum valueOf(String name) =>
      _$devicePairingCreateDataTargetDevicePlatformEnumValueOf(name);
}
