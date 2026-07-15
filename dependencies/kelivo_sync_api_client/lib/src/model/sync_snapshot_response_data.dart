//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:kelivo_sync_api_client/src/model/sync_record.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'sync_snapshot_response_data.g.dart';

/// SyncSnapshotResponseData
///
/// Properties:
/// * [records]
/// * [nextSnapshotCursor]
/// * [syncCursor]
/// * [hasMore]
@BuiltValue()
abstract class SyncSnapshotResponseData
    implements
        Built<SyncSnapshotResponseData, SyncSnapshotResponseDataBuilder> {
  @BuiltValueField(wireName: r'records')
  BuiltList<SyncRecord> get records;

  @BuiltValueField(wireName: r'nextSnapshotCursor')
  String? get nextSnapshotCursor;

  @BuiltValueField(wireName: r'syncCursor')
  String? get syncCursor;

  @BuiltValueField(wireName: r'hasMore')
  bool get hasMore;

  SyncSnapshotResponseData._();

  factory SyncSnapshotResponseData([
    void updates(SyncSnapshotResponseDataBuilder b),
  ]) = _$SyncSnapshotResponseData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SyncSnapshotResponseDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<SyncSnapshotResponseData> get serializer =>
      _$SyncSnapshotResponseDataSerializer();
}

class _$SyncSnapshotResponseDataSerializer
    implements PrimitiveSerializer<SyncSnapshotResponseData> {
  @override
  final Iterable<Type> types = const [
    SyncSnapshotResponseData,
    _$SyncSnapshotResponseData,
  ];

  @override
  final String wireName = r'SyncSnapshotResponseData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    SyncSnapshotResponseData object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'records';
    yield serializers.serialize(
      object.records,
      specifiedType: const FullType(BuiltList, [FullType(SyncRecord)]),
    );
    yield r'nextSnapshotCursor';
    yield object.nextSnapshotCursor == null
        ? null
        : serializers.serialize(
            object.nextSnapshotCursor,
            specifiedType: const FullType.nullable(String),
          );
    yield r'syncCursor';
    yield object.syncCursor == null
        ? null
        : serializers.serialize(
            object.syncCursor,
            specifiedType: const FullType.nullable(String),
          );
    yield r'hasMore';
    yield serializers.serialize(
      object.hasMore,
      specifiedType: const FullType(bool),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    SyncSnapshotResponseData object, {
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
    required SyncSnapshotResponseDataBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'records':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(BuiltList, [
                      FullType(SyncRecord),
                    ]),
                  )
                  as BuiltList<SyncRecord>;
          result.records.replace(valueDes);
          break;
        case r'nextSnapshotCursor':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType.nullable(String),
                  )
                  as String?;
          if (valueDes == null) continue;
          result.nextSnapshotCursor = valueDes;
          break;
        case r'syncCursor':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType.nullable(String),
                  )
                  as String?;
          if (valueDes == null) continue;
          result.syncCursor = valueDes;
          break;
        case r'hasMore':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(bool),
                  )
                  as bool;
          result.hasMore = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  SyncSnapshotResponseData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SyncSnapshotResponseDataBuilder();
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
