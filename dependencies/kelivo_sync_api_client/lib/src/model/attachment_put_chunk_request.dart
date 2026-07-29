//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'attachment_put_chunk_request.g.dart';

/// AttachmentPutChunkRequest
///
/// Properties:
/// * [mutationId]
/// * [attachmentId]
/// * [uploadId]
/// * [chunkKeyEpoch]
/// * [chunkIndex]
/// * [ciphertext] - 客户端生成的附件分块密文，使用规范无填充 Base64URL 编码，解码后最大 4 MiB
@BuiltValue()
abstract class AttachmentPutChunkRequest
    implements
        Built<AttachmentPutChunkRequest, AttachmentPutChunkRequestBuilder> {
  @BuiltValueField(wireName: r'mutationId')
  String get mutationId;

  @BuiltValueField(wireName: r'attachmentId')
  String get attachmentId;

  @BuiltValueField(wireName: r'uploadId')
  String get uploadId;

  @BuiltValueField(wireName: r'chunkKeyEpoch')
  int get chunkKeyEpoch;

  @BuiltValueField(wireName: r'chunkIndex')
  int get chunkIndex;

  /// 客户端生成的附件分块密文，使用规范无填充 Base64URL 编码，解码后最大 4 MiB
  @BuiltValueField(wireName: r'ciphertext')
  String get ciphertext;

  AttachmentPutChunkRequest._();

  factory AttachmentPutChunkRequest([
    void updates(AttachmentPutChunkRequestBuilder b),
  ]) = _$AttachmentPutChunkRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(AttachmentPutChunkRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AttachmentPutChunkRequest> get serializer =>
      _$AttachmentPutChunkRequestSerializer();
}

class _$AttachmentPutChunkRequestSerializer
    implements PrimitiveSerializer<AttachmentPutChunkRequest> {
  @override
  final Iterable<Type> types = const [
    AttachmentPutChunkRequest,
    _$AttachmentPutChunkRequest,
  ];

  @override
  final String wireName = r'AttachmentPutChunkRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AttachmentPutChunkRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'mutationId';
    yield serializers.serialize(
      object.mutationId,
      specifiedType: const FullType(String),
    );
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
    yield r'chunkKeyEpoch';
    yield serializers.serialize(
      object.chunkKeyEpoch,
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
  }

  @override
  Object serialize(
    Serializers serializers,
    AttachmentPutChunkRequest object, {
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
    required AttachmentPutChunkRequestBuilder result,
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
        case r'chunkKeyEpoch':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.chunkKeyEpoch = valueDes;
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
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  AttachmentPutChunkRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = AttachmentPutChunkRequestBuilder();
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
