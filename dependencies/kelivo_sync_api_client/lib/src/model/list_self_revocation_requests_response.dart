//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/self_revocation_request_list_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'list_self_revocation_requests_response.g.dart';

/// ListSelfRevocationRequestsResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class ListSelfRevocationRequestsResponse
    implements
        Built<
          ListSelfRevocationRequestsResponse,
          ListSelfRevocationRequestsResponseBuilder
        > {
  @BuiltValueField(wireName: r'data')
  SelfRevocationRequestListData get data;

  ListSelfRevocationRequestsResponse._();

  factory ListSelfRevocationRequestsResponse([
    void updates(ListSelfRevocationRequestsResponseBuilder b),
  ]) = _$ListSelfRevocationRequestsResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ListSelfRevocationRequestsResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ListSelfRevocationRequestsResponse> get serializer =>
      _$ListSelfRevocationRequestsResponseSerializer();
}

class _$ListSelfRevocationRequestsResponseSerializer
    implements PrimitiveSerializer<ListSelfRevocationRequestsResponse> {
  @override
  final Iterable<Type> types = const [
    ListSelfRevocationRequestsResponse,
    _$ListSelfRevocationRequestsResponse,
  ];

  @override
  final String wireName = r'ListSelfRevocationRequestsResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ListSelfRevocationRequestsResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(SelfRevocationRequestListData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ListSelfRevocationRequestsResponse object, {
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
    required ListSelfRevocationRequestsResponseBuilder result,
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
                    specifiedType: const FullType(
                      SelfRevocationRequestListData,
                    ),
                  )
                  as SelfRevocationRequestListData;
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
  ListSelfRevocationRequestsResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ListSelfRevocationRequestsResponseBuilder();
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
