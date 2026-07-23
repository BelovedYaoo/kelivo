//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/json_object.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'sync_put_change.g.dart';

/// SyncPutChange
///
/// Properties:
/// * [changeSeq]
/// * [operation]
/// * [recordId]
/// * [revision]
/// * [envelopeVersion]
/// * [keyEpoch]
/// * [ciphertext] - 客户端生成的完整加密信封，使用无填充 Base64URL 编码，解码后最大 1 MiB
/// * [ciphertextBytes]
/// * [deletedAt]
/// * [updatedAt]
/// * [updatedByDeviceId]
@BuiltValue()
abstract class SyncPutChange
    implements Built<SyncPutChange, SyncPutChangeBuilder> {
  @BuiltValueField(wireName: r'changeSeq')
  int get changeSeq;

  @BuiltValueField(wireName: r'operation')
  SyncPutChangeOperationEnum get operation;
  // enum operationEnum {  put,  };

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

  SyncPutChange._();

  factory SyncPutChange([void updates(SyncPutChangeBuilder b)]) =
      _$SyncPutChange;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SyncPutChangeBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<SyncPutChange> get serializer =>
      _$SyncPutChangeSerializer();
}

class _$SyncPutChangeSerializer implements PrimitiveSerializer<SyncPutChange> {
  @override
  final Iterable<Type> types = const [SyncPutChange, _$SyncPutChange];

  @override
  final String wireName = r'SyncPutChange';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    SyncPutChange object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'changeSeq';
    yield serializers.serialize(
      object.changeSeq,
      specifiedType: const FullType(int),
    );
    yield r'operation';
    yield serializers.serialize(
      object.operation,
      specifiedType: const FullType(SyncPutChangeOperationEnum),
    );
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
  }

  @override
  Object serialize(
    Serializers serializers,
    SyncPutChange object, {
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
    required SyncPutChangeBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'changeSeq':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.changeSeq = valueDes;
          break;
        case r'operation':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(SyncPutChangeOperationEnum),
                  )
                  as SyncPutChangeOperationEnum;
          result.operation = valueDes;
          break;
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
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  SyncPutChange deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SyncPutChangeBuilder();
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

class SyncPutChangeOperationEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'put')
  static const SyncPutChangeOperationEnum put =
      _$syncPutChangeOperationEnum_put;

  static Serializer<SyncPutChangeOperationEnum> get serializer =>
      _$syncPutChangeOperationEnumSerializer;

  const SyncPutChangeOperationEnum._(String name) : super(name);

  static BuiltSet<SyncPutChangeOperationEnum> get values =>
      _$syncPutChangeOperationEnumValues;
  static SyncPutChangeOperationEnum valueOf(String name) =>
      _$syncPutChangeOperationEnumValueOf(name);
}
