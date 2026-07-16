//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/list_sync_conflicts_response_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'list_sync_conflicts_response.g.dart';

/// ListSyncConflictsResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class ListSyncConflictsResponse
    implements
        Built<ListSyncConflictsResponse, ListSyncConflictsResponseBuilder> {
  @BuiltValueField(wireName: r'data')
  ListSyncConflictsResponseData get data;

  ListSyncConflictsResponse._();

  factory ListSyncConflictsResponse([
    void updates(ListSyncConflictsResponseBuilder b),
  ]) = _$ListSyncConflictsResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ListSyncConflictsResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ListSyncConflictsResponse> get serializer =>
      _$ListSyncConflictsResponseSerializer();
}

class _$ListSyncConflictsResponseSerializer
    implements PrimitiveSerializer<ListSyncConflictsResponse> {
  @override
  final Iterable<Type> types = const [
    ListSyncConflictsResponse,
    _$ListSyncConflictsResponse,
  ];

  @override
  final String wireName = r'ListSyncConflictsResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ListSyncConflictsResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(ListSyncConflictsResponseData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ListSyncConflictsResponse object, {
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
    required ListSyncConflictsResponseBuilder result,
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
                      ListSyncConflictsResponseData,
                    ),
                  )
                  as ListSyncConflictsResponseData;
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
  ListSyncConflictsResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ListSyncConflictsResponseBuilder();
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
