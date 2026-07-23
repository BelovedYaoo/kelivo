//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/json_object.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'sync_deleted_record.g.dart';

/// SyncDeletedRecord
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
abstract class SyncDeletedRecord
    implements Built<SyncDeletedRecord, SyncDeletedRecordBuilder> {
  @BuiltValueField(wireName: r'recordId')
  String get recordId;

  @BuiltValueField(wireName: r'revision')
  int get revision;

  @BuiltValueField(wireName: r'envelopeVersion')
  JsonObject? get envelopeVersion;

  @BuiltValueField(wireName: r'keyEpoch')
  JsonObject? get keyEpoch;

  @BuiltValueField(wireName: r'ciphertext')
  JsonObject? get ciphertext;

  @BuiltValueField(wireName: r'ciphertextBytes')
  int get ciphertextBytes;

  @BuiltValueField(wireName: r'deletedAt')
  DateTime get deletedAt;

  @BuiltValueField(wireName: r'updatedAt')
  DateTime get updatedAt;

  @BuiltValueField(wireName: r'updatedByDeviceId')
  String? get updatedByDeviceId;

  @BuiltValueField(wireName: r'lastChangeSeq')
  int get lastChangeSeq;

  SyncDeletedRecord._();

  factory SyncDeletedRecord([void updates(SyncDeletedRecordBuilder b)]) =
      _$SyncDeletedRecord;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SyncDeletedRecordBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<SyncDeletedRecord> get serializer =>
      _$SyncDeletedRecordSerializer();
}

class _$SyncDeletedRecordSerializer
    implements PrimitiveSerializer<SyncDeletedRecord> {
  @override
  final Iterable<Type> types = const [SyncDeletedRecord, _$SyncDeletedRecord];

  @override
  final String wireName = r'SyncDeletedRecord';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    SyncDeletedRecord object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'recordId';
    yield serializers.serialize(
      object.recordId,
      specifiedType: const FullType(String),
    );
    yield r'revision';
    yield serializers.serialize(
      object.revision,
      specifiedType: const FullType(int),
    );
    yield r'envelopeVersion';
    yield object.envelopeVersion == null
        ? null
        : serializers.serialize(
            object.envelopeVersion,
            specifiedType: const FullType.nullable(JsonObject),
          );
    yield r'keyEpoch';
    yield object.keyEpoch == null
        ? null
        : serializers.serialize(
            object.keyEpoch,
            specifiedType: const FullType.nullable(JsonObject),
          );
    yield r'ciphertext';
    yield object.ciphertext == null
        ? null
        : serializers.serialize(
            object.ciphertext,
            specifiedType: const FullType.nullable(JsonObject),
          );
    yield r'ciphertextBytes';
    yield serializers.serialize(
      object.ciphertextBytes,
      specifiedType: const FullType(int),
    );
    yield r'deletedAt';
    yield serializers.serialize(
      object.deletedAt,
      specifiedType: const FullType(DateTime),
    );
    yield r'updatedAt';
    yield serializers.serialize(
      object.updatedAt,
      specifiedType: const FullType(DateTime),
    );
    yield r'updatedByDeviceId';
    yield object.updatedByDeviceId == null
        ? null
        : serializers.serialize(
            object.updatedByDeviceId,
            specifiedType: const FullType.nullable(String),
          );
    yield r'lastChangeSeq';
    yield serializers.serialize(
      object.lastChangeSeq,
      specifiedType: const FullType(int),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    SyncDeletedRecord object, {
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
    required SyncDeletedRecordBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'recordId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.recordId = valueDes;
          break;
        case r'revision':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.revision = valueDes;
          break;
        case r'envelopeVersion':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType.nullable(JsonObject),
                  )
                  as JsonObject?;
          if (valueDes == null) continue;
          result.envelopeVersion = valueDes;
          break;
        case r'keyEpoch':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType.nullable(JsonObject),
                  )
                  as JsonObject?;
          if (valueDes == null) continue;
          result.keyEpoch = valueDes;
          break;
        case r'ciphertext':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType.nullable(JsonObject),
                  )
                  as JsonObject?;
          if (valueDes == null) continue;
          result.ciphertext = valueDes;
          break;
        case r'ciphertextBytes':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.ciphertextBytes = valueDes;
          break;
        case r'deletedAt':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(DateTime),
                  )
                  as DateTime;
          result.deletedAt = valueDes;
          break;
        case r'updatedAt':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(DateTime),
                  )
                  as DateTime;
          result.updatedAt = valueDes;
          break;
        case r'updatedByDeviceId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType.nullable(String),
                  )
                  as String?;
          if (valueDes == null) continue;
          result.updatedByDeviceId = valueDes;
          break;
        case r'lastChangeSeq':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.lastChangeSeq = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  SyncDeletedRecord deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SyncDeletedRecordBuilder();
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
