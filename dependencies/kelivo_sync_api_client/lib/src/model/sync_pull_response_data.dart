//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/sync_change.dart';
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'sync_pull_response_data.g.dart';

/// SyncPullResponseData
///
/// Properties:
/// * [changes]
/// * [nextCursor]
/// * [hasMore]
/// * [resetRequired]
@BuiltValue()
abstract class SyncPullResponseData
    implements Built<SyncPullResponseData, SyncPullResponseDataBuilder> {
  @BuiltValueField(wireName: r'changes')
  BuiltList<SyncChange> get changes;

  @BuiltValueField(wireName: r'nextCursor')
  String get nextCursor;

  @BuiltValueField(wireName: r'hasMore')
  bool get hasMore;

  @BuiltValueField(wireName: r'resetRequired')
  bool get resetRequired;

  SyncPullResponseData._();

  factory SyncPullResponseData([void updates(SyncPullResponseDataBuilder b)]) =
      _$SyncPullResponseData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SyncPullResponseDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<SyncPullResponseData> get serializer =>
      _$SyncPullResponseDataSerializer();
}

class _$SyncPullResponseDataSerializer
    implements PrimitiveSerializer<SyncPullResponseData> {
  @override
  final Iterable<Type> types = const [
    SyncPullResponseData,
    _$SyncPullResponseData,
  ];

  @override
  final String wireName = r'SyncPullResponseData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    SyncPullResponseData object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'changes';
    yield serializers.serialize(
      object.changes,
      specifiedType: const FullType(BuiltList, [FullType(SyncChange)]),
    );
    yield r'nextCursor';
    yield serializers.serialize(
      object.nextCursor,
      specifiedType: const FullType(String),
    );
    yield r'hasMore';
    yield serializers.serialize(
      object.hasMore,
      specifiedType: const FullType(bool),
    );
    yield r'resetRequired';
    yield serializers.serialize(
      object.resetRequired,
      specifiedType: const FullType(bool),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    SyncPullResponseData object, {
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
    required SyncPullResponseDataBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'changes':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(BuiltList, [
                      FullType(SyncChange),
                    ]),
                  )
                  as BuiltList<SyncChange>;
          result.changes.replace(valueDes);
          break;
        case r'nextCursor':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.nextCursor = valueDes;
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
        case r'resetRequired':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(bool),
                  )
                  as bool;
          result.resetRequired = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  SyncPullResponseData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SyncPullResponseDataBuilder();
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
