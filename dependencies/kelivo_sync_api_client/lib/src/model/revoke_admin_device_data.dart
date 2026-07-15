//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/admin_device_summary.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'revoke_admin_device_data.g.dart';

/// RevokeAdminDeviceData
///
/// Properties:
/// * [device]
@BuiltValue()
abstract class RevokeAdminDeviceData
    implements Built<RevokeAdminDeviceData, RevokeAdminDeviceDataBuilder> {
  @BuiltValueField(wireName: r'device')
  AdminDeviceSummary get device;

  RevokeAdminDeviceData._();

  factory RevokeAdminDeviceData([
    void updates(RevokeAdminDeviceDataBuilder b),
  ]) = _$RevokeAdminDeviceData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(RevokeAdminDeviceDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<RevokeAdminDeviceData> get serializer =>
      _$RevokeAdminDeviceDataSerializer();
}

class _$RevokeAdminDeviceDataSerializer
    implements PrimitiveSerializer<RevokeAdminDeviceData> {
  @override
  final Iterable<Type> types = const [
    RevokeAdminDeviceData,
    _$RevokeAdminDeviceData,
  ];

  @override
  final String wireName = r'RevokeAdminDeviceData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    RevokeAdminDeviceData object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'device';
    yield serializers.serialize(
      object.device,
      specifiedType: const FullType(AdminDeviceSummary),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    RevokeAdminDeviceData object, {
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
    required RevokeAdminDeviceDataBuilder result,
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
                    specifiedType: const FullType(AdminDeviceSummary),
                  )
                  as AdminDeviceSummary;
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
  RevokeAdminDeviceData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = RevokeAdminDeviceDataBuilder();
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
