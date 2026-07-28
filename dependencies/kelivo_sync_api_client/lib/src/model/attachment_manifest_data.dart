//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/attachment_manifest_chunk.dart';
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'attachment_manifest_data.g.dart';

/// AttachmentManifestData
///
/// Properties:
/// * [attachmentId]
/// * [uploadId]
/// * [keyEpoch]
/// * [chunkCount]
/// * [totalCiphertextBytes]
/// * [manifestCiphertext] - 客户端认证的附件清单密文，使用规范无填充 Base64URL 编码，解码后最大 1 MiB
/// * [manifestCiphertextBytes]
/// * [chunks]
/// * [committedAt]
@BuiltValue()
abstract class AttachmentManifestData
    implements Built<AttachmentManifestData, AttachmentManifestDataBuilder> {
  @BuiltValueField(wireName: r'attachmentId')
  String get attachmentId;

  @BuiltValueField(wireName: r'uploadId')
  String get uploadId;

  @BuiltValueField(wireName: r'keyEpoch')
  int get keyEpoch;

  @BuiltValueField(wireName: r'chunkCount')
  int get chunkCount;

  @BuiltValueField(wireName: r'totalCiphertextBytes')
  int get totalCiphertextBytes;

  /// 客户端认证的附件清单密文，使用规范无填充 Base64URL 编码，解码后最大 1 MiB
  @BuiltValueField(wireName: r'manifestCiphertext')
  String get manifestCiphertext;

  @BuiltValueField(wireName: r'manifestCiphertextBytes')
  int get manifestCiphertextBytes;

  @BuiltValueField(wireName: r'chunks')
  BuiltList<AttachmentManifestChunk> get chunks;

  @BuiltValueField(wireName: r'committedAt')
  DateTime get committedAt;

  AttachmentManifestData._();

  factory AttachmentManifestData([
    void updates(AttachmentManifestDataBuilder b),
  ]) = _$AttachmentManifestData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(AttachmentManifestDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AttachmentManifestData> get serializer =>
      _$AttachmentManifestDataSerializer();
}

class _$AttachmentManifestDataSerializer
    implements PrimitiveSerializer<AttachmentManifestData> {
  @override
  final Iterable<Type> types = const [
    AttachmentManifestData,
    _$AttachmentManifestData,
  ];

  @override
  final String wireName = r'AttachmentManifestData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AttachmentManifestData object, {
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
    yield r'chunkCount';
    yield serializers.serialize(
      object.chunkCount,
      specifiedType: const FullType(int),
    );
    yield r'totalCiphertextBytes';
    yield serializers.serialize(
      object.totalCiphertextBytes,
      specifiedType: const FullType(int),
    );
    yield r'manifestCiphertext';
    yield serializers.serialize(
      object.manifestCiphertext,
      specifiedType: const FullType(String),
    );
    yield r'manifestCiphertextBytes';
    yield serializers.serialize(
      object.manifestCiphertextBytes,
      specifiedType: const FullType(int),
    );
    yield r'chunks';
    yield serializers.serialize(
      object.chunks,
      specifiedType: const FullType(BuiltList, [
        FullType(AttachmentManifestChunk),
      ]),
    );
    yield r'committedAt';
    yield serializers.serialize(
      object.committedAt,
      specifiedType: const FullType(DateTime),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    AttachmentManifestData object, {
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
    required AttachmentManifestDataBuilder result,
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
        case r'chunkCount':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.chunkCount = valueDes;
          break;
        case r'totalCiphertextBytes':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.totalCiphertextBytes = valueDes;
          break;
        case r'manifestCiphertext':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.manifestCiphertext = valueDes;
          break;
        case r'manifestCiphertextBytes':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.manifestCiphertextBytes = valueDes;
          break;
        case r'chunks':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(BuiltList, [
                      FullType(AttachmentManifestChunk),
                    ]),
                  )
                  as BuiltList<AttachmentManifestChunk>;
          result.chunks.replace(valueDes);
          break;
        case r'committedAt':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(DateTime),
                  )
                  as DateTime;
          result.committedAt = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  AttachmentManifestData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = AttachmentManifestDataBuilder();
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
