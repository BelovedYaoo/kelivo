//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'sync_conflict_mutation_result.g.dart';

/// SyncConflictMutationResult
///
/// Properties:
/// * [mutationId]
/// * [status]
/// * [currentRevision]
@BuiltValue()
abstract class SyncConflictMutationResult
    implements
        Built<SyncConflictMutationResult, SyncConflictMutationResultBuilder> {
  @BuiltValueField(wireName: r'mutationId')
  String get mutationId;

  @BuiltValueField(wireName: r'status')
  SyncConflictMutationResultStatusEnum get status;
  // enum statusEnum {  conflict,  };

  @BuiltValueField(wireName: r'currentRevision')
  int? get currentRevision;

  SyncConflictMutationResult._();

  factory SyncConflictMutationResult([
    void updates(SyncConflictMutationResultBuilder b),
  ]) = _$SyncConflictMutationResult;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SyncConflictMutationResultBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<SyncConflictMutationResult> get serializer =>
      _$SyncConflictMutationResultSerializer();
}

class _$SyncConflictMutationResultSerializer
    implements PrimitiveSerializer<SyncConflictMutationResult> {
  @override
  final Iterable<Type> types = const [
    SyncConflictMutationResult,
    _$SyncConflictMutationResult,
  ];

  @override
  final String wireName = r'SyncConflictMutationResult';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    SyncConflictMutationResult object, {
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
      specifiedType: const FullType(SyncConflictMutationResultStatusEnum),
    );
    yield r'currentRevision';
    yield object.currentRevision == null
        ? null
        : serializers.serialize(
            object.currentRevision,
            specifiedType: const FullType.nullable(int),
          );
  }

  @override
  Object serialize(
    Serializers serializers,
    SyncConflictMutationResult object, {
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
    required SyncConflictMutationResultBuilder result,
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
                      SyncConflictMutationResultStatusEnum,
                    ),
                  )
                  as SyncConflictMutationResultStatusEnum;
          result.status = valueDes;
          break;
        case r'currentRevision':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType.nullable(int),
                  )
                  as int?;
          if (valueDes == null) continue;
          result.currentRevision = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  SyncConflictMutationResult deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SyncConflictMutationResultBuilder();
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

class SyncConflictMutationResultStatusEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'conflict')
  static const SyncConflictMutationResultStatusEnum conflict =
      _$syncConflictMutationResultStatusEnum_conflict;

  static Serializer<SyncConflictMutationResultStatusEnum> get serializer =>
      _$syncConflictMutationResultStatusEnumSerializer;

  const SyncConflictMutationResultStatusEnum._(String name) : super(name);

  static BuiltSet<SyncConflictMutationResultStatusEnum> get values =>
      _$syncConflictMutationResultStatusEnumValues;
  static SyncConflictMutationResultStatusEnum valueOf(String name) =>
      _$syncConflictMutationResultStatusEnumValueOf(name);
}
