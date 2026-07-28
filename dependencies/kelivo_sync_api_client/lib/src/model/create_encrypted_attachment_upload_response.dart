//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/attachment_upload_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'create_encrypted_attachment_upload_response.g.dart';

/// CreateEncryptedAttachmentUploadResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class CreateEncryptedAttachmentUploadResponse
    implements
        Built<
          CreateEncryptedAttachmentUploadResponse,
          CreateEncryptedAttachmentUploadResponseBuilder
        > {
  @BuiltValueField(wireName: r'data')
  AttachmentUploadData get data;

  CreateEncryptedAttachmentUploadResponse._();

  factory CreateEncryptedAttachmentUploadResponse([
    void updates(CreateEncryptedAttachmentUploadResponseBuilder b),
  ]) = _$CreateEncryptedAttachmentUploadResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(CreateEncryptedAttachmentUploadResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<CreateEncryptedAttachmentUploadResponse> get serializer =>
      _$CreateEncryptedAttachmentUploadResponseSerializer();
}

class _$CreateEncryptedAttachmentUploadResponseSerializer
    implements PrimitiveSerializer<CreateEncryptedAttachmentUploadResponse> {
  @override
  final Iterable<Type> types = const [
    CreateEncryptedAttachmentUploadResponse,
    _$CreateEncryptedAttachmentUploadResponse,
  ];

  @override
  final String wireName = r'CreateEncryptedAttachmentUploadResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    CreateEncryptedAttachmentUploadResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(AttachmentUploadData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    CreateEncryptedAttachmentUploadResponse object, {
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
    required CreateEncryptedAttachmentUploadResponseBuilder result,
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
                    specifiedType: const FullType(AttachmentUploadData),
                  )
                  as AttachmentUploadData;
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
  CreateEncryptedAttachmentUploadResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = CreateEncryptedAttachmentUploadResponseBuilder();
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
