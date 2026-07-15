//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:kelivo_sync_api_client/src/model/sync_record.dart';
import 'package:kelivo_sync_api_client/src/model/sync_entity_type.dart';
import 'package:kelivo_sync_api_client/src/model/sync_upsert_change.dart';
import 'package:kelivo_sync_api_client/src/model/sync_delete_change.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:one_of/one_of.dart';

part 'sync_change.g.dart';

/// SyncChange
///
/// Properties:
/// * [changeSeq]
/// * [operation]
/// * [record]
/// * [entityType]
/// * [entityId]
/// * [revision]
/// * [deletedAt]
@BuiltValue()
abstract class SyncChange implements Built<SyncChange, SyncChangeBuilder> {
  /// One Of [SyncDeleteChange], [SyncUpsertChange]
  OneOf get oneOf;

  static const String discriminatorFieldName = r'operation';

  static const Map<String, Type> discriminatorMapping = {
    r'delete': SyncDeleteChange,
    r'upsert': SyncUpsertChange,
  };

  SyncChange._();

  factory SyncChange([void updates(SyncChangeBuilder b)]) = _$SyncChange;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SyncChangeBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<SyncChange> get serializer => _$SyncChangeSerializer();
}

extension SyncChangeDiscriminatorExt on SyncChange {
  String? get discriminatorValue {
    if (this is SyncDeleteChange) {
      return r'delete';
    }
    if (this is SyncUpsertChange) {
      return r'upsert';
    }
    return null;
  }
}

extension SyncChangeBuilderDiscriminatorExt on SyncChangeBuilder {
  String? get discriminatorValue {
    if (this is SyncDeleteChangeBuilder) {
      return r'delete';
    }
    if (this is SyncUpsertChangeBuilder) {
      return r'upsert';
    }
    return null;
  }
}

class _$SyncChangeSerializer implements PrimitiveSerializer<SyncChange> {
  @override
  final Iterable<Type> types = const [SyncChange, _$SyncChange];

  @override
  final String wireName = r'SyncChange';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    SyncChange object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {}

  @override
  Object serialize(
    Serializers serializers,
    SyncChange object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final oneOf = object.oneOf;
    return serializers.serialize(
      oneOf.value,
      specifiedType: FullType(oneOf.valueType),
    )!;
  }

  @override
  SyncChange deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SyncChangeBuilder();
    Object? oneOfDataSrc;
    final serializedList = (serialized as Iterable<Object?>).toList();
    final discIndex =
        serializedList.indexOf(SyncChange.discriminatorFieldName) + 1;
    final discValue =
        serializers.deserialize(
              serializedList[discIndex],
              specifiedType: FullType(String),
            )
            as String;
    oneOfDataSrc = serialized;
    final oneOfTypes = [SyncDeleteChange, SyncUpsertChange];
    Object oneOfResult;
    Type oneOfType;
    switch (discValue) {
      case r'delete':
        oneOfResult =
            serializers.deserialize(
                  oneOfDataSrc,
                  specifiedType: FullType(SyncDeleteChange),
                )
                as SyncDeleteChange;
        oneOfType = SyncDeleteChange;
        break;
      case r'upsert':
        oneOfResult =
            serializers.deserialize(
                  oneOfDataSrc,
                  specifiedType: FullType(SyncUpsertChange),
                )
                as SyncUpsertChange;
        oneOfType = SyncUpsertChange;
        break;
      default:
        throw UnsupportedError(
          "Couldn't deserialize oneOf for the discriminator value: ${discValue}",
        );
    }
    result.oneOf = OneOfDynamic(
      typeIndex: oneOfTypes.indexOf(oneOfType),
      types: oneOfTypes,
      value: oneOfResult,
    );
    return result.build();
  }
}

class SyncChangeOperationEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'delete')
  static const SyncChangeOperationEnum delete =
      _$syncChangeOperationEnum_delete;

  static Serializer<SyncChangeOperationEnum> get serializer =>
      _$syncChangeOperationEnumSerializer;

  const SyncChangeOperationEnum._(String name) : super(name);

  static BuiltSet<SyncChangeOperationEnum> get values =>
      _$syncChangeOperationEnumValues;
  static SyncChangeOperationEnum valueOf(String name) =>
      _$syncChangeOperationEnumValueOf(name);
}
