//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'sync_snapshot_request.g.dart';

/// SyncSnapshotRequest
///
/// Properties:
/// * [snapshotCursor]
/// * [limit]
@BuiltValue()
abstract class SyncSnapshotRequest
    implements Built<SyncSnapshotRequest, SyncSnapshotRequestBuilder> {
  @BuiltValueField(wireName: r'snapshotCursor')
  String? get snapshotCursor;

  @BuiltValueField(wireName: r'limit')
  int? get limit;

  SyncSnapshotRequest._();

  factory SyncSnapshotRequest([void updates(SyncSnapshotRequestBuilder b)]) =
      _$SyncSnapshotRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SyncSnapshotRequestBuilder b) => b..limit = 10;

  @BuiltValueSerializer(custom: true)
  static Serializer<SyncSnapshotRequest> get serializer =>
      _$SyncSnapshotRequestSerializer();
}

class _$SyncSnapshotRequestSerializer
    implements PrimitiveSerializer<SyncSnapshotRequest> {
  @override
  final Iterable<Type> types = const [
    SyncSnapshotRequest,
    _$SyncSnapshotRequest,
  ];

  @override
  final String wireName = r'SyncSnapshotRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    SyncSnapshotRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    if (object.snapshotCursor != null) {
      yield r'snapshotCursor';
      yield serializers.serialize(
        object.snapshotCursor,
        specifiedType: const FullType.nullable(String),
      );
    }
    if (object.limit != null) {
      yield r'limit';
      yield serializers.serialize(
        object.limit,
        specifiedType: const FullType(int),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    SyncSnapshotRequest object, {
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
    required SyncSnapshotRequestBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'snapshotCursor':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType.nullable(String),
                  )
                  as String?;
          if (valueDes == null) continue;
          result.snapshotCursor = valueDes;
          break;
        case r'limit':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.limit = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  SyncSnapshotRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SyncSnapshotRequestBuilder();
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
