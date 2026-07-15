//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'get_attachment_download_url_request.g.dart';

/// GetAttachmentDownloadUrlRequest
///
/// Properties:
/// * [attachmentId]
@BuiltValue()
abstract class GetAttachmentDownloadUrlRequest
    implements
        Built<
          GetAttachmentDownloadUrlRequest,
          GetAttachmentDownloadUrlRequestBuilder
        > {
  @BuiltValueField(wireName: r'attachmentId')
  String get attachmentId;

  GetAttachmentDownloadUrlRequest._();

  factory GetAttachmentDownloadUrlRequest([
    void updates(GetAttachmentDownloadUrlRequestBuilder b),
  ]) = _$GetAttachmentDownloadUrlRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(GetAttachmentDownloadUrlRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<GetAttachmentDownloadUrlRequest> get serializer =>
      _$GetAttachmentDownloadUrlRequestSerializer();
}

class _$GetAttachmentDownloadUrlRequestSerializer
    implements PrimitiveSerializer<GetAttachmentDownloadUrlRequest> {
  @override
  final Iterable<Type> types = const [
    GetAttachmentDownloadUrlRequest,
    _$GetAttachmentDownloadUrlRequest,
  ];

  @override
  final String wireName = r'GetAttachmentDownloadUrlRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    GetAttachmentDownloadUrlRequest object, {
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
    GetAttachmentDownloadUrlRequest object, {
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
    required GetAttachmentDownloadUrlRequestBuilder result,
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
  GetAttachmentDownloadUrlRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = GetAttachmentDownloadUrlRequestBuilder();
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
