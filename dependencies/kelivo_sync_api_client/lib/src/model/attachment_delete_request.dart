//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'attachment_delete_request.g.dart';

/// AttachmentDeleteRequest
///
/// Properties:
/// * [mutationId]
/// * [attachmentId]
/// * [uploadId]
/// * [keyEpoch]
@BuiltValue()
abstract class AttachmentDeleteRequest
    implements Built<AttachmentDeleteRequest, AttachmentDeleteRequestBuilder> {
  @BuiltValueField(wireName: r'mutationId')
  String get mutationId;

  @BuiltValueField(wireName: r'attachmentId')
  String get attachmentId;

  @BuiltValueField(wireName: r'uploadId')
  String get uploadId;

  @BuiltValueField(wireName: r'keyEpoch')
  int get keyEpoch;

  AttachmentDeleteRequest._();

  factory AttachmentDeleteRequest([
    void updates(AttachmentDeleteRequestBuilder b),
  ]) = _$AttachmentDeleteRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(AttachmentDeleteRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AttachmentDeleteRequest> get serializer =>
      _$AttachmentDeleteRequestSerializer();
}

class _$AttachmentDeleteRequestSerializer
    implements PrimitiveSerializer<AttachmentDeleteRequest> {
  @override
  final Iterable<Type> types = const [
    AttachmentDeleteRequest,
    _$AttachmentDeleteRequest,
  ];

  @override
  final String wireName = r'AttachmentDeleteRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AttachmentDeleteRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'mutationId';
    yield serializers.serialize(
      object.mutationId,
      specifiedType: const FullType(String),
    );
    yield r'attachmentId';
    yield serializers.serialize(
      object.attachmentId,
      specifiedType: const FullType(String),
    );
    yield r'uploadId';
    yield serializers.serialize(
      object.uploadId,
      specifiedType: const FullType(String),
    );
    yield r'keyEpoch';
    yield serializers.serialize(
      object.keyEpoch,
      specifiedType: const FullType(int),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    AttachmentDeleteRequest object, {
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
    required AttachmentDeleteRequestBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'mutationId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.mutationId = valueDes;
          break;
        case r'attachmentId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.attachmentId = valueDes;
          break;
        case r'uploadId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.uploadId = valueDes;
          break;
        case r'keyEpoch':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.keyEpoch = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  AttachmentDeleteRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = AttachmentDeleteRequestBuilder();
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
