//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/opaque_registration_finish_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'opaque_registration_finish_response.g.dart';

/// OpaqueRegistrationFinishResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class OpaqueRegistrationFinishResponse
    implements
        Built<
          OpaqueRegistrationFinishResponse,
          OpaqueRegistrationFinishResponseBuilder
        > {
  @BuiltValueField(wireName: r'data')
  OpaqueRegistrationFinishData get data;

  OpaqueRegistrationFinishResponse._();

  factory OpaqueRegistrationFinishResponse([
    void updates(OpaqueRegistrationFinishResponseBuilder b),
  ]) = _$OpaqueRegistrationFinishResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(OpaqueRegistrationFinishResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<OpaqueRegistrationFinishResponse> get serializer =>
      _$OpaqueRegistrationFinishResponseSerializer();
}

class _$OpaqueRegistrationFinishResponseSerializer
    implements PrimitiveSerializer<OpaqueRegistrationFinishResponse> {
  @override
  final Iterable<Type> types = const [
    OpaqueRegistrationFinishResponse,
    _$OpaqueRegistrationFinishResponse,
  ];

  @override
  final String wireName = r'OpaqueRegistrationFinishResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    OpaqueRegistrationFinishResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(OpaqueRegistrationFinishData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    OpaqueRegistrationFinishResponse object, {
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
    required OpaqueRegistrationFinishResponseBuilder result,
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
                    specifiedType: const FullType(OpaqueRegistrationFinishData),
                  )
                  as OpaqueRegistrationFinishData;
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
  OpaqueRegistrationFinishResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = OpaqueRegistrationFinishResponseBuilder();
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
