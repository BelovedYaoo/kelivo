//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/json_object.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'sync_rejected_mutation_result.g.dart';

/// SyncRejectedMutationResult
///
/// Properties:
/// * [mutationId]
/// * [status]
/// * [errorCode]
/// * [params]
@BuiltValue()
abstract class SyncRejectedMutationResult
    implements
        Built<SyncRejectedMutationResult, SyncRejectedMutationResultBuilder> {
  @BuiltValueField(wireName: r'mutationId')
  String get mutationId;

  @BuiltValueField(wireName: r'status')
  SyncRejectedMutationResultStatusEnum get status;
  // enum statusEnum {  rejected,  };

  @BuiltValueField(wireName: r'errorCode')
  String get errorCode;

  @BuiltValueField(wireName: r'params')
  BuiltMap<String, JsonObject?>? get params;

  SyncRejectedMutationResult._();

  factory SyncRejectedMutationResult([
    void updates(SyncRejectedMutationResultBuilder b),
  ]) = _$SyncRejectedMutationResult;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SyncRejectedMutationResultBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<SyncRejectedMutationResult> get serializer =>
      _$SyncRejectedMutationResultSerializer();
}

class _$SyncRejectedMutationResultSerializer
    implements PrimitiveSerializer<SyncRejectedMutationResult> {
  @override
  final Iterable<Type> types = const [
    SyncRejectedMutationResult,
    _$SyncRejectedMutationResult,
  ];

  @override
  final String wireName = r'SyncRejectedMutationResult';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    SyncRejectedMutationResult object, {
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
      specifiedType: const FullType(SyncRejectedMutationResultStatusEnum),
    );
    yield r'errorCode';
    yield serializers.serialize(
      object.errorCode,
      specifiedType: const FullType(String),
    );
    if (object.params != null) {
      yield r'params';
      yield serializers.serialize(
        object.params,
        specifiedType: const FullType(BuiltMap, [
          FullType(String),
          FullType.nullable(JsonObject),
        ]),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    SyncRejectedMutationResult object, {
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
    required SyncRejectedMutationResultBuilder result,
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
                      SyncRejectedMutationResultStatusEnum,
                    ),
                  )
                  as SyncRejectedMutationResultStatusEnum;
          result.status = valueDes;
          break;
        case r'errorCode':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.errorCode = valueDes;
          break;
        case r'params':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(BuiltMap, [
                      FullType(String),
                      FullType.nullable(JsonObject),
                    ]),
                  )
                  as BuiltMap<String, JsonObject?>;
          result.params.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  SyncRejectedMutationResult deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SyncRejectedMutationResultBuilder();
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

class SyncRejectedMutationResultStatusEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'rejected')
  static const SyncRejectedMutationResultStatusEnum rejected =
      _$syncRejectedMutationResultStatusEnum_rejected;

  static Serializer<SyncRejectedMutationResultStatusEnum> get serializer =>
      _$syncRejectedMutationResultStatusEnumSerializer;

  const SyncRejectedMutationResultStatusEnum._(String name) : super(name);

  static BuiltSet<SyncRejectedMutationResultStatusEnum> get values =>
      _$syncRejectedMutationResultStatusEnumValues;
  static SyncRejectedMutationResultStatusEnum valueOf(String name) =>
      _$syncRejectedMutationResultStatusEnumValueOf(name);
}
