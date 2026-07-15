//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/list_device_sessions_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'list_device_sessions_response.g.dart';

/// ListDeviceSessionsResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class ListDeviceSessionsResponse
    implements
        Built<ListDeviceSessionsResponse, ListDeviceSessionsResponseBuilder> {
  @BuiltValueField(wireName: r'data')
  ListDeviceSessionsData get data;

  ListDeviceSessionsResponse._();

  factory ListDeviceSessionsResponse([
    void updates(ListDeviceSessionsResponseBuilder b),
  ]) = _$ListDeviceSessionsResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ListDeviceSessionsResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ListDeviceSessionsResponse> get serializer =>
      _$ListDeviceSessionsResponseSerializer();
}

class _$ListDeviceSessionsResponseSerializer
    implements PrimitiveSerializer<ListDeviceSessionsResponse> {
  @override
  final Iterable<Type> types = const [
    ListDeviceSessionsResponse,
    _$ListDeviceSessionsResponse,
  ];

  @override
  final String wireName = r'ListDeviceSessionsResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ListDeviceSessionsResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(ListDeviceSessionsData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ListDeviceSessionsResponse object, {
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
    required ListDeviceSessionsResponseBuilder result,
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
                    specifiedType: const FullType(ListDeviceSessionsData),
                  )
                  as ListDeviceSessionsData;
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
  ListDeviceSessionsResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ListDeviceSessionsResponseBuilder();
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
