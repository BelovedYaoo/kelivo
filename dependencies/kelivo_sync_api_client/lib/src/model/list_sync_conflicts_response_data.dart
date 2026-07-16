//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:kelivo_sync_api_client/src/model/sync_conflict.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'list_sync_conflicts_response_data.g.dart';

/// ListSyncConflictsResponseData
///
/// Properties:
/// * [conflicts]
@BuiltValue()
abstract class ListSyncConflictsResponseData
    implements
        Built<
          ListSyncConflictsResponseData,
          ListSyncConflictsResponseDataBuilder
        > {
  @BuiltValueField(wireName: r'conflicts')
  BuiltList<SyncConflict> get conflicts;

  ListSyncConflictsResponseData._();

  factory ListSyncConflictsResponseData([
    void updates(ListSyncConflictsResponseDataBuilder b),
  ]) = _$ListSyncConflictsResponseData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ListSyncConflictsResponseDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ListSyncConflictsResponseData> get serializer =>
      _$ListSyncConflictsResponseDataSerializer();
}

class _$ListSyncConflictsResponseDataSerializer
    implements PrimitiveSerializer<ListSyncConflictsResponseData> {
  @override
  final Iterable<Type> types = const [
    ListSyncConflictsResponseData,
    _$ListSyncConflictsResponseData,
  ];

  @override
  final String wireName = r'ListSyncConflictsResponseData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ListSyncConflictsResponseData object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'conflicts';
    yield serializers.serialize(
      object.conflicts,
      specifiedType: const FullType(BuiltList, [FullType(SyncConflict)]),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ListSyncConflictsResponseData object, {
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
    required ListSyncConflictsResponseDataBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'conflicts':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(BuiltList, [
                      FullType(SyncConflict),
                    ]),
                  )
                  as BuiltList<SyncConflict>;
          result.conflicts.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ListSyncConflictsResponseData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ListSyncConflictsResponseDataBuilder();
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
