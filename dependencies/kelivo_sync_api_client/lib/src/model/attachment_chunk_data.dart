//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'attachment_chunk_data.g.dart';

/// AttachmentChunkData
///
/// Properties:
/// * [attachmentId]
/// * [uploadId]
/// * [keyEpoch]
/// * [chunkIndex]
/// * [ciphertext] - 客户端生成的附件分块密文，使用规范无填充 Base64URL 编码，解码后最大 4 MiB
/// * [ciphertextBytes]
@BuiltValue()
abstract class AttachmentChunkData
    implements Built<AttachmentChunkData, AttachmentChunkDataBuilder> {
  @BuiltValueField(wireName: r'attachmentId')
  String get attachmentId;

  @BuiltValueField(wireName: r'uploadId')
  String get uploadId;

  @BuiltValueField(wireName: r'keyEpoch')
  int get keyEpoch;

  @BuiltValueField(wireName: r'chunkIndex')
  int get chunkIndex;

  /// 客户端生成的附件分块密文，使用规范无填充 Base64URL 编码，解码后最大 4 MiB
  @BuiltValueField(wireName: r'ciphertext')
  String get ciphertext;

  @BuiltValueField(wireName: r'ciphertextBytes')
  int get ciphertextBytes;

  AttachmentChunkData._();

  factory AttachmentChunkData([void updates(AttachmentChunkDataBuilder b)]) =
      _$AttachmentChunkData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(AttachmentChunkDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AttachmentChunkData> get serializer =>
      _$AttachmentChunkDataSerializer();
}

class _$AttachmentChunkDataSerializer
    implements PrimitiveSerializer<AttachmentChunkData> {
  @override
  final Iterable<Type> types = const [
    AttachmentChunkData,
    _$AttachmentChunkData,
  ];

  @override
  final String wireName = r'AttachmentChunkData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AttachmentChunkData object, {
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
    yield r'keyEpoch';
    yield serializers.serialize(
      object.keyEpoch,
      specifiedType: const FullType(int),
    );
    yield r'chunkIndex';
    yield serializers.serialize(
      object.chunkIndex,
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
  }

  @override
  Object serialize(
    Serializers serializers,
    AttachmentChunkData object, {
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
    required AttachmentChunkDataBuilder result,
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
        case r'keyEpoch':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.keyEpoch = valueDes;
          break;
        case r'chunkIndex':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.chunkIndex = valueDes;
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
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  AttachmentChunkData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = AttachmentChunkDataBuilder();
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
