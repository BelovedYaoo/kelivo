//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/list_attachment_info_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'list_attachment_info_response.g.dart';

/// ListAttachmentInfoResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class ListAttachmentInfoResponse
    implements
        Built<ListAttachmentInfoResponse, ListAttachmentInfoResponseBuilder> {
  @BuiltValueField(wireName: r'data')
  ListAttachmentInfoData get data;

  ListAttachmentInfoResponse._();

  factory ListAttachmentInfoResponse([
    void updates(ListAttachmentInfoResponseBuilder b),
  ]) = _$ListAttachmentInfoResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ListAttachmentInfoResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ListAttachmentInfoResponse> get serializer =>
      _$ListAttachmentInfoResponseSerializer();
}

class _$ListAttachmentInfoResponseSerializer
    implements PrimitiveSerializer<ListAttachmentInfoResponse> {
  @override
  final Iterable<Type> types = const [
    ListAttachmentInfoResponse,
    _$ListAttachmentInfoResponse,
  ];

  @override
  final String wireName = r'ListAttachmentInfoResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ListAttachmentInfoResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(ListAttachmentInfoData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ListAttachmentInfoResponse object, {
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
    required ListAttachmentInfoResponseBuilder result,
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
                    specifiedType: const FullType(ListAttachmentInfoData),
                  )
                  as ListAttachmentInfoData;
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
  ListAttachmentInfoResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ListAttachmentInfoResponseBuilder();
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
