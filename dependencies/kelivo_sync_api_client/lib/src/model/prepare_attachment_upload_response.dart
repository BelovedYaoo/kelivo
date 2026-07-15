//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/prepare_attachment_upload_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'prepare_attachment_upload_response.g.dart';

/// PrepareAttachmentUploadResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class PrepareAttachmentUploadResponse
    implements
        Built<
          PrepareAttachmentUploadResponse,
          PrepareAttachmentUploadResponseBuilder
        > {
  @BuiltValueField(wireName: r'data')
  PrepareAttachmentUploadData get data;

  PrepareAttachmentUploadResponse._();

  factory PrepareAttachmentUploadResponse([
    void updates(PrepareAttachmentUploadResponseBuilder b),
  ]) = _$PrepareAttachmentUploadResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(PrepareAttachmentUploadResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<PrepareAttachmentUploadResponse> get serializer =>
      _$PrepareAttachmentUploadResponseSerializer();
}

class _$PrepareAttachmentUploadResponseSerializer
    implements PrimitiveSerializer<PrepareAttachmentUploadResponse> {
  @override
  final Iterable<Type> types = const [
    PrepareAttachmentUploadResponse,
    _$PrepareAttachmentUploadResponse,
  ];

  @override
  final String wireName = r'PrepareAttachmentUploadResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    PrepareAttachmentUploadResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(PrepareAttachmentUploadData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    PrepareAttachmentUploadResponse object, {
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
    required PrepareAttachmentUploadResponseBuilder result,
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
                    specifiedType: const FullType(PrepareAttachmentUploadData),
                  )
                  as PrepareAttachmentUploadData;
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
  PrepareAttachmentUploadResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = PrepareAttachmentUploadResponseBuilder();
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
