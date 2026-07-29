//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'data_rekey_source_attachment_data_chunks_inner.g.dart';

/// DataRekeySourceAttachmentDataChunksInner
///
/// Properties:
/// * [chunkIndex]
/// * [ciphertextBytes]
/// * [ciphertextDigest]
@BuiltValue()
abstract class DataRekeySourceAttachmentDataChunksInner
    implements
        Built<
          DataRekeySourceAttachmentDataChunksInner,
          DataRekeySourceAttachmentDataChunksInnerBuilder
        > {
  @BuiltValueField(wireName: r'chunkIndex')
  int get chunkIndex;

  @BuiltValueField(wireName: r'ciphertextBytes')
  int get ciphertextBytes;

  @BuiltValueField(wireName: r'ciphertextDigest')
  String get ciphertextDigest;

  DataRekeySourceAttachmentDataChunksInner._();

  factory DataRekeySourceAttachmentDataChunksInner([
    void updates(DataRekeySourceAttachmentDataChunksInnerBuilder b),
  ]) = _$DataRekeySourceAttachmentDataChunksInner;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DataRekeySourceAttachmentDataChunksInnerBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DataRekeySourceAttachmentDataChunksInner> get serializer =>
      _$DataRekeySourceAttachmentDataChunksInnerSerializer();
}

class _$DataRekeySourceAttachmentDataChunksInnerSerializer
    implements PrimitiveSerializer<DataRekeySourceAttachmentDataChunksInner> {
  @override
  final Iterable<Type> types = const [
    DataRekeySourceAttachmentDataChunksInner,
    _$DataRekeySourceAttachmentDataChunksInner,
  ];

  @override
  final String wireName = r'DataRekeySourceAttachmentDataChunksInner';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DataRekeySourceAttachmentDataChunksInner object, {
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
    yield r'ciphertextDigest';
    yield serializers.serialize(
      object.ciphertextDigest,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    DataRekeySourceAttachmentDataChunksInner object, {
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
    required DataRekeySourceAttachmentDataChunksInnerBuilder result,
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
        case r'ciphertextDigest':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.ciphertextDigest = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  DataRekeySourceAttachmentDataChunksInner deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DataRekeySourceAttachmentDataChunksInnerBuilder();
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
