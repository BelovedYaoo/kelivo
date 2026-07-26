//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/device_pairing_consume_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'device_pairing_consume_response.g.dart';

/// DevicePairingConsumeResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class DevicePairingConsumeResponse
    implements
        Built<
          DevicePairingConsumeResponse,
          DevicePairingConsumeResponseBuilder
        > {
  @BuiltValueField(wireName: r'data')
  DevicePairingConsumeData get data;

  DevicePairingConsumeResponse._();

  factory DevicePairingConsumeResponse([
    void updates(DevicePairingConsumeResponseBuilder b),
  ]) = _$DevicePairingConsumeResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DevicePairingConsumeResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DevicePairingConsumeResponse> get serializer =>
      _$DevicePairingConsumeResponseSerializer();
}

class _$DevicePairingConsumeResponseSerializer
    implements PrimitiveSerializer<DevicePairingConsumeResponse> {
  @override
  final Iterable<Type> types = const [
    DevicePairingConsumeResponse,
    _$DevicePairingConsumeResponse,
  ];

  @override
  final String wireName = r'DevicePairingConsumeResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DevicePairingConsumeResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(DevicePairingConsumeData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    DevicePairingConsumeResponse object, {
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
    required DevicePairingConsumeResponseBuilder result,
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
                    specifiedType: const FullType(DevicePairingConsumeData),
                  )
                  as DevicePairingConsumeData;
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
  DevicePairingConsumeResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DevicePairingConsumeResponseBuilder();
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
