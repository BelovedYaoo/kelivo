//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/sync_conflict_mutation_result.dart';
import 'package:kelivo_sync_api_client/src/model/sync_retry_mutation_result.dart';
import 'package:kelivo_sync_api_client/src/model/sync_field_conflict_mutation_result.dart';
import 'package:built_collection/built_collection.dart';
import 'package:kelivo_sync_api_client/src/model/sync_rejected_mutation_result.dart';
import 'package:kelivo_sync_api_client/src/model/sync_applied_mutation_result.dart';
import 'package:built_value/json_object.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:one_of/any_of.dart';

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
/// * [conflictId]
/// * [conflictingPaths]
/// * [errorCode]
/// * [params]
/// * [retryable]
@BuiltValue()
abstract class SyncMutationResult
    implements Built<SyncMutationResult, SyncMutationResultBuilder> {
  /// Any Of [SyncAppliedMutationResult], [SyncConflictMutationResult], [SyncFieldConflictMutationResult], [SyncRejectedMutationResult], [SyncRetryMutationResult]
  AnyOf get anyOf;

  SyncMutationResult._();

  factory SyncMutationResult([void updates(SyncMutationResultBuilder b)]) =
      _$SyncMutationResult;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SyncMutationResultBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<SyncMutationResult> get serializer =>
      _$SyncMutationResultSerializer();
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
    final anyOf = object.anyOf;
    return serializers.serialize(
      anyOf,
      specifiedType: FullType(
        AnyOf,
        anyOf.valueTypes.map((type) => FullType(type)).toList(),
      ),
    )!;
  }

  @override
  SyncMutationResult deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SyncMutationResultBuilder();
    Object? anyOfDataSrc;
    final targetType = const FullType(AnyOf, [
      FullType(SyncAppliedMutationResult),
      FullType(SyncConflictMutationResult),
      FullType(SyncFieldConflictMutationResult),
      FullType(SyncRejectedMutationResult),
      FullType(SyncRetryMutationResult),
    ]);
    anyOfDataSrc = serialized;
    result.anyOf =
        serializers.deserialize(anyOfDataSrc, specifiedType: targetType)
            as AnyOf;
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
  @BuiltValueEnumConst(wireName: r'field-conflict')
  static const SyncMutationResultReasonEnum fieldConflict =
      _$syncMutationResultReasonEnum_fieldConflict;

  static Serializer<SyncMutationResultReasonEnum> get serializer =>
      _$syncMutationResultReasonEnumSerializer;

  const SyncMutationResultReasonEnum._(String name) : super(name);

  static BuiltSet<SyncMutationResultReasonEnum> get values =>
      _$syncMutationResultReasonEnumValues;
  static SyncMutationResultReasonEnum valueOf(String name) =>
      _$syncMutationResultReasonEnumValueOf(name);
}
