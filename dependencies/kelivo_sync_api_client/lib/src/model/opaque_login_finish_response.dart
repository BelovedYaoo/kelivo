//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/opaque_login_finish_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'opaque_login_finish_response.g.dart';

/// OpaqueLoginFinishResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class OpaqueLoginFinishResponse
    implements
        Built<OpaqueLoginFinishResponse, OpaqueLoginFinishResponseBuilder> {
  @BuiltValueField(wireName: r'data')
  OpaqueLoginFinishData get data;

  OpaqueLoginFinishResponse._();

  factory OpaqueLoginFinishResponse([
    void updates(OpaqueLoginFinishResponseBuilder b),
  ]) = _$OpaqueLoginFinishResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(OpaqueLoginFinishResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<OpaqueLoginFinishResponse> get serializer =>
      _$OpaqueLoginFinishResponseSerializer();
}

class _$OpaqueLoginFinishResponseSerializer
    implements PrimitiveSerializer<OpaqueLoginFinishResponse> {
  @override
  final Iterable<Type> types = const [
    OpaqueLoginFinishResponse,
    _$OpaqueLoginFinishResponse,
  ];

  @override
  final String wireName = r'OpaqueLoginFinishResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    OpaqueLoginFinishResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(OpaqueLoginFinishData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    OpaqueLoginFinishResponse object, {
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
    required OpaqueLoginFinishResponseBuilder result,
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
                    specifiedType: const FullType(OpaqueLoginFinishData),
                  )
                  as OpaqueLoginFinishData;
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
  OpaqueLoginFinishResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = OpaqueLoginFinishResponseBuilder();
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
