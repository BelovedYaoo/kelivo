//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'prepare_attachment_upload_request.g.dart';

/// PrepareAttachmentUploadRequest
///
/// Properties:
/// * [sha256]
/// * [md5] - 文件 MD5 摘要，使用标准 Base64 编码
/// * [sizeBytes]
@BuiltValue()
abstract class PrepareAttachmentUploadRequest
    implements
        Built<
          PrepareAttachmentUploadRequest,
          PrepareAttachmentUploadRequestBuilder
        > {
  @BuiltValueField(wireName: r'sha256')
  String get sha256;

  /// 文件 MD5 摘要，使用标准 Base64 编码
  @BuiltValueField(wireName: r'md5')
  String get md5;

  @BuiltValueField(wireName: r'sizeBytes')
  int get sizeBytes;

  PrepareAttachmentUploadRequest._();

  factory PrepareAttachmentUploadRequest([
    void updates(PrepareAttachmentUploadRequestBuilder b),
  ]) = _$PrepareAttachmentUploadRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(PrepareAttachmentUploadRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<PrepareAttachmentUploadRequest> get serializer =>
      _$PrepareAttachmentUploadRequestSerializer();
}

class _$PrepareAttachmentUploadRequestSerializer
    implements PrimitiveSerializer<PrepareAttachmentUploadRequest> {
  @override
  final Iterable<Type> types = const [
    PrepareAttachmentUploadRequest,
    _$PrepareAttachmentUploadRequest,
  ];

  @override
  final String wireName = r'PrepareAttachmentUploadRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    PrepareAttachmentUploadRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'sha256';
    yield serializers.serialize(
      object.sha256,
      specifiedType: const FullType(String),
    );
    yield r'md5';
    yield serializers.serialize(
      object.md5,
      specifiedType: const FullType(String),
    );
    yield r'sizeBytes';
    yield serializers.serialize(
      object.sizeBytes,
      specifiedType: const FullType(int),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    PrepareAttachmentUploadRequest object, {
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
    required PrepareAttachmentUploadRequestBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'sha256':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.sha256 = valueDes;
          break;
        case r'md5':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.md5 = valueDes;
          break;
        case r'sizeBytes':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.sizeBytes = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  PrepareAttachmentUploadRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = PrepareAttachmentUploadRequestBuilder();
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
