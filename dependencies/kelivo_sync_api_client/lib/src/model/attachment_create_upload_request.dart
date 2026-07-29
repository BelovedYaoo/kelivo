//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'attachment_create_upload_request.g.dart';

/// AttachmentCreateUploadRequest
///
/// Properties:
/// * [mutationId]
/// * [attachmentId]
/// * [chunkKeyEpoch]
/// * [manifestKeyEpoch]
/// * [manifestRevision]
/// * [chunkCount]
/// * [totalCiphertextBytes]
@BuiltValue()
abstract class AttachmentCreateUploadRequest
    implements
        Built<
          AttachmentCreateUploadRequest,
          AttachmentCreateUploadRequestBuilder
        > {
  @BuiltValueField(wireName: r'mutationId')
  String get mutationId;

  @BuiltValueField(wireName: r'attachmentId')
  String get attachmentId;

  @BuiltValueField(wireName: r'chunkKeyEpoch')
  int get chunkKeyEpoch;

  @BuiltValueField(wireName: r'manifestKeyEpoch')
  int get manifestKeyEpoch;

  @BuiltValueField(wireName: r'manifestRevision')
  int get manifestRevision;

  @BuiltValueField(wireName: r'chunkCount')
  int get chunkCount;

  @BuiltValueField(wireName: r'totalCiphertextBytes')
  int get totalCiphertextBytes;

  AttachmentCreateUploadRequest._();

  factory AttachmentCreateUploadRequest([
    void updates(AttachmentCreateUploadRequestBuilder b),
  ]) = _$AttachmentCreateUploadRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(AttachmentCreateUploadRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AttachmentCreateUploadRequest> get serializer =>
      _$AttachmentCreateUploadRequestSerializer();
}

class _$AttachmentCreateUploadRequestSerializer
    implements PrimitiveSerializer<AttachmentCreateUploadRequest> {
  @override
  final Iterable<Type> types = const [
    AttachmentCreateUploadRequest,
    _$AttachmentCreateUploadRequest,
  ];

  @override
  final String wireName = r'AttachmentCreateUploadRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AttachmentCreateUploadRequest object, {
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
    yield r'chunkKeyEpoch';
    yield serializers.serialize(
      object.chunkKeyEpoch,
      specifiedType: const FullType(int),
    );
    yield r'manifestKeyEpoch';
    yield serializers.serialize(
      object.manifestKeyEpoch,
      specifiedType: const FullType(int),
    );
    yield r'manifestRevision';
    yield serializers.serialize(
      object.manifestRevision,
      specifiedType: const FullType(int),
    );
    yield r'chunkCount';
    yield serializers.serialize(
      object.chunkCount,
      specifiedType: const FullType(int),
    );
    yield r'totalCiphertextBytes';
    yield serializers.serialize(
      object.totalCiphertextBytes,
      specifiedType: const FullType(int),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    AttachmentCreateUploadRequest object, {
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
    required AttachmentCreateUploadRequestBuilder result,
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
        case r'chunkKeyEpoch':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.chunkKeyEpoch = valueDes;
          break;
        case r'manifestKeyEpoch':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.manifestKeyEpoch = valueDes;
          break;
        case r'manifestRevision':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.manifestRevision = valueDes;
          break;
        case r'chunkCount':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.chunkCount = valueDes;
          break;
        case r'totalCiphertextBytes':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.totalCiphertextBytes = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  AttachmentCreateUploadRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = AttachmentCreateUploadRequestBuilder();
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
