//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/opaque_login_start_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'opaque_login_start_response.g.dart';

/// OpaqueLoginStartResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class OpaqueLoginStartResponse
    implements
        Built<OpaqueLoginStartResponse, OpaqueLoginStartResponseBuilder> {
  @BuiltValueField(wireName: r'data')
  OpaqueLoginStartData get data;

  OpaqueLoginStartResponse._();

  factory OpaqueLoginStartResponse([
    void updates(OpaqueLoginStartResponseBuilder b),
  ]) = _$OpaqueLoginStartResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(OpaqueLoginStartResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<OpaqueLoginStartResponse> get serializer =>
      _$OpaqueLoginStartResponseSerializer();
}

class _$OpaqueLoginStartResponseSerializer
    implements PrimitiveSerializer<OpaqueLoginStartResponse> {
  @override
  final Iterable<Type> types = const [
    OpaqueLoginStartResponse,
    _$OpaqueLoginStartResponse,
  ];

  @override
  final String wireName = r'OpaqueLoginStartResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    OpaqueLoginStartResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(OpaqueLoginStartData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    OpaqueLoginStartResponse object, {
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
    required OpaqueLoginStartResponseBuilder result,
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
                    specifiedType: const FullType(OpaqueLoginStartData),
                  )
                  as OpaqueLoginStartData;
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
  OpaqueLoginStartResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = OpaqueLoginStartResponseBuilder();
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
