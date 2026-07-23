//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/sync_snapshot_response_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'pull_encrypted_sync_snapshot_response.g.dart';

/// PullEncryptedSyncSnapshotResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class PullEncryptedSyncSnapshotResponse
    implements
        Built<
          PullEncryptedSyncSnapshotResponse,
          PullEncryptedSyncSnapshotResponseBuilder
        > {
  @BuiltValueField(wireName: r'data')
  SyncSnapshotResponseData get data;

  PullEncryptedSyncSnapshotResponse._();

  factory PullEncryptedSyncSnapshotResponse([
    void updates(PullEncryptedSyncSnapshotResponseBuilder b),
  ]) = _$PullEncryptedSyncSnapshotResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(PullEncryptedSyncSnapshotResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<PullEncryptedSyncSnapshotResponse> get serializer =>
      _$PullEncryptedSyncSnapshotResponseSerializer();
}

class _$PullEncryptedSyncSnapshotResponseSerializer
    implements PrimitiveSerializer<PullEncryptedSyncSnapshotResponse> {
  @override
  final Iterable<Type> types = const [
    PullEncryptedSyncSnapshotResponse,
    _$PullEncryptedSyncSnapshotResponse,
  ];

  @override
  final String wireName = r'PullEncryptedSyncSnapshotResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    PullEncryptedSyncSnapshotResponse object, {
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
    PullEncryptedSyncSnapshotResponse object, {
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
    required PullEncryptedSyncSnapshotResponseBuilder result,
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
  PullEncryptedSyncSnapshotResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = PullEncryptedSyncSnapshotResponseBuilder();
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
