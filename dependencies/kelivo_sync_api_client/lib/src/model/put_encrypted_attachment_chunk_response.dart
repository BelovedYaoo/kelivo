//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/attachment_stored_chunk_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'put_encrypted_attachment_chunk_response.g.dart';

/// PutEncryptedAttachmentChunkResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class PutEncryptedAttachmentChunkResponse
    implements
        Built<
          PutEncryptedAttachmentChunkResponse,
          PutEncryptedAttachmentChunkResponseBuilder
        > {
  @BuiltValueField(wireName: r'data')
  AttachmentStoredChunkData get data;

  PutEncryptedAttachmentChunkResponse._();

  factory PutEncryptedAttachmentChunkResponse([
    void updates(PutEncryptedAttachmentChunkResponseBuilder b),
  ]) = _$PutEncryptedAttachmentChunkResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(PutEncryptedAttachmentChunkResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<PutEncryptedAttachmentChunkResponse> get serializer =>
      _$PutEncryptedAttachmentChunkResponseSerializer();
}

class _$PutEncryptedAttachmentChunkResponseSerializer
    implements PrimitiveSerializer<PutEncryptedAttachmentChunkResponse> {
  @override
  final Iterable<Type> types = const [
    PutEncryptedAttachmentChunkResponse,
    _$PutEncryptedAttachmentChunkResponse,
  ];

  @override
  final String wireName = r'PutEncryptedAttachmentChunkResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    PutEncryptedAttachmentChunkResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(AttachmentStoredChunkData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    PutEncryptedAttachmentChunkResponse object, {
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
    required PutEncryptedAttachmentChunkResponseBuilder result,
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
                    specifiedType: const FullType(AttachmentStoredChunkData),
                  )
                  as AttachmentStoredChunkData;
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
  PutEncryptedAttachmentChunkResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = PutEncryptedAttachmentChunkResponseBuilder();
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
