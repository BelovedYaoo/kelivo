//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/json_object.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'sync_active_record.g.dart';

/// SyncActiveRecord
///
/// Properties:
/// * [recordId]
/// * [revision]
/// * [envelopeVersion]
/// * [keyEpoch]
/// * [ciphertext] - 客户端生成的完整加密信封，使用无填充 Base64URL 编码，解码后最大 1 MiB
/// * [ciphertextBytes]
/// * [deletedAt]
/// * [updatedAt]
/// * [updatedByDeviceId]
/// * [lastChangeSeq]
@BuiltValue()
abstract class SyncActiveRecord
    implements Built<SyncActiveRecord, SyncActiveRecordBuilder> {
  @BuiltValueField(wireName: r'recordId')
  String get recordId;

  @BuiltValueField(wireName: r'revision')
  int get revision;

  @BuiltValueField(wireName: r'envelopeVersion')
  int get envelopeVersion;

  @BuiltValueField(wireName: r'keyEpoch')
  int get keyEpoch;

  /// 客户端生成的完整加密信封，使用无填充 Base64URL 编码，解码后最大 1 MiB
  @BuiltValueField(wireName: r'ciphertext')
  String get ciphertext;

  @BuiltValueField(wireName: r'ciphertextBytes')
  int get ciphertextBytes;

  @BuiltValueField(wireName: r'deletedAt')
  JsonObject? get deletedAt;

  @BuiltValueField(wireName: r'updatedAt')
  DateTime get updatedAt;

  @BuiltValueField(wireName: r'updatedByDeviceId')
  String? get updatedByDeviceId;

  @BuiltValueField(wireName: r'lastChangeSeq')
  int get lastChangeSeq;

  SyncActiveRecord._();

  factory SyncActiveRecord([void updates(SyncActiveRecordBuilder b)]) =
      _$SyncActiveRecord;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SyncActiveRecordBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<SyncActiveRecord> get serializer =>
      _$SyncActiveRecordSerializer();
}

class _$SyncActiveRecordSerializer
    implements PrimitiveSerializer<SyncActiveRecord> {
  @override
  final Iterable<Type> types = const [SyncActiveRecord, _$SyncActiveRecord];

  @override
  final String wireName = r'SyncActiveRecord';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    SyncActiveRecord object, {
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
    yield serializers.serialize(
      object.envelopeVersion,
      specifiedType: const FullType(int),
    );
    yield r'keyEpoch';
    yield serializers.serialize(
      object.keyEpoch,
      specifiedType: const FullType(int),
    );
    yield r'ciphertext';
    yield serializers.serialize(
      object.ciphertext,
      specifiedType: const FullType(String),
    );
    yield r'ciphertextBytes';
    yield serializers.serialize(
      object.ciphertextBytes,
      specifiedType: const FullType(int),
    );
    yield r'deletedAt';
    yield object.deletedAt == null
        ? null
        : serializers.serialize(
            object.deletedAt,
            specifiedType: const FullType.nullable(JsonObject),
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
    SyncActiveRecord object, {
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
    required SyncActiveRecordBuilder result,
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
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.envelopeVersion = valueDes;
          break;
        case r'keyEpoch':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.keyEpoch = valueDes;
          break;
        case r'ciphertext':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
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
                    specifiedType: const FullType.nullable(JsonObject),
                  )
                  as JsonObject?;
          if (valueDes == null) continue;
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
  SyncActiveRecord deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SyncActiveRecordBuilder();
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
