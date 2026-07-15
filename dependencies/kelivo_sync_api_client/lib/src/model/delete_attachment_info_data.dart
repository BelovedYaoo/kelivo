//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'delete_attachment_info_data.g.dart';

/// DeleteAttachmentInfoData
///
/// Properties:
/// * [attachmentId]
/// * [deleted]
@BuiltValue()
abstract class DeleteAttachmentInfoData
    implements
        Built<DeleteAttachmentInfoData, DeleteAttachmentInfoDataBuilder> {
  @BuiltValueField(wireName: r'attachmentId')
  String get attachmentId;

  @BuiltValueField(wireName: r'deleted')
  bool get deleted;

  DeleteAttachmentInfoData._();

  factory DeleteAttachmentInfoData([
    void updates(DeleteAttachmentInfoDataBuilder b),
  ]) = _$DeleteAttachmentInfoData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DeleteAttachmentInfoDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DeleteAttachmentInfoData> get serializer =>
      _$DeleteAttachmentInfoDataSerializer();
}

class _$DeleteAttachmentInfoDataSerializer
    implements PrimitiveSerializer<DeleteAttachmentInfoData> {
  @override
  final Iterable<Type> types = const [
    DeleteAttachmentInfoData,
    _$DeleteAttachmentInfoData,
  ];

  @override
  final String wireName = r'DeleteAttachmentInfoData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DeleteAttachmentInfoData object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'attachmentId';
    yield serializers.serialize(
      object.attachmentId,
      specifiedType: const FullType(String),
    );
    yield r'deleted';
    yield serializers.serialize(
      object.deleted,
      specifiedType: const FullType(bool),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    DeleteAttachmentInfoData object, {
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
    required DeleteAttachmentInfoDataBuilder result,
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
        case r'deleted':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(bool),
                  )
                  as bool;
          result.deleted = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  DeleteAttachmentInfoData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DeleteAttachmentInfoDataBuilder();
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
