//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/attachment_chunk_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'get_encrypted_attachment_chunk_response.g.dart';

/// GetEncryptedAttachmentChunkResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class GetEncryptedAttachmentChunkResponse
    implements
        Built<
          GetEncryptedAttachmentChunkResponse,
          GetEncryptedAttachmentChunkResponseBuilder
        > {
  @BuiltValueField(wireName: r'data')
  AttachmentChunkData get data;

  GetEncryptedAttachmentChunkResponse._();

  factory GetEncryptedAttachmentChunkResponse([
    void updates(GetEncryptedAttachmentChunkResponseBuilder b),
  ]) = _$GetEncryptedAttachmentChunkResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(GetEncryptedAttachmentChunkResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<GetEncryptedAttachmentChunkResponse> get serializer =>
      _$GetEncryptedAttachmentChunkResponseSerializer();
}

class _$GetEncryptedAttachmentChunkResponseSerializer
    implements PrimitiveSerializer<GetEncryptedAttachmentChunkResponse> {
  @override
  final Iterable<Type> types = const [
    GetEncryptedAttachmentChunkResponse,
    _$GetEncryptedAttachmentChunkResponse,
  ];

  @override
  final String wireName = r'GetEncryptedAttachmentChunkResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    GetEncryptedAttachmentChunkResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(AttachmentChunkData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    GetEncryptedAttachmentChunkResponse object, {
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
    required GetEncryptedAttachmentChunkResponseBuilder result,
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
                    specifiedType: const FullType(AttachmentChunkData),
                  )
                  as AttachmentChunkData;
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
  GetEncryptedAttachmentChunkResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = GetEncryptedAttachmentChunkResponseBuilder();
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
