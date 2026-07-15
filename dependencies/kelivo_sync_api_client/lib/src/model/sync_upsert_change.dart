//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:kelivo_sync_api_client/src/model/sync_record.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'sync_upsert_change.g.dart';

/// SyncUpsertChange
///
/// Properties:
/// * [changeSeq]
/// * [operation]
/// * [record]
@BuiltValue()
abstract class SyncUpsertChange
    implements Built<SyncUpsertChange, SyncUpsertChangeBuilder> {
  @BuiltValueField(wireName: r'changeSeq')
  int get changeSeq;

  @BuiltValueField(wireName: r'operation')
  SyncUpsertChangeOperationEnum get operation;
  // enum operationEnum {  upsert,  };

  @BuiltValueField(wireName: r'record')
  SyncRecord get record;

  SyncUpsertChange._();

  factory SyncUpsertChange([void updates(SyncUpsertChangeBuilder b)]) =
      _$SyncUpsertChange;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SyncUpsertChangeBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<SyncUpsertChange> get serializer =>
      _$SyncUpsertChangeSerializer();
}

class _$SyncUpsertChangeSerializer
    implements PrimitiveSerializer<SyncUpsertChange> {
  @override
  final Iterable<Type> types = const [SyncUpsertChange, _$SyncUpsertChange];

  @override
  final String wireName = r'SyncUpsertChange';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    SyncUpsertChange object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'changeSeq';
    yield serializers.serialize(
      object.changeSeq,
      specifiedType: const FullType(int),
    );
    yield r'operation';
    yield serializers.serialize(
      object.operation,
      specifiedType: const FullType(SyncUpsertChangeOperationEnum),
    );
    yield r'record';
    yield serializers.serialize(
      object.record,
      specifiedType: const FullType(SyncRecord),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    SyncUpsertChange object, {
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
    required SyncUpsertChangeBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'changeSeq':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.changeSeq = valueDes;
          break;
        case r'operation':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      SyncUpsertChangeOperationEnum,
                    ),
                  )
                  as SyncUpsertChangeOperationEnum;
          result.operation = valueDes;
          break;
        case r'record':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(SyncRecord),
                  )
                  as SyncRecord;
          result.record.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  SyncUpsertChange deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SyncUpsertChangeBuilder();
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

class SyncUpsertChangeOperationEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'upsert')
  static const SyncUpsertChangeOperationEnum upsert =
      _$syncUpsertChangeOperationEnum_upsert;

  static Serializer<SyncUpsertChangeOperationEnum> get serializer =>
      _$syncUpsertChangeOperationEnumSerializer;

  const SyncUpsertChangeOperationEnum._(String name) : super(name);

  static BuiltSet<SyncUpsertChangeOperationEnum> get values =>
      _$syncUpsertChangeOperationEnumValues;
  static SyncUpsertChangeOperationEnum valueOf(String name) =>
      _$syncUpsertChangeOperationEnumValueOf(name);
}
