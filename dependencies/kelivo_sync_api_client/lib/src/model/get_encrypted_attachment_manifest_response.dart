//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/attachment_manifest_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'get_encrypted_attachment_manifest_response.g.dart';

/// GetEncryptedAttachmentManifestResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class GetEncryptedAttachmentManifestResponse
    implements
        Built<
          GetEncryptedAttachmentManifestResponse,
          GetEncryptedAttachmentManifestResponseBuilder
        > {
  @BuiltValueField(wireName: r'data')
  AttachmentManifestData get data;

  GetEncryptedAttachmentManifestResponse._();

  factory GetEncryptedAttachmentManifestResponse([
    void updates(GetEncryptedAttachmentManifestResponseBuilder b),
  ]) = _$GetEncryptedAttachmentManifestResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(GetEncryptedAttachmentManifestResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<GetEncryptedAttachmentManifestResponse> get serializer =>
      _$GetEncryptedAttachmentManifestResponseSerializer();
}

class _$GetEncryptedAttachmentManifestResponseSerializer
    implements PrimitiveSerializer<GetEncryptedAttachmentManifestResponse> {
  @override
  final Iterable<Type> types = const [
    GetEncryptedAttachmentManifestResponse,
    _$GetEncryptedAttachmentManifestResponse,
  ];

  @override
  final String wireName = r'GetEncryptedAttachmentManifestResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    GetEncryptedAttachmentManifestResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(AttachmentManifestData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    GetEncryptedAttachmentManifestResponse object, {
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
    required GetEncryptedAttachmentManifestResponseBuilder result,
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
                    specifiedType: const FullType(AttachmentManifestData),
                  )
                  as AttachmentManifestData;
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
  GetEncryptedAttachmentManifestResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = GetEncryptedAttachmentManifestResponseBuilder();
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
