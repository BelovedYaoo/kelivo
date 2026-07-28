//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'attachment_get_manifest_request.g.dart';

/// AttachmentGetManifestRequest
///
/// Properties:
/// * [attachmentId]
/// * [uploadId]
/// * [keyEpoch]
@BuiltValue()
abstract class AttachmentGetManifestRequest
    implements
        Built<
          AttachmentGetManifestRequest,
          AttachmentGetManifestRequestBuilder
        > {
  @BuiltValueField(wireName: r'attachmentId')
  String get attachmentId;

  @BuiltValueField(wireName: r'uploadId')
  String get uploadId;

  @BuiltValueField(wireName: r'keyEpoch')
  int get keyEpoch;

  AttachmentGetManifestRequest._();

  factory AttachmentGetManifestRequest([
    void updates(AttachmentGetManifestRequestBuilder b),
  ]) = _$AttachmentGetManifestRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(AttachmentGetManifestRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AttachmentGetManifestRequest> get serializer =>
      _$AttachmentGetManifestRequestSerializer();
}

class _$AttachmentGetManifestRequestSerializer
    implements PrimitiveSerializer<AttachmentGetManifestRequest> {
  @override
  final Iterable<Type> types = const [
    AttachmentGetManifestRequest,
    _$AttachmentGetManifestRequest,
  ];

  @override
  final String wireName = r'AttachmentGetManifestRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AttachmentGetManifestRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
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
    AttachmentGetManifestRequest object, {
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
    required AttachmentGetManifestRequestBuilder result,
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
  AttachmentGetManifestRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = AttachmentGetManifestRequestBuilder();
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
