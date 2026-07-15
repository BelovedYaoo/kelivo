//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/sync_pull_response_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'pull_sync_changes_response.g.dart';

/// PullSyncChangesResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class PullSyncChangesResponse
    implements Built<PullSyncChangesResponse, PullSyncChangesResponseBuilder> {
  @BuiltValueField(wireName: r'data')
  SyncPullResponseData get data;

  PullSyncChangesResponse._();

  factory PullSyncChangesResponse([
    void updates(PullSyncChangesResponseBuilder b),
  ]) = _$PullSyncChangesResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(PullSyncChangesResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<PullSyncChangesResponse> get serializer =>
      _$PullSyncChangesResponseSerializer();
}

class _$PullSyncChangesResponseSerializer
    implements PrimitiveSerializer<PullSyncChangesResponse> {
  @override
  final Iterable<Type> types = const [
    PullSyncChangesResponse,
    _$PullSyncChangesResponse,
  ];

  @override
  final String wireName = r'PullSyncChangesResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    PullSyncChangesResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(SyncPullResponseData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    PullSyncChangesResponse object, {
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
    required PullSyncChangesResponseBuilder result,
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
                    specifiedType: const FullType(SyncPullResponseData),
                  )
                  as SyncPullResponseData;
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
  PullSyncChangesResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = PullSyncChangesResponseBuilder();
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
