//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/sync_push_response_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'push_sync_changes_response.g.dart';

/// PushSyncChangesResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class PushSyncChangesResponse
    implements Built<PushSyncChangesResponse, PushSyncChangesResponseBuilder> {
  @BuiltValueField(wireName: r'data')
  SyncPushResponseData get data;

  PushSyncChangesResponse._();

  factory PushSyncChangesResponse([
    void updates(PushSyncChangesResponseBuilder b),
  ]) = _$PushSyncChangesResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(PushSyncChangesResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<PushSyncChangesResponse> get serializer =>
      _$PushSyncChangesResponseSerializer();
}

class _$PushSyncChangesResponseSerializer
    implements PrimitiveSerializer<PushSyncChangesResponse> {
  @override
  final Iterable<Type> types = const [
    PushSyncChangesResponse,
    _$PushSyncChangesResponse,
  ];

  @override
  final String wireName = r'PushSyncChangesResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    PushSyncChangesResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(SyncPushResponseData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    PushSyncChangesResponse object, {
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
    required PushSyncChangesResponseBuilder result,
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
                    specifiedType: const FullType(SyncPushResponseData),
                  )
                  as SyncPushResponseData;
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
  PushSyncChangesResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = PushSyncChangesResponseBuilder();
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
