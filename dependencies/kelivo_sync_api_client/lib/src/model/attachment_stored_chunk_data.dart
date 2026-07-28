//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'attachment_stored_chunk_data.g.dart';

/// AttachmentStoredChunkData
///
/// Properties:
/// * [attachmentId]
/// * [uploadId]
/// * [chunkIndex]
/// * [ciphertextBytes]
/// * [status]
@BuiltValue()
abstract class AttachmentStoredChunkData
    implements
        Built<AttachmentStoredChunkData, AttachmentStoredChunkDataBuilder> {
  @BuiltValueField(wireName: r'attachmentId')
  String get attachmentId;

  @BuiltValueField(wireName: r'uploadId')
  String get uploadId;

  @BuiltValueField(wireName: r'chunkIndex')
  int get chunkIndex;

  @BuiltValueField(wireName: r'ciphertextBytes')
  int get ciphertextBytes;

  @BuiltValueField(wireName: r'status')
  AttachmentStoredChunkDataStatusEnum get status;
  // enum statusEnum {  stored,  };

  AttachmentStoredChunkData._();

  factory AttachmentStoredChunkData([
    void updates(AttachmentStoredChunkDataBuilder b),
  ]) = _$AttachmentStoredChunkData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(AttachmentStoredChunkDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AttachmentStoredChunkData> get serializer =>
      _$AttachmentStoredChunkDataSerializer();
}

class _$AttachmentStoredChunkDataSerializer
    implements PrimitiveSerializer<AttachmentStoredChunkData> {
  @override
  final Iterable<Type> types = const [
    AttachmentStoredChunkData,
    _$AttachmentStoredChunkData,
  ];

  @override
  final String wireName = r'AttachmentStoredChunkData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AttachmentStoredChunkData object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'attachmentId';
    yield serializers.serialize(
      object.attachmentId,
      specifiedType: const FullType(String),
    );
    yield r'uploadId';
    yield serializers.serialize(
      object.uploadId,
      specifiedType: const FullType(String),
    );
    yield r'chunkIndex';
    yield serializers.serialize(
      object.chunkIndex,
      specifiedType: const FullType(int),
    );
    yield r'ciphertextBytes';
    yield serializers.serialize(
      object.ciphertextBytes,
      specifiedType: const FullType(int),
    );
    yield r'status';
    yield serializers.serialize(
      object.status,
      specifiedType: const FullType(AttachmentStoredChunkDataStatusEnum),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    AttachmentStoredChunkData object, {
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
    required AttachmentStoredChunkDataBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'attachmentId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.attachmentId = valueDes;
          break;
        case r'uploadId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.uploadId = valueDes;
          break;
        case r'chunkIndex':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.chunkIndex = valueDes;
          break;
        case r'ciphertextBytes':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.ciphertextBytes = valueDes;
          break;
        case r'status':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      AttachmentStoredChunkDataStatusEnum,
                    ),
                  )
                  as AttachmentStoredChunkDataStatusEnum;
          result.status = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  AttachmentStoredChunkData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = AttachmentStoredChunkDataBuilder();
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

class AttachmentStoredChunkDataStatusEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'stored')
  static const AttachmentStoredChunkDataStatusEnum stored =
      _$attachmentStoredChunkDataStatusEnum_stored;

  static Serializer<AttachmentStoredChunkDataStatusEnum> get serializer =>
      _$attachmentStoredChunkDataStatusEnumSerializer;

  const AttachmentStoredChunkDataStatusEnum._(String name) : super(name);

  static BuiltSet<AttachmentStoredChunkDataStatusEnum> get values =>
      _$attachmentStoredChunkDataStatusEnumValues;
  static AttachmentStoredChunkDataStatusEnum valueOf(String name) =>
      _$attachmentStoredChunkDataStatusEnumValueOf(name);
}
