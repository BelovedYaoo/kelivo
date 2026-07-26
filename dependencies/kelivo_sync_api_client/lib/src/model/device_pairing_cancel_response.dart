//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/device_pairing_cancel_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'device_pairing_cancel_response.g.dart';

/// DevicePairingCancelResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class DevicePairingCancelResponse
    implements
        Built<DevicePairingCancelResponse, DevicePairingCancelResponseBuilder> {
  @BuiltValueField(wireName: r'data')
  DevicePairingCancelData get data;

  DevicePairingCancelResponse._();

  factory DevicePairingCancelResponse([
    void updates(DevicePairingCancelResponseBuilder b),
  ]) = _$DevicePairingCancelResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DevicePairingCancelResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DevicePairingCancelResponse> get serializer =>
      _$DevicePairingCancelResponseSerializer();
}

class _$DevicePairingCancelResponseSerializer
    implements PrimitiveSerializer<DevicePairingCancelResponse> {
  @override
  final Iterable<Type> types = const [
    DevicePairingCancelResponse,
    _$DevicePairingCancelResponse,
  ];

  @override
  final String wireName = r'DevicePairingCancelResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DevicePairingCancelResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(DevicePairingCancelData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    DevicePairingCancelResponse object, {
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
    required DevicePairingCancelResponseBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'data':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(DevicePairingCancelData),
                  )
                  as DevicePairingCancelData;
          result.data.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  DevicePairingCancelResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DevicePairingCancelResponseBuilder();
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
