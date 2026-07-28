//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'sync_mutation.g.dart';

/// SyncMutation
///
/// Properties:
/// * [mutationId]
/// * [recordId]
/// * [expectedRevision]
/// * [operation]
/// * [envelopeVersion]
/// * [keyEpoch]
/// * [ciphertext] - 客户端生成的完整加密信封，使用无填充 Base64URL 编码，解码后最大 1 MiB
@BuiltValue()
abstract class SyncMutation
    implements Built<SyncMutation, SyncMutationBuilder> {
  @BuiltValueField(wireName: r'mutationId')
  String get mutationId;

  @BuiltValueField(wireName: r'recordId')
  String get recordId;

  @BuiltValueField(wireName: r'expectedRevision')
  int get expectedRevision;

  @BuiltValueField(wireName: r'operation')
  SyncMutationOperationEnum get operation;
  // enum operationEnum {  put,  };

  @BuiltValueField(wireName: r'envelopeVersion')
  int get envelopeVersion;

  @BuiltValueField(wireName: r'keyEpoch')
  int get keyEpoch;

  /// 客户端生成的完整加密信封，使用无填充 Base64URL 编码，解码后最大 1 MiB
  @BuiltValueField(wireName: r'ciphertext')
  String get ciphertext;

  SyncMutation._();

  factory SyncMutation([void updates(SyncMutationBuilder b)]) = _$SyncMutation;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SyncMutationBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<SyncMutation> get serializer => _$SyncMutationSerializer();
}

class _$SyncMutationSerializer implements PrimitiveSerializer<SyncMutation> {
  @override
  final Iterable<Type> types = const [SyncMutation, _$SyncMutation];

  @override
  final String wireName = r'SyncMutation';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    SyncMutation object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'mutationId';
    yield serializers.serialize(
      object.mutationId,
      specifiedType: const FullType(String),
    );
    yield r'recordId';
    yield serializers.serialize(
      object.recordId,
      specifiedType: const FullType(String),
    );
    yield r'expectedRevision';
    yield serializers.serialize(
      object.expectedRevision,
      specifiedType: const FullType(int),
    );
    yield r'operation';
    yield serializers.serialize(
      object.operation,
      specifiedType: const FullType(SyncMutationOperationEnum),
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
  }

  @override
  Object serialize(
    Serializers serializers,
    SyncMutation object, {
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
    required SyncMutationBuilder result,
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
        case r'recordId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.recordId = valueDes;
          break;
        case r'expectedRevision':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.expectedRevision = valueDes;
          break;
        case r'operation':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(SyncMutationOperationEnum),
                  )
                  as SyncMutationOperationEnum;
          result.operation = valueDes;
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
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  SyncMutation deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SyncMutationBuilder();
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

class SyncMutationOperationEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'put')
  static const SyncMutationOperationEnum put = _$syncMutationOperationEnum_put;

  static Serializer<SyncMutationOperationEnum> get serializer =>
      _$syncMutationOperationEnumSerializer;

  const SyncMutationOperationEnum._(String name) : super(name);

  static BuiltSet<SyncMutationOperationEnum> get values =>
      _$syncMutationOperationEnumValues;
  static SyncMutationOperationEnum valueOf(String name) =>
      _$syncMutationOperationEnumValueOf(name);
}
