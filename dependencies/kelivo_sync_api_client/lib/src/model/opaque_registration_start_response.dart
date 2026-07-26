//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/opaque_registration_start_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'opaque_registration_start_response.g.dart';

/// OpaqueRegistrationStartResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class OpaqueRegistrationStartResponse
    implements
        Built<
          OpaqueRegistrationStartResponse,
          OpaqueRegistrationStartResponseBuilder
        > {
  @BuiltValueField(wireName: r'data')
  OpaqueRegistrationStartData get data;

  OpaqueRegistrationStartResponse._();

  factory OpaqueRegistrationStartResponse([
    void updates(OpaqueRegistrationStartResponseBuilder b),
  ]) = _$OpaqueRegistrationStartResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(OpaqueRegistrationStartResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<OpaqueRegistrationStartResponse> get serializer =>
      _$OpaqueRegistrationStartResponseSerializer();
}

class _$OpaqueRegistrationStartResponseSerializer
    implements PrimitiveSerializer<OpaqueRegistrationStartResponse> {
  @override
  final Iterable<Type> types = const [
    OpaqueRegistrationStartResponse,
    _$OpaqueRegistrationStartResponse,
  ];

  @override
  final String wireName = r'OpaqueRegistrationStartResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    OpaqueRegistrationStartResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(OpaqueRegistrationStartData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    OpaqueRegistrationStartResponse object, {
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
    required OpaqueRegistrationStartResponseBuilder result,
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
                    specifiedType: const FullType(OpaqueRegistrationStartData),
                  )
                  as OpaqueRegistrationStartData;
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
  OpaqueRegistrationStartResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = OpaqueRegistrationStartResponseBuilder();
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
