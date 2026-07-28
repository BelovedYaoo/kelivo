//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/attachment_manifest_chunk.dart';
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'attachment_commit_upload_request.g.dart';

/// AttachmentCommitUploadRequest
///
/// Properties:
/// * [mutationId]
/// * [attachmentId]
/// * [uploadId]
/// * [keyEpoch]
/// * [manifestCiphertext] - 客户端认证的附件清单密文，使用规范无填充 Base64URL 编码，解码后最大 1 MiB
/// * [chunks]
@BuiltValue()
abstract class AttachmentCommitUploadRequest
    implements
        Built<
          AttachmentCommitUploadRequest,
          AttachmentCommitUploadRequestBuilder
        > {
  @BuiltValueField(wireName: r'mutationId')
  String get mutationId;

  @BuiltValueField(wireName: r'attachmentId')
  String get attachmentId;

  @BuiltValueField(wireName: r'uploadId')
  String get uploadId;

  @BuiltValueField(wireName: r'keyEpoch')
  int get keyEpoch;

  /// 客户端认证的附件清单密文，使用规范无填充 Base64URL 编码，解码后最大 1 MiB
  @BuiltValueField(wireName: r'manifestCiphertext')
  String get manifestCiphertext;

  @BuiltValueField(wireName: r'chunks')
  BuiltList<AttachmentManifestChunk> get chunks;

  AttachmentCommitUploadRequest._();

  factory AttachmentCommitUploadRequest([
    void updates(AttachmentCommitUploadRequestBuilder b),
  ]) = _$AttachmentCommitUploadRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(AttachmentCommitUploadRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AttachmentCommitUploadRequest> get serializer =>
      _$AttachmentCommitUploadRequestSerializer();
}

class _$AttachmentCommitUploadRequestSerializer
    implements PrimitiveSerializer<AttachmentCommitUploadRequest> {
  @override
  final Iterable<Type> types = const [
    AttachmentCommitUploadRequest,
    _$AttachmentCommitUploadRequest,
  ];

  @override
  final String wireName = r'AttachmentCommitUploadRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AttachmentCommitUploadRequest object, {
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
    yield r'keyEpoch';
    yield serializers.serialize(
      object.keyEpoch,
      specifiedType: const FullType(int),
    );
    yield r'manifestCiphertext';
    yield serializers.serialize(
      object.manifestCiphertext,
      specifiedType: const FullType(String),
    );
    yield r'chunks';
    yield serializers.serialize(
      object.chunks,
      specifiedType: const FullType(BuiltList, [
        FullType(AttachmentManifestChunk),
      ]),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    AttachmentCommitUploadRequest object, {
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
    required AttachmentCommitUploadRequestBuilder result,
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
        case r'keyEpoch':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.keyEpoch = valueDes;
          break;
        case r'manifestCiphertext':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.manifestCiphertext = valueDes;
          break;
        case r'chunks':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(BuiltList, [
                      FullType(AttachmentManifestChunk),
                    ]),
                  )
                  as BuiltList<AttachmentManifestChunk>;
          result.chunks.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  AttachmentCommitUploadRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = AttachmentCommitUploadRequestBuilder();
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
