//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'attachment_manifest_chunk.g.dart';

/// AttachmentManifestChunk
///
/// Properties:
/// * [chunkIndex]
/// * [ciphertextBytes]
@BuiltValue()
abstract class AttachmentManifestChunk
    implements Built<AttachmentManifestChunk, AttachmentManifestChunkBuilder> {
  @BuiltValueField(wireName: r'chunkIndex')
  int get chunkIndex;

  @BuiltValueField(wireName: r'ciphertextBytes')
  int get ciphertextBytes;

  AttachmentManifestChunk._();

  factory AttachmentManifestChunk([
    void updates(AttachmentManifestChunkBuilder b),
  ]) = _$AttachmentManifestChunk;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(AttachmentManifestChunkBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AttachmentManifestChunk> get serializer =>
      _$AttachmentManifestChunkSerializer();
}

class _$AttachmentManifestChunkSerializer
    implements PrimitiveSerializer<AttachmentManifestChunk> {
  @override
  final Iterable<Type> types = const [
    AttachmentManifestChunk,
    _$AttachmentManifestChunk,
  ];

  @override
  final String wireName = r'AttachmentManifestChunk';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AttachmentManifestChunk object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'chunkIndex';
    yield serializers.serialize(
      object.chunkIndex,
      specifiedType: const FullType(int),
    );
    yield r'ciphertextBytes';
    yield serializers.serialize(
      object.ciphertextBytes,
      specifiedType: const FullType(int),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    AttachmentManifestChunk object, {
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
    required AttachmentManifestChunkBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'chunkIndex':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.chunkIndex = valueDes;
          break;
        case r'ciphertextBytes':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.ciphertextBytes = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  AttachmentManifestChunk deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = AttachmentManifestChunkBuilder();
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
