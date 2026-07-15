//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'list_attachment_info_request.g.dart';

/// ListAttachmentInfoRequest
///
/// Properties:
/// * [entityType]
/// * [entityId]
@BuiltValue()
abstract class ListAttachmentInfoRequest
    implements
        Built<ListAttachmentInfoRequest, ListAttachmentInfoRequestBuilder> {
  @BuiltValueField(wireName: r'entityType')
  String get entityType;

  @BuiltValueField(wireName: r'entityId')
  String get entityId;

  ListAttachmentInfoRequest._();

  factory ListAttachmentInfoRequest([
    void updates(ListAttachmentInfoRequestBuilder b),
  ]) = _$ListAttachmentInfoRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ListAttachmentInfoRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ListAttachmentInfoRequest> get serializer =>
      _$ListAttachmentInfoRequestSerializer();
}

class _$ListAttachmentInfoRequestSerializer
    implements PrimitiveSerializer<ListAttachmentInfoRequest> {
  @override
  final Iterable<Type> types = const [
    ListAttachmentInfoRequest,
    _$ListAttachmentInfoRequest,
  ];

  @override
  final String wireName = r'ListAttachmentInfoRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ListAttachmentInfoRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'entityType';
    yield serializers.serialize(
      object.entityType,
      specifiedType: const FullType(String),
    );
    yield r'entityId';
    yield serializers.serialize(
      object.entityId,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ListAttachmentInfoRequest object, {
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
    required ListAttachmentInfoRequestBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'entityType':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.entityType = valueDes;
          break;
        case r'entityId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.entityId = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ListAttachmentInfoRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ListAttachmentInfoRequestBuilder();
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
