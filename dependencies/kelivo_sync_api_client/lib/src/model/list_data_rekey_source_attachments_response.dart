//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/data_rekey_source_attachment_list_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'list_data_rekey_source_attachments_response.g.dart';

/// ListDataRekeySourceAttachmentsResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class ListDataRekeySourceAttachmentsResponse
    implements
        Built<
          ListDataRekeySourceAttachmentsResponse,
          ListDataRekeySourceAttachmentsResponseBuilder
        > {
  @BuiltValueField(wireName: r'data')
  DataRekeySourceAttachmentListData get data;

  ListDataRekeySourceAttachmentsResponse._();

  factory ListDataRekeySourceAttachmentsResponse([
    void updates(ListDataRekeySourceAttachmentsResponseBuilder b),
  ]) = _$ListDataRekeySourceAttachmentsResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ListDataRekeySourceAttachmentsResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ListDataRekeySourceAttachmentsResponse> get serializer =>
      _$ListDataRekeySourceAttachmentsResponseSerializer();
}

class _$ListDataRekeySourceAttachmentsResponseSerializer
    implements PrimitiveSerializer<ListDataRekeySourceAttachmentsResponse> {
  @override
  final Iterable<Type> types = const [
    ListDataRekeySourceAttachmentsResponse,
    _$ListDataRekeySourceAttachmentsResponse,
  ];

  @override
  final String wireName = r'ListDataRekeySourceAttachmentsResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ListDataRekeySourceAttachmentsResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(DataRekeySourceAttachmentListData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ListDataRekeySourceAttachmentsResponse object, {
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
    required ListDataRekeySourceAttachmentsResponseBuilder result,
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
                    specifiedType: const FullType(
                      DataRekeySourceAttachmentListData,
                    ),
                  )
                  as DataRekeySourceAttachmentListData;
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
  ListDataRekeySourceAttachmentsResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ListDataRekeySourceAttachmentsResponseBuilder();
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
