//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'attachment_get_chunk_request.g.dart';

/// AttachmentGetChunkRequest
///
/// Properties:
/// * [attachmentId]
/// * [uploadId]
/// * [keyEpoch]
/// * [chunkIndex]
@BuiltValue()
abstract class AttachmentGetChunkRequest
    implements
        Built<AttachmentGetChunkRequest, AttachmentGetChunkRequestBuilder> {
  @BuiltValueField(wireName: r'attachmentId')
  String get attachmentId;

  @BuiltValueField(wireName: r'uploadId')
  String get uploadId;

  @BuiltValueField(wireName: r'keyEpoch')
  int get keyEpoch;

  @BuiltValueField(wireName: r'chunkIndex')
  int get chunkIndex;

  AttachmentGetChunkRequest._();

  factory AttachmentGetChunkRequest([
    void updates(AttachmentGetChunkRequestBuilder b),
  ]) = _$AttachmentGetChunkRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(AttachmentGetChunkRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AttachmentGetChunkRequest> get serializer =>
      _$AttachmentGetChunkRequestSerializer();
}

class _$AttachmentGetChunkRequestSerializer
    implements PrimitiveSerializer<AttachmentGetChunkRequest> {
  @override
  final Iterable<Type> types = const [
    AttachmentGetChunkRequest,
    _$AttachmentGetChunkRequest,
  ];

  @override
  final String wireName = r'AttachmentGetChunkRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AttachmentGetChunkRequest object, {
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
  }

  @override
  Object serialize(
    Serializers serializers,
    AttachmentGetChunkRequest object, {
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
    required AttachmentGetChunkRequestBuilder result,
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
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  AttachmentGetChunkRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = AttachmentGetChunkRequestBuilder();
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
