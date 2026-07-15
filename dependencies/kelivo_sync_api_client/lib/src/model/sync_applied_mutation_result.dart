//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'sync_applied_mutation_result.g.dart';

/// SyncAppliedMutationResult
///
/// Properties:
/// * [mutationId]
/// * [status]
/// * [revision]
/// * [changeSeq]
@BuiltValue()
abstract class SyncAppliedMutationResult
    implements
        Built<SyncAppliedMutationResult, SyncAppliedMutationResultBuilder> {
  @BuiltValueField(wireName: r'mutationId')
  String get mutationId;

  @BuiltValueField(wireName: r'status')
  SyncAppliedMutationResultStatusEnum get status;
  // enum statusEnum {  applied,  };

  @BuiltValueField(wireName: r'revision')
  int get revision;

  @BuiltValueField(wireName: r'changeSeq')
  int get changeSeq;

  SyncAppliedMutationResult._();

  factory SyncAppliedMutationResult([
    void updates(SyncAppliedMutationResultBuilder b),
  ]) = _$SyncAppliedMutationResult;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SyncAppliedMutationResultBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<SyncAppliedMutationResult> get serializer =>
      _$SyncAppliedMutationResultSerializer();
}

class _$SyncAppliedMutationResultSerializer
    implements PrimitiveSerializer<SyncAppliedMutationResult> {
  @override
  final Iterable<Type> types = const [
    SyncAppliedMutationResult,
    _$SyncAppliedMutationResult,
  ];

  @override
  final String wireName = r'SyncAppliedMutationResult';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    SyncAppliedMutationResult object, {
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
      specifiedType: const FullType(SyncAppliedMutationResultStatusEnum),
    );
    yield r'revision';
    yield serializers.serialize(
      object.revision,
      specifiedType: const FullType(int),
    );
    yield r'changeSeq';
    yield serializers.serialize(
      object.changeSeq,
      specifiedType: const FullType(int),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    SyncAppliedMutationResult object, {
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
    required SyncAppliedMutationResultBuilder result,
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
                      SyncAppliedMutationResultStatusEnum,
                    ),
                  )
                  as SyncAppliedMutationResultStatusEnum;
          result.status = valueDes;
          break;
        case r'revision':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.revision = valueDes;
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
  SyncAppliedMutationResult deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SyncAppliedMutationResultBuilder();
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

class SyncAppliedMutationResultStatusEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'applied')
  static const SyncAppliedMutationResultStatusEnum applied =
      _$syncAppliedMutationResultStatusEnum_applied;

  static Serializer<SyncAppliedMutationResultStatusEnum> get serializer =>
      _$syncAppliedMutationResultStatusEnumSerializer;

  const SyncAppliedMutationResultStatusEnum._(String name) : super(name);

  static BuiltSet<SyncAppliedMutationResultStatusEnum> get values =>
      _$syncAppliedMutationResultStatusEnumValues;
  static SyncAppliedMutationResultStatusEnum valueOf(String name) =>
      _$syncAppliedMutationResultStatusEnumValueOf(name);
}
