//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/attachment_committed_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'commit_encrypted_attachment_upload_response.g.dart';

/// CommitEncryptedAttachmentUploadResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class CommitEncryptedAttachmentUploadResponse
    implements
        Built<
          CommitEncryptedAttachmentUploadResponse,
          CommitEncryptedAttachmentUploadResponseBuilder
        > {
  @BuiltValueField(wireName: r'data')
  AttachmentCommittedData get data;

  CommitEncryptedAttachmentUploadResponse._();

  factory CommitEncryptedAttachmentUploadResponse([
    void updates(CommitEncryptedAttachmentUploadResponseBuilder b),
  ]) = _$CommitEncryptedAttachmentUploadResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(CommitEncryptedAttachmentUploadResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<CommitEncryptedAttachmentUploadResponse> get serializer =>
      _$CommitEncryptedAttachmentUploadResponseSerializer();
}

class _$CommitEncryptedAttachmentUploadResponseSerializer
    implements PrimitiveSerializer<CommitEncryptedAttachmentUploadResponse> {
  @override
  final Iterable<Type> types = const [
    CommitEncryptedAttachmentUploadResponse,
    _$CommitEncryptedAttachmentUploadResponse,
  ];

  @override
  final String wireName = r'CommitEncryptedAttachmentUploadResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    CommitEncryptedAttachmentUploadResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(AttachmentCommittedData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    CommitEncryptedAttachmentUploadResponse object, {
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
    required CommitEncryptedAttachmentUploadResponseBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'data':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(AttachmentCommittedData),
                  )
                  as AttachmentCommittedData;
          result.data.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  CommitEncryptedAttachmentUploadResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = CommitEncryptedAttachmentUploadResponseBuilder();
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
