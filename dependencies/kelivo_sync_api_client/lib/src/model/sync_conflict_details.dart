//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/sync_conflict_details_fields_inner.dart';
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'sync_conflict_details.g.dart';

/// SyncConflictDetails
///
/// Properties:
/// * [baseRevision]
/// * [fields]
@BuiltValue()
abstract class SyncConflictDetails
    implements Built<SyncConflictDetails, SyncConflictDetailsBuilder> {
  @BuiltValueField(wireName: r'baseRevision')
  int get baseRevision;

  @BuiltValueField(wireName: r'fields')
  BuiltList<SyncConflictDetailsFieldsInner> get fields;

  SyncConflictDetails._();

  factory SyncConflictDetails([void updates(SyncConflictDetailsBuilder b)]) =
      _$SyncConflictDetails;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SyncConflictDetailsBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<SyncConflictDetails> get serializer =>
      _$SyncConflictDetailsSerializer();
}

class _$SyncConflictDetailsSerializer
    implements PrimitiveSerializer<SyncConflictDetails> {
  @override
  final Iterable<Type> types = const [
    SyncConflictDetails,
    _$SyncConflictDetails,
  ];

  @override
  final String wireName = r'SyncConflictDetails';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    SyncConflictDetails object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'baseRevision';
    yield serializers.serialize(
      object.baseRevision,
      specifiedType: const FullType(int),
    );
    yield r'fields';
    yield serializers.serialize(
      object.fields,
      specifiedType: const FullType(BuiltList, [
        FullType(SyncConflictDetailsFieldsInner),
      ]),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    SyncConflictDetails object, {
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
    required SyncConflictDetailsBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'baseRevision':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.baseRevision = valueDes;
          break;
        case r'fields':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(BuiltList, [
                      FullType(SyncConflictDetailsFieldsInner),
                    ]),
                  )
                  as BuiltList<SyncConflictDetailsFieldsInner>;
          result.fields.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  SyncConflictDetails deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SyncConflictDetailsBuilder();
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
