//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'sync_retry_mutation_result.g.dart';

/// SyncRetryMutationResult
///
/// Properties:
/// * [mutationId]
/// * [status]
/// * [retryable]
@BuiltValue()
abstract class SyncRetryMutationResult
    implements Built<SyncRetryMutationResult, SyncRetryMutationResultBuilder> {
  @BuiltValueField(wireName: r'mutationId')
  String get mutationId;

  @BuiltValueField(wireName: r'status')
  SyncRetryMutationResultStatusEnum get status;
  // enum statusEnum {  retry,  };

  @BuiltValueField(wireName: r'retryable')
  bool get retryable;

  SyncRetryMutationResult._();

  factory SyncRetryMutationResult([
    void updates(SyncRetryMutationResultBuilder b),
  ]) = _$SyncRetryMutationResult;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SyncRetryMutationResultBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<SyncRetryMutationResult> get serializer =>
      _$SyncRetryMutationResultSerializer();
}

class _$SyncRetryMutationResultSerializer
    implements PrimitiveSerializer<SyncRetryMutationResult> {
  @override
  final Iterable<Type> types = const [
    SyncRetryMutationResult,
    _$SyncRetryMutationResult,
  ];

  @override
  final String wireName = r'SyncRetryMutationResult';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    SyncRetryMutationResult object, {
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
      specifiedType: const FullType(SyncRetryMutationResultStatusEnum),
    );
    yield r'retryable';
    yield serializers.serialize(
      object.retryable,
      specifiedType: const FullType(bool),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    SyncRetryMutationResult object, {
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
    required SyncRetryMutationResultBuilder result,
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
                      SyncRetryMutationResultStatusEnum,
                    ),
                  )
                  as SyncRetryMutationResultStatusEnum;
          result.status = valueDes;
          break;
        case r'retryable':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(bool),
                  )
                  as bool;
          result.retryable = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  SyncRetryMutationResult deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SyncRetryMutationResultBuilder();
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

class SyncRetryMutationResultStatusEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'retry')
  static const SyncRetryMutationResultStatusEnum retry =
      _$syncRetryMutationResultStatusEnum_retry;

  static Serializer<SyncRetryMutationResultStatusEnum> get serializer =>
      _$syncRetryMutationResultStatusEnumSerializer;

  const SyncRetryMutationResultStatusEnum._(String name) : super(name);

  static BuiltSet<SyncRetryMutationResultStatusEnum> get values =>
      _$syncRetryMutationResultStatusEnumValues;
  static SyncRetryMutationResultStatusEnum valueOf(String name) =>
      _$syncRetryMutationResultStatusEnumValueOf(name);
}
