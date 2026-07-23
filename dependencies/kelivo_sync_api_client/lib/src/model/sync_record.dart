//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/sync_deleted_record.dart';
import 'package:kelivo_sync_api_client/src/model/sync_active_record.dart';
import 'package:built_value/json_object.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:one_of/any_of.dart';

part 'sync_record.g.dart';

/// SyncRecord
///
/// Properties:
/// * [recordId]
/// * [revision]
/// * [envelopeVersion]
/// * [keyEpoch]
/// * [ciphertext]
/// * [ciphertextBytes]
/// * [deletedAt]
/// * [updatedAt]
/// * [updatedByDeviceId]
/// * [lastChangeSeq]
@BuiltValue()
abstract class SyncRecord implements Built<SyncRecord, SyncRecordBuilder> {
  /// Any Of [SyncActiveRecord], [SyncDeletedRecord]
  AnyOf get anyOf;

  SyncRecord._();

  factory SyncRecord([void updates(SyncRecordBuilder b)]) = _$SyncRecord;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SyncRecordBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<SyncRecord> get serializer => _$SyncRecordSerializer();
}

class _$SyncRecordSerializer implements PrimitiveSerializer<SyncRecord> {
  @override
  final Iterable<Type> types = const [SyncRecord, _$SyncRecord];

  @override
  final String wireName = r'SyncRecord';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    SyncRecord object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {}

  @override
  Object serialize(
    Serializers serializers,
    SyncRecord object, {
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
  SyncRecord deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SyncRecordBuilder();
    Object? anyOfDataSrc;
    final targetType = const FullType(AnyOf, [
      FullType(SyncActiveRecord),
      FullType(SyncDeletedRecord),
    ]);
    anyOfDataSrc = serialized;
    result.anyOf =
        serializers.deserialize(anyOfDataSrc, specifiedType: targetType)
            as AnyOf;
    return result.build();
  }
}
