//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/sync_conflict_mutation_result.dart';
import 'package:kelivo_sync_api_client/src/model/sync_retry_mutation_result.dart';
import 'package:built_collection/built_collection.dart';
import 'package:kelivo_sync_api_client/src/model/sync_rejected_mutation_result.dart';
import 'package:kelivo_sync_api_client/src/model/sync_applied_mutation_result.dart';
import 'package:built_value/json_object.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:one_of/one_of.dart';

part 'sync_mutation_result.g.dart';

/// SyncMutationResult
///
/// Properties:
/// * [mutationId]
/// * [status]
/// * [revision]
/// * [changeSeq]
/// * [currentRevision]
/// * [reason]
/// * [errorCode]
/// * [params]
/// * [retryable]
@BuiltValue()
abstract class SyncMutationResult
    implements Built<SyncMutationResult, SyncMutationResultBuilder> {
  /// One Of [SyncAppliedMutationResult], [SyncConflictMutationResult], [SyncRejectedMutationResult], [SyncRetryMutationResult]
  OneOf get oneOf;

  static const String discriminatorFieldName = r'status';

  static const Map<String, Type> discriminatorMapping = {
    r'applied': SyncAppliedMutationResult,
    r'conflict': SyncConflictMutationResult,
    r'rejected': SyncRejectedMutationResult,
    r'retry': SyncRetryMutationResult,
  };

  SyncMutationResult._();

  factory SyncMutationResult([void updates(SyncMutationResultBuilder b)]) =
      _$SyncMutationResult;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SyncMutationResultBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<SyncMutationResult> get serializer =>
      _$SyncMutationResultSerializer();
}

extension SyncMutationResultDiscriminatorExt on SyncMutationResult {
  String? get discriminatorValue {
    if (this is SyncAppliedMutationResult) {
      return r'applied';
    }
    if (this is SyncConflictMutationResult) {
      return r'conflict';
    }
    if (this is SyncRejectedMutationResult) {
      return r'rejected';
    }
    if (this is SyncRetryMutationResult) {
      return r'retry';
    }
    return null;
  }
}

extension SyncMutationResultBuilderDiscriminatorExt
    on SyncMutationResultBuilder {
  String? get discriminatorValue {
    if (this is SyncAppliedMutationResultBuilder) {
      return r'applied';
    }
    if (this is SyncConflictMutationResultBuilder) {
      return r'conflict';
    }
    if (this is SyncRejectedMutationResultBuilder) {
      return r'rejected';
    }
    if (this is SyncRetryMutationResultBuilder) {
      return r'retry';
    }
    return null;
  }
}

class _$SyncMutationResultSerializer
    implements PrimitiveSerializer<SyncMutationResult> {
  @override
  final Iterable<Type> types = const [SyncMutationResult, _$SyncMutationResult];

  @override
  final String wireName = r'SyncMutationResult';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    SyncMutationResult object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {}

  @override
  Object serialize(
    Serializers serializers,
    SyncMutationResult object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final oneOf = object.oneOf;
    return serializers.serialize(
      oneOf.value,
      specifiedType: FullType(oneOf.valueType),
    )!;
  }

  @override
  SyncMutationResult deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SyncMutationResultBuilder();
    Object? oneOfDataSrc;
    final serializedList = (serialized as Iterable<Object?>).toList();
    final discIndex =
        serializedList.indexOf(SyncMutationResult.discriminatorFieldName) + 1;
    final discValue =
        serializers.deserialize(
              serializedList[discIndex],
              specifiedType: FullType(String),
            )
            as String;
    oneOfDataSrc = serialized;
    final oneOfTypes = [
      SyncAppliedMutationResult,
      SyncConflictMutationResult,
      SyncRejectedMutationResult,
      SyncRetryMutationResult,
    ];
    Object oneOfResult;
    Type oneOfType;
    switch (discValue) {
      case r'applied':
        oneOfResult =
            serializers.deserialize(
                  oneOfDataSrc,
                  specifiedType: FullType(SyncAppliedMutationResult),
                )
                as SyncAppliedMutationResult;
        oneOfType = SyncAppliedMutationResult;
        break;
      case r'conflict':
        oneOfResult =
            serializers.deserialize(
                  oneOfDataSrc,
                  specifiedType: FullType(SyncConflictMutationResult),
                )
                as SyncConflictMutationResult;
        oneOfType = SyncConflictMutationResult;
        break;
      case r'rejected':
        oneOfResult =
            serializers.deserialize(
                  oneOfDataSrc,
                  specifiedType: FullType(SyncRejectedMutationResult),
                )
                as SyncRejectedMutationResult;
        oneOfType = SyncRejectedMutationResult;
        break;
      case r'retry':
        oneOfResult =
            serializers.deserialize(
                  oneOfDataSrc,
                  specifiedType: FullType(SyncRetryMutationResult),
                )
                as SyncRetryMutationResult;
        oneOfType = SyncRetryMutationResult;
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

class SyncMutationResultStatusEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'retry')
  static const SyncMutationResultStatusEnum retry =
      _$syncMutationResultStatusEnum_retry;

  static Serializer<SyncMutationResultStatusEnum> get serializer =>
      _$syncMutationResultStatusEnumSerializer;

  const SyncMutationResultStatusEnum._(String name) : super(name);

  static BuiltSet<SyncMutationResultStatusEnum> get values =>
      _$syncMutationResultStatusEnumValues;
  static SyncMutationResultStatusEnum valueOf(String name) =>
      _$syncMutationResultStatusEnumValueOf(name);
}

class SyncMutationResultReasonEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'entity-exists')
  static const SyncMutationResultReasonEnum entityExists =
      _$syncMutationResultReasonEnum_entityExists;
  @BuiltValueEnumConst(wireName: r'entity-missing')
  static const SyncMutationResultReasonEnum entityMissing =
      _$syncMutationResultReasonEnum_entityMissing;
  @BuiltValueEnumConst(wireName: r'entity-deleted')
  static const SyncMutationResultReasonEnum entityDeleted =
      _$syncMutationResultReasonEnum_entityDeleted;
  @BuiltValueEnumConst(wireName: r'entity-active')
  static const SyncMutationResultReasonEnum entityActive =
      _$syncMutationResultReasonEnum_entityActive;
  @BuiltValueEnumConst(wireName: r'revision-ahead')
  static const SyncMutationResultReasonEnum revisionAhead =
      _$syncMutationResultReasonEnum_revisionAhead;
  @BuiltValueEnumConst(wireName: r'revision-stale')
  static const SyncMutationResultReasonEnum revisionStale =
      _$syncMutationResultReasonEnum_revisionStale;

  static Serializer<SyncMutationResultReasonEnum> get serializer =>
      _$syncMutationResultReasonEnumSerializer;

  const SyncMutationResultReasonEnum._(String name) : super(name);

  static BuiltSet<SyncMutationResultReasonEnum> get values =>
      _$syncMutationResultReasonEnumValues;
  static SyncMutationResultReasonEnum valueOf(String name) =>
      _$syncMutationResultReasonEnumValueOf(name);
}
