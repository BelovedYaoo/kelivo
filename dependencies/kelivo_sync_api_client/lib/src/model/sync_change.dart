//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'sync_change.g.dart';

/// SyncChange
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
/// * [updatedAt]
/// * [updatedByDeviceId]
@BuiltValue()
abstract class SyncChange implements Built<SyncChange, SyncChangeBuilder> {
  @BuiltValueField(wireName: r'changeSeq')
  int get changeSeq;

  @BuiltValueField(wireName: r'operation')
  SyncChangeOperationEnum get operation;
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

  @BuiltValueField(wireName: r'updatedAt')
  DateTime get updatedAt;

  @BuiltValueField(wireName: r'updatedByDeviceId')
  String? get updatedByDeviceId;

  SyncChange._();

  factory SyncChange([void updates(SyncChangeBuilder b)]) = _$SyncChange;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SyncChangeBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<SyncChange> get serializer => _$SyncChangeSerializer();
}

class _$SyncChangeSerializer implements PrimitiveSerializer<SyncChange> {
  @override
  final Iterable<Type> types = const [SyncChange, _$SyncChange];

  @override
  final String wireName = r'SyncChange';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    SyncChange object, {
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
      specifiedType: const FullType(SyncChangeOperationEnum),
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
    SyncChange object, {
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
    required SyncChangeBuilder result,
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
                    specifiedType: const FullType(SyncChangeOperationEnum),
                  )
                  as SyncChangeOperationEnum;
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
  SyncChange deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SyncChangeBuilder();
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

class SyncChangeOperationEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'put')
  static const SyncChangeOperationEnum put = _$syncChangeOperationEnum_put;

  static Serializer<SyncChangeOperationEnum> get serializer =>
      _$syncChangeOperationEnumSerializer;

  const SyncChangeOperationEnum._(String name) : super(name);

  static BuiltSet<SyncChangeOperationEnum> get values =>
      _$syncChangeOperationEnumValues;
  static SyncChangeOperationEnum valueOf(String name) =>
      _$syncChangeOperationEnumValueOf(name);
}
