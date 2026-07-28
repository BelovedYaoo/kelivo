//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/attachment_deleted_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'delete_encrypted_attachment_response.g.dart';

/// DeleteEncryptedAttachmentResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class DeleteEncryptedAttachmentResponse
    implements
        Built<
          DeleteEncryptedAttachmentResponse,
          DeleteEncryptedAttachmentResponseBuilder
        > {
  @BuiltValueField(wireName: r'data')
  AttachmentDeletedData get data;

  DeleteEncryptedAttachmentResponse._();

  factory DeleteEncryptedAttachmentResponse([
    void updates(DeleteEncryptedAttachmentResponseBuilder b),
  ]) = _$DeleteEncryptedAttachmentResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DeleteEncryptedAttachmentResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DeleteEncryptedAttachmentResponse> get serializer =>
      _$DeleteEncryptedAttachmentResponseSerializer();
}

class _$DeleteEncryptedAttachmentResponseSerializer
    implements PrimitiveSerializer<DeleteEncryptedAttachmentResponse> {
  @override
  final Iterable<Type> types = const [
    DeleteEncryptedAttachmentResponse,
    _$DeleteEncryptedAttachmentResponse,
  ];

  @override
  final String wireName = r'DeleteEncryptedAttachmentResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DeleteEncryptedAttachmentResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(AttachmentDeletedData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    DeleteEncryptedAttachmentResponse object, {
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
    required DeleteEncryptedAttachmentResponseBuilder result,
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
                    specifiedType: const FullType(AttachmentDeletedData),
                  )
                  as AttachmentDeletedData;
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
  DeleteEncryptedAttachmentResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DeleteEncryptedAttachmentResponseBuilder();
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
