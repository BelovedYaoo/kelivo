//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'delete_attachment_info_request.g.dart';

/// DeleteAttachmentInfoRequest
///
/// Properties:
/// * [attachmentId]
@BuiltValue()
abstract class DeleteAttachmentInfoRequest
    implements
        Built<DeleteAttachmentInfoRequest, DeleteAttachmentInfoRequestBuilder> {
  @BuiltValueField(wireName: r'attachmentId')
  String get attachmentId;

  DeleteAttachmentInfoRequest._();

  factory DeleteAttachmentInfoRequest([
    void updates(DeleteAttachmentInfoRequestBuilder b),
  ]) = _$DeleteAttachmentInfoRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DeleteAttachmentInfoRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DeleteAttachmentInfoRequest> get serializer =>
      _$DeleteAttachmentInfoRequestSerializer();
}

class _$DeleteAttachmentInfoRequestSerializer
    implements PrimitiveSerializer<DeleteAttachmentInfoRequest> {
  @override
  final Iterable<Type> types = const [
    DeleteAttachmentInfoRequest,
    _$DeleteAttachmentInfoRequest,
  ];

  @override
  final String wireName = r'DeleteAttachmentInfoRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DeleteAttachmentInfoRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'attachmentId';
    yield serializers.serialize(
      object.attachmentId,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    DeleteAttachmentInfoRequest object, {
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
    required DeleteAttachmentInfoRequestBuilder result,
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
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  DeleteAttachmentInfoRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DeleteAttachmentInfoRequestBuilder();
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
