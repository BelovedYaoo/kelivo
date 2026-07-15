//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/delete_attachment_info_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'delete_attachment_info_response.g.dart';

/// DeleteAttachmentInfoResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class DeleteAttachmentInfoResponse
    implements
        Built<
          DeleteAttachmentInfoResponse,
          DeleteAttachmentInfoResponseBuilder
        > {
  @BuiltValueField(wireName: r'data')
  DeleteAttachmentInfoData get data;

  DeleteAttachmentInfoResponse._();

  factory DeleteAttachmentInfoResponse([
    void updates(DeleteAttachmentInfoResponseBuilder b),
  ]) = _$DeleteAttachmentInfoResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DeleteAttachmentInfoResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DeleteAttachmentInfoResponse> get serializer =>
      _$DeleteAttachmentInfoResponseSerializer();
}

class _$DeleteAttachmentInfoResponseSerializer
    implements PrimitiveSerializer<DeleteAttachmentInfoResponse> {
  @override
  final Iterable<Type> types = const [
    DeleteAttachmentInfoResponse,
    _$DeleteAttachmentInfoResponse,
  ];

  @override
  final String wireName = r'DeleteAttachmentInfoResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DeleteAttachmentInfoResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(DeleteAttachmentInfoData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    DeleteAttachmentInfoResponse object, {
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
    required DeleteAttachmentInfoResponseBuilder result,
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
                    specifiedType: const FullType(DeleteAttachmentInfoData),
                  )
                  as DeleteAttachmentInfoData;
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
  DeleteAttachmentInfoResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DeleteAttachmentInfoResponseBuilder();
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
