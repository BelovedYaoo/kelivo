//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/sync_snapshot_response_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'pull_sync_snapshot_response.g.dart';

/// PullSyncSnapshotResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class PullSyncSnapshotResponse
    implements
        Built<PullSyncSnapshotResponse, PullSyncSnapshotResponseBuilder> {
  @BuiltValueField(wireName: r'data')
  SyncSnapshotResponseData get data;

  PullSyncSnapshotResponse._();

  factory PullSyncSnapshotResponse([
    void updates(PullSyncSnapshotResponseBuilder b),
  ]) = _$PullSyncSnapshotResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(PullSyncSnapshotResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<PullSyncSnapshotResponse> get serializer =>
      _$PullSyncSnapshotResponseSerializer();
}

class _$PullSyncSnapshotResponseSerializer
    implements PrimitiveSerializer<PullSyncSnapshotResponse> {
  @override
  final Iterable<Type> types = const [
    PullSyncSnapshotResponse,
    _$PullSyncSnapshotResponse,
  ];

  @override
  final String wireName = r'PullSyncSnapshotResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    PullSyncSnapshotResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(SyncSnapshotResponseData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    PullSyncSnapshotResponse object, {
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
    required PullSyncSnapshotResponseBuilder result,
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
                    specifiedType: const FullType(SyncSnapshotResponseData),
                  )
                  as SyncSnapshotResponseData;
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
  PullSyncSnapshotResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = PullSyncSnapshotResponseBuilder();
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
