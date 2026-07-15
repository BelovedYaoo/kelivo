//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/get_attachment_download_url_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'get_attachment_download_url_response.g.dart';

/// GetAttachmentDownloadUrlResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class GetAttachmentDownloadUrlResponse
    implements
        Built<
          GetAttachmentDownloadUrlResponse,
          GetAttachmentDownloadUrlResponseBuilder
        > {
  @BuiltValueField(wireName: r'data')
  GetAttachmentDownloadUrlData get data;

  GetAttachmentDownloadUrlResponse._();

  factory GetAttachmentDownloadUrlResponse([
    void updates(GetAttachmentDownloadUrlResponseBuilder b),
  ]) = _$GetAttachmentDownloadUrlResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(GetAttachmentDownloadUrlResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<GetAttachmentDownloadUrlResponse> get serializer =>
      _$GetAttachmentDownloadUrlResponseSerializer();
}

class _$GetAttachmentDownloadUrlResponseSerializer
    implements PrimitiveSerializer<GetAttachmentDownloadUrlResponse> {
  @override
  final Iterable<Type> types = const [
    GetAttachmentDownloadUrlResponse,
    _$GetAttachmentDownloadUrlResponse,
  ];

  @override
  final String wireName = r'GetAttachmentDownloadUrlResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    GetAttachmentDownloadUrlResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(GetAttachmentDownloadUrlData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    GetAttachmentDownloadUrlResponse object, {
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
    required GetAttachmentDownloadUrlResponseBuilder result,
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
                    specifiedType: const FullType(GetAttachmentDownloadUrlData),
                  )
                  as GetAttachmentDownloadUrlData;
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
  GetAttachmentDownloadUrlResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = GetAttachmentDownloadUrlResponseBuilder();
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
