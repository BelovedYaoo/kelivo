//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/trusted_device_summary.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'revoke_trusted_device_data.g.dart';

/// RevokeTrustedDeviceData
///
/// Properties:
/// * [device]
@BuiltValue()
abstract class RevokeTrustedDeviceData
    implements Built<RevokeTrustedDeviceData, RevokeTrustedDeviceDataBuilder> {
  @BuiltValueField(wireName: r'device')
  TrustedDeviceSummary get device;

  RevokeTrustedDeviceData._();

  factory RevokeTrustedDeviceData([
    void updates(RevokeTrustedDeviceDataBuilder b),
  ]) = _$RevokeTrustedDeviceData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(RevokeTrustedDeviceDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<RevokeTrustedDeviceData> get serializer =>
      _$RevokeTrustedDeviceDataSerializer();
}

class _$RevokeTrustedDeviceDataSerializer
    implements PrimitiveSerializer<RevokeTrustedDeviceData> {
  @override
  final Iterable<Type> types = const [
    RevokeTrustedDeviceData,
    _$RevokeTrustedDeviceData,
  ];

  @override
  final String wireName = r'RevokeTrustedDeviceData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    RevokeTrustedDeviceData object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'device';
    yield serializers.serialize(
      object.device,
      specifiedType: const FullType(TrustedDeviceSummary),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    RevokeTrustedDeviceData object, {
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
    required RevokeTrustedDeviceDataBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'device':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(TrustedDeviceSummary),
                  )
                  as TrustedDeviceSummary;
          result.device.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  RevokeTrustedDeviceData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = RevokeTrustedDeviceDataBuilder();
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
