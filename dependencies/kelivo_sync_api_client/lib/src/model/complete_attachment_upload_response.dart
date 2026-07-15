//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/complete_attachment_upload_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'complete_attachment_upload_response.g.dart';

/// CompleteAttachmentUploadResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class CompleteAttachmentUploadResponse
    implements
        Built<
          CompleteAttachmentUploadResponse,
          CompleteAttachmentUploadResponseBuilder
        > {
  @BuiltValueField(wireName: r'data')
  CompleteAttachmentUploadData get data;

  CompleteAttachmentUploadResponse._();

  factory CompleteAttachmentUploadResponse([
    void updates(CompleteAttachmentUploadResponseBuilder b),
  ]) = _$CompleteAttachmentUploadResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(CompleteAttachmentUploadResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<CompleteAttachmentUploadResponse> get serializer =>
      _$CompleteAttachmentUploadResponseSerializer();
}

class _$CompleteAttachmentUploadResponseSerializer
    implements PrimitiveSerializer<CompleteAttachmentUploadResponse> {
  @override
  final Iterable<Type> types = const [
    CompleteAttachmentUploadResponse,
    _$CompleteAttachmentUploadResponse,
  ];

  @override
  final String wireName = r'CompleteAttachmentUploadResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    CompleteAttachmentUploadResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(CompleteAttachmentUploadData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    CompleteAttachmentUploadResponse object, {
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
    required CompleteAttachmentUploadResponseBuilder result,
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
                    specifiedType: const FullType(CompleteAttachmentUploadData),
                  )
                  as CompleteAttachmentUploadData;
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
  CompleteAttachmentUploadResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = CompleteAttachmentUploadResponseBuilder();
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
