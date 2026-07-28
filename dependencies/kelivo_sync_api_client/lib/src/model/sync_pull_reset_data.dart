//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/sync_change.dart';
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'sync_pull_reset_data.g.dart';

/// SyncPullResetData
///
/// Properties:
/// * [changes]
/// * [nextCursor]
/// * [hasMore]
/// * [resetRequired]
@BuiltValue()
abstract class SyncPullResetData
    implements Built<SyncPullResetData, SyncPullResetDataBuilder> {
  @BuiltValueField(wireName: r'changes')
  BuiltList<SyncChange> get changes;

  @BuiltValueField(wireName: r'nextCursor')
  SyncPullResetDataNextCursorEnum? get nextCursor;
  // enum nextCursorEnum {  ,  };

  @BuiltValueField(wireName: r'hasMore')
  bool get hasMore;

  @BuiltValueField(wireName: r'resetRequired')
  bool get resetRequired;

  SyncPullResetData._();

  factory SyncPullResetData([void updates(SyncPullResetDataBuilder b)]) =
      _$SyncPullResetData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SyncPullResetDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<SyncPullResetData> get serializer =>
      _$SyncPullResetDataSerializer();
}

class _$SyncPullResetDataSerializer
    implements PrimitiveSerializer<SyncPullResetData> {
  @override
  final Iterable<Type> types = const [SyncPullResetData, _$SyncPullResetData];

  @override
  final String wireName = r'SyncPullResetData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    SyncPullResetData object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'changes';
    yield serializers.serialize(
      object.changes,
      specifiedType: const FullType(BuiltList, [FullType(SyncChange)]),
    );
    yield r'nextCursor';
    yield object.nextCursor == null
        ? null
        : serializers.serialize(
            object.nextCursor,
            specifiedType: const FullType.nullable(
              SyncPullResetDataNextCursorEnum,
            ),
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
    SyncPullResetData object, {
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
    required SyncPullResetDataBuilder result,
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
                    specifiedType: const FullType.nullable(
                      SyncPullResetDataNextCursorEnum,
                    ),
                  )
                  as SyncPullResetDataNextCursorEnum?;
          if (valueDes == null) continue;
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
  SyncPullResetData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SyncPullResetDataBuilder();
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

class SyncPullResetDataNextCursorEnum extends EnumClass {
  static Serializer<SyncPullResetDataNextCursorEnum> get serializer =>
      _$syncPullResetDataNextCursorEnumSerializer;

  const SyncPullResetDataNextCursorEnum._(String name) : super(name);

  static BuiltSet<SyncPullResetDataNextCursorEnum> get values =>
      _$syncPullResetDataNextCursorEnumValues;
  static SyncPullResetDataNextCursorEnum valueOf(String name) =>
      _$syncPullResetDataNextCursorEnumValueOf(name);
}
