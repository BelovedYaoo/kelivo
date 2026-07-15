//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'get_attachment_download_url_data.g.dart';

/// GetAttachmentDownloadUrlData
///
/// Properties:
/// * [attachmentId]
/// * [downloadUrl]
/// * [expiresAt]
@BuiltValue()
abstract class GetAttachmentDownloadUrlData
    implements
        Built<
          GetAttachmentDownloadUrlData,
          GetAttachmentDownloadUrlDataBuilder
        > {
  @BuiltValueField(wireName: r'attachmentId')
  String get attachmentId;

  @BuiltValueField(wireName: r'downloadUrl')
  String get downloadUrl;

  @BuiltValueField(wireName: r'expiresAt')
  DateTime get expiresAt;

  GetAttachmentDownloadUrlData._();

  factory GetAttachmentDownloadUrlData([
    void updates(GetAttachmentDownloadUrlDataBuilder b),
  ]) = _$GetAttachmentDownloadUrlData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(GetAttachmentDownloadUrlDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<GetAttachmentDownloadUrlData> get serializer =>
      _$GetAttachmentDownloadUrlDataSerializer();
}

class _$GetAttachmentDownloadUrlDataSerializer
    implements PrimitiveSerializer<GetAttachmentDownloadUrlData> {
  @override
  final Iterable<Type> types = const [
    GetAttachmentDownloadUrlData,
    _$GetAttachmentDownloadUrlData,
  ];

  @override
  final String wireName = r'GetAttachmentDownloadUrlData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    GetAttachmentDownloadUrlData object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'attachmentId';
    yield serializers.serialize(
      object.attachmentId,
      specifiedType: const FullType(String),
    );
    yield r'downloadUrl';
    yield serializers.serialize(
      object.downloadUrl,
      specifiedType: const FullType(String),
    );
    yield r'expiresAt';
    yield serializers.serialize(
      object.expiresAt,
      specifiedType: const FullType(DateTime),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    GetAttachmentDownloadUrlData object, {
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
    required GetAttachmentDownloadUrlDataBuilder result,
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
        case r'downloadUrl':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.downloadUrl = valueDes;
          break;
        case r'expiresAt':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(DateTime),
                  )
                  as DateTime;
          result.expiresAt = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  GetAttachmentDownloadUrlData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = GetAttachmentDownloadUrlDataBuilder();
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
