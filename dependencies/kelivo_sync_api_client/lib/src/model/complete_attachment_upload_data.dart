//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/attachment_info.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'complete_attachment_upload_data.g.dart';

/// CompleteAttachmentUploadData
///
/// Properties:
/// * [attachment]
@BuiltValue()
abstract class CompleteAttachmentUploadData
    implements
        Built<
          CompleteAttachmentUploadData,
          CompleteAttachmentUploadDataBuilder
        > {
  @BuiltValueField(wireName: r'attachment')
  AttachmentInfo get attachment;

  CompleteAttachmentUploadData._();

  factory CompleteAttachmentUploadData([
    void updates(CompleteAttachmentUploadDataBuilder b),
  ]) = _$CompleteAttachmentUploadData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(CompleteAttachmentUploadDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<CompleteAttachmentUploadData> get serializer =>
      _$CompleteAttachmentUploadDataSerializer();
}

class _$CompleteAttachmentUploadDataSerializer
    implements PrimitiveSerializer<CompleteAttachmentUploadData> {
  @override
  final Iterable<Type> types = const [
    CompleteAttachmentUploadData,
    _$CompleteAttachmentUploadData,
  ];

  @override
  final String wireName = r'CompleteAttachmentUploadData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    CompleteAttachmentUploadData object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'attachment';
    yield serializers.serialize(
      object.attachment,
      specifiedType: const FullType(AttachmentInfo),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    CompleteAttachmentUploadData object, {
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
    required CompleteAttachmentUploadDataBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'attachment':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(AttachmentInfo),
                  )
                  as AttachmentInfo;
          result.attachment.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  CompleteAttachmentUploadData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = CompleteAttachmentUploadDataBuilder();
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
