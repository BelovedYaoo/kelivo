//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/revoke_trusted_device_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'revoke_trusted_device_response.g.dart';

/// RevokeTrustedDeviceResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class RevokeTrustedDeviceResponse
    implements
        Built<RevokeTrustedDeviceResponse, RevokeTrustedDeviceResponseBuilder> {
  @BuiltValueField(wireName: r'data')
  RevokeTrustedDeviceData get data;

  RevokeTrustedDeviceResponse._();

  factory RevokeTrustedDeviceResponse([
    void updates(RevokeTrustedDeviceResponseBuilder b),
  ]) = _$RevokeTrustedDeviceResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(RevokeTrustedDeviceResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<RevokeTrustedDeviceResponse> get serializer =>
      _$RevokeTrustedDeviceResponseSerializer();
}

class _$RevokeTrustedDeviceResponseSerializer
    implements PrimitiveSerializer<RevokeTrustedDeviceResponse> {
  @override
  final Iterable<Type> types = const [
    RevokeTrustedDeviceResponse,
    _$RevokeTrustedDeviceResponse,
  ];

  @override
  final String wireName = r'RevokeTrustedDeviceResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    RevokeTrustedDeviceResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(RevokeTrustedDeviceData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    RevokeTrustedDeviceResponse object, {
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
    required RevokeTrustedDeviceResponseBuilder result,
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
                    specifiedType: const FullType(RevokeTrustedDeviceData),
                  )
                  as RevokeTrustedDeviceData;
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
  RevokeTrustedDeviceResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = RevokeTrustedDeviceResponseBuilder();
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
