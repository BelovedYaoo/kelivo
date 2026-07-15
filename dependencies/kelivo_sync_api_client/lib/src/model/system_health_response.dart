//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/system_health_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'system_health_response.g.dart';

/// SystemHealthResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class SystemHealthResponse
    implements Built<SystemHealthResponse, SystemHealthResponseBuilder> {
  @BuiltValueField(wireName: r'data')
  SystemHealthData get data;

  SystemHealthResponse._();

  factory SystemHealthResponse([void updates(SystemHealthResponseBuilder b)]) =
      _$SystemHealthResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SystemHealthResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<SystemHealthResponse> get serializer =>
      _$SystemHealthResponseSerializer();
}

class _$SystemHealthResponseSerializer
    implements PrimitiveSerializer<SystemHealthResponse> {
  @override
  final Iterable<Type> types = const [
    SystemHealthResponse,
    _$SystemHealthResponse,
  ];

  @override
  final String wireName = r'SystemHealthResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    SystemHealthResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(SystemHealthData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    SystemHealthResponse object, {
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
    required SystemHealthResponseBuilder result,
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
                    specifiedType: const FullType(SystemHealthData),
                  )
                  as SystemHealthData;
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
  SystemHealthResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SystemHealthResponseBuilder();
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
