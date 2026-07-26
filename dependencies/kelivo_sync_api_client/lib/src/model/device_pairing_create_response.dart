//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/device_pairing_create_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'device_pairing_create_response.g.dart';

/// DevicePairingCreateResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class DevicePairingCreateResponse
    implements
        Built<DevicePairingCreateResponse, DevicePairingCreateResponseBuilder> {
  @BuiltValueField(wireName: r'data')
  DevicePairingCreateData get data;

  DevicePairingCreateResponse._();

  factory DevicePairingCreateResponse([
    void updates(DevicePairingCreateResponseBuilder b),
  ]) = _$DevicePairingCreateResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DevicePairingCreateResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DevicePairingCreateResponse> get serializer =>
      _$DevicePairingCreateResponseSerializer();
}

class _$DevicePairingCreateResponseSerializer
    implements PrimitiveSerializer<DevicePairingCreateResponse> {
  @override
  final Iterable<Type> types = const [
    DevicePairingCreateResponse,
    _$DevicePairingCreateResponse,
  ];

  @override
  final String wireName = r'DevicePairingCreateResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DevicePairingCreateResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(DevicePairingCreateData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    DevicePairingCreateResponse object, {
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
    required DevicePairingCreateResponseBuilder result,
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
                    specifiedType: const FullType(DevicePairingCreateData),
                  )
                  as DevicePairingCreateData;
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
  DevicePairingCreateResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DevicePairingCreateResponseBuilder();
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
