//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/device_session_summary.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'revoke_device_session_data.g.dart';

/// RevokeDeviceSessionData
///
/// Properties:
/// * [device]
@BuiltValue()
abstract class RevokeDeviceSessionData
    implements Built<RevokeDeviceSessionData, RevokeDeviceSessionDataBuilder> {
  @BuiltValueField(wireName: r'device')
  DeviceSessionSummary get device;

  RevokeDeviceSessionData._();

  factory RevokeDeviceSessionData([
    void updates(RevokeDeviceSessionDataBuilder b),
  ]) = _$RevokeDeviceSessionData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(RevokeDeviceSessionDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<RevokeDeviceSessionData> get serializer =>
      _$RevokeDeviceSessionDataSerializer();
}

class _$RevokeDeviceSessionDataSerializer
    implements PrimitiveSerializer<RevokeDeviceSessionData> {
  @override
  final Iterable<Type> types = const [
    RevokeDeviceSessionData,
    _$RevokeDeviceSessionData,
  ];

  @override
  final String wireName = r'RevokeDeviceSessionData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    RevokeDeviceSessionData object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'device';
    yield serializers.serialize(
      object.device,
      specifiedType: const FullType(DeviceSessionSummary),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    RevokeDeviceSessionData object, {
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
    required RevokeDeviceSessionDataBuilder result,
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
                    specifiedType: const FullType(DeviceSessionSummary),
                  )
                  as DeviceSessionSummary;
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
  RevokeDeviceSessionData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = RevokeDeviceSessionDataBuilder();
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
