//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'sync_field_conflict_mutation_result.g.dart';

/// SyncFieldConflictMutationResult
///
/// Properties:
/// * [mutationId]
/// * [status]
/// * [currentRevision]
/// * [reason]
/// * [conflictId]
/// * [conflictingPaths]
/// * [changeSeq]
@BuiltValue()
abstract class SyncFieldConflictMutationResult
    implements
        Built<
          SyncFieldConflictMutationResult,
          SyncFieldConflictMutationResultBuilder
        > {
  @BuiltValueField(wireName: r'mutationId')
  String get mutationId;

  @BuiltValueField(wireName: r'status')
  SyncFieldConflictMutationResultStatusEnum get status;
  // enum statusEnum {  conflict,  };

  @BuiltValueField(wireName: r'currentRevision')
  int get currentRevision;

  @BuiltValueField(wireName: r'reason')
  SyncFieldConflictMutationResultReasonEnum get reason;
  // enum reasonEnum {  field-conflict,  };

  @BuiltValueField(wireName: r'conflictId')
  String get conflictId;

  @BuiltValueField(wireName: r'conflictingPaths')
  BuiltList<String> get conflictingPaths;

  @BuiltValueField(wireName: r'changeSeq')
  int? get changeSeq;

  SyncFieldConflictMutationResult._();

  factory SyncFieldConflictMutationResult([
    void updates(SyncFieldConflictMutationResultBuilder b),
  ]) = _$SyncFieldConflictMutationResult;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SyncFieldConflictMutationResultBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<SyncFieldConflictMutationResult> get serializer =>
      _$SyncFieldConflictMutationResultSerializer();
}

class _$SyncFieldConflictMutationResultSerializer
    implements PrimitiveSerializer<SyncFieldConflictMutationResult> {
  @override
  final Iterable<Type> types = const [
    SyncFieldConflictMutationResult,
    _$SyncFieldConflictMutationResult,
  ];

  @override
  final String wireName = r'SyncFieldConflictMutationResult';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    SyncFieldConflictMutationResult object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'mutationId';
    yield serializers.serialize(
      object.mutationId,
      specifiedType: const FullType(String),
    );
    yield r'status';
    yield serializers.serialize(
      object.status,
      specifiedType: const FullType(SyncFieldConflictMutationResultStatusEnum),
    );
    yield r'currentRevision';
    yield serializers.serialize(
      object.currentRevision,
      specifiedType: const FullType(int),
    );
    yield r'reason';
    yield serializers.serialize(
      object.reason,
      specifiedType: const FullType(SyncFieldConflictMutationResultReasonEnum),
    );
    yield r'conflictId';
    yield serializers.serialize(
      object.conflictId,
      specifiedType: const FullType(String),
    );
    yield r'conflictingPaths';
    yield serializers.serialize(
      object.conflictingPaths,
      specifiedType: const FullType(BuiltList, [FullType(String)]),
    );
    if (object.changeSeq != null) {
      yield r'changeSeq';
      yield serializers.serialize(
        object.changeSeq,
        specifiedType: const FullType(int),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    SyncFieldConflictMutationResult object, {
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
    required SyncFieldConflictMutationResultBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'mutationId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.mutationId = valueDes;
          break;
        case r'status':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      SyncFieldConflictMutationResultStatusEnum,
                    ),
                  )
                  as SyncFieldConflictMutationResultStatusEnum;
          result.status = valueDes;
          break;
        case r'currentRevision':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.currentRevision = valueDes;
          break;
        case r'reason':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      SyncFieldConflictMutationResultReasonEnum,
                    ),
                  )
                  as SyncFieldConflictMutationResultReasonEnum;
          result.reason = valueDes;
          break;
        case r'conflictId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.conflictId = valueDes;
          break;
        case r'conflictingPaths':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(BuiltList, [
                      FullType(String),
                    ]),
                  )
                  as BuiltList<String>;
          result.conflictingPaths.replace(valueDes);
          break;
        case r'changeSeq':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.changeSeq = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  SyncFieldConflictMutationResult deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SyncFieldConflictMutationResultBuilder();
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

class SyncFieldConflictMutationResultStatusEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'conflict')
  static const SyncFieldConflictMutationResultStatusEnum conflict =
      _$syncFieldConflictMutationResultStatusEnum_conflict;

  static Serializer<SyncFieldConflictMutationResultStatusEnum> get serializer =>
      _$syncFieldConflictMutationResultStatusEnumSerializer;

  const SyncFieldConflictMutationResultStatusEnum._(String name) : super(name);

  static BuiltSet<SyncFieldConflictMutationResultStatusEnum> get values =>
      _$syncFieldConflictMutationResultStatusEnumValues;
  static SyncFieldConflictMutationResultStatusEnum valueOf(String name) =>
      _$syncFieldConflictMutationResultStatusEnumValueOf(name);
}

class SyncFieldConflictMutationResultReasonEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'field-conflict')
  static const SyncFieldConflictMutationResultReasonEnum fieldConflict =
      _$syncFieldConflictMutationResultReasonEnum_fieldConflict;

  static Serializer<SyncFieldConflictMutationResultReasonEnum> get serializer =>
      _$syncFieldConflictMutationResultReasonEnumSerializer;

  const SyncFieldConflictMutationResultReasonEnum._(String name) : super(name);

  static BuiltSet<SyncFieldConflictMutationResultReasonEnum> get values =>
      _$syncFieldConflictMutationResultReasonEnumValues;
  static SyncFieldConflictMutationResultReasonEnum valueOf(String name) =>
      _$syncFieldConflictMutationResultReasonEnumValueOf(name);
}
