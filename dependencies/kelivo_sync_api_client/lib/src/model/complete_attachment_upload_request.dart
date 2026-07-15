//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'complete_attachment_upload_request.g.dart';

/// CompleteAttachmentUploadRequest
///
/// Properties:
/// * [attachmentId]
/// * [blobId]
/// * [entityType]
/// * [entityId]
/// * [fileName]
/// * [mimeType]
/// * [etag]
@BuiltValue()
abstract class CompleteAttachmentUploadRequest
    implements
        Built<
          CompleteAttachmentUploadRequest,
          CompleteAttachmentUploadRequestBuilder
        > {
  @BuiltValueField(wireName: r'attachmentId')
  String get attachmentId;

  @BuiltValueField(wireName: r'blobId')
  String get blobId;

  @BuiltValueField(wireName: r'entityType')
  String get entityType;

  @BuiltValueField(wireName: r'entityId')
  String get entityId;

  @BuiltValueField(wireName: r'fileName')
  String get fileName;

  @BuiltValueField(wireName: r'mimeType')
  String get mimeType;

  @BuiltValueField(wireName: r'etag')
  String get etag;

  CompleteAttachmentUploadRequest._();

  factory CompleteAttachmentUploadRequest([
    void updates(CompleteAttachmentUploadRequestBuilder b),
  ]) = _$CompleteAttachmentUploadRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(CompleteAttachmentUploadRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<CompleteAttachmentUploadRequest> get serializer =>
      _$CompleteAttachmentUploadRequestSerializer();
}

class _$CompleteAttachmentUploadRequestSerializer
    implements PrimitiveSerializer<CompleteAttachmentUploadRequest> {
  @override
  final Iterable<Type> types = const [
    CompleteAttachmentUploadRequest,
    _$CompleteAttachmentUploadRequest,
  ];

  @override
  final String wireName = r'CompleteAttachmentUploadRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    CompleteAttachmentUploadRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'attachmentId';
    yield serializers.serialize(
      object.attachmentId,
      specifiedType: const FullType(String),
    );
    yield r'blobId';
    yield serializers.serialize(
      object.blobId,
      specifiedType: const FullType(String),
    );
    yield r'entityType';
    yield serializers.serialize(
      object.entityType,
      specifiedType: const FullType(String),
    );
    yield r'entityId';
    yield serializers.serialize(
      object.entityId,
      specifiedType: const FullType(String),
    );
    yield r'fileName';
    yield serializers.serialize(
      object.fileName,
      specifiedType: const FullType(String),
    );
    yield r'mimeType';
    yield serializers.serialize(
      object.mimeType,
      specifiedType: const FullType(String),
    );
    yield r'etag';
    yield serializers.serialize(
      object.etag,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    CompleteAttachmentUploadRequest object, {
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
    required CompleteAttachmentUploadRequestBuilder result,
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
        case r'blobId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.blobId = valueDes;
          break;
        case r'entityType':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.entityType = valueDes;
          break;
        case r'entityId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.entityId = valueDes;
          break;
        case r'fileName':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.fileName = valueDes;
          break;
        case r'mimeType':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.mimeType = valueDes;
          break;
        case r'etag':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.etag = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  CompleteAttachmentUploadRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = CompleteAttachmentUploadRequestBuilder();
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
