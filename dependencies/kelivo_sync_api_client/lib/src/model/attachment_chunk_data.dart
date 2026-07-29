//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'attachment_chunk_data.g.dart';

/// AttachmentChunkData
///
/// Properties:
/// * [dataRekeyPhase]
/// * [attachmentId]
/// * [uploadId]
/// * [chunkKeyEpoch]
/// * [chunkIndex]
/// * [ciphertext] - 客户端生成的附件分块密文，使用规范无填充 Base64URL 编码，解码后最大 4 MiB
/// * [ciphertextBytes]
@BuiltValue()
abstract class AttachmentChunkData
    implements Built<AttachmentChunkData, AttachmentChunkDataBuilder> {
  @BuiltValueField(wireName: r'dataRekeyPhase')
  AttachmentChunkDataDataRekeyPhaseEnum get dataRekeyPhase;
  // enum dataRekeyPhaseEnum {  ready,  rekey-pending,  };

  @BuiltValueField(wireName: r'attachmentId')
  String get attachmentId;

  @BuiltValueField(wireName: r'uploadId')
  String get uploadId;

  @BuiltValueField(wireName: r'chunkKeyEpoch')
  int get chunkKeyEpoch;

  @BuiltValueField(wireName: r'chunkIndex')
  int get chunkIndex;

  /// 客户端生成的附件分块密文，使用规范无填充 Base64URL 编码，解码后最大 4 MiB
  @BuiltValueField(wireName: r'ciphertext')
  String get ciphertext;

  @BuiltValueField(wireName: r'ciphertextBytes')
  int get ciphertextBytes;

  AttachmentChunkData._();

  factory AttachmentChunkData([void updates(AttachmentChunkDataBuilder b)]) =
      _$AttachmentChunkData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(AttachmentChunkDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AttachmentChunkData> get serializer =>
      _$AttachmentChunkDataSerializer();
}

class _$AttachmentChunkDataSerializer
    implements PrimitiveSerializer<AttachmentChunkData> {
  @override
  final Iterable<Type> types = const [
    AttachmentChunkData,
    _$AttachmentChunkData,
  ];

  @override
  final String wireName = r'AttachmentChunkData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AttachmentChunkData object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'dataRekeyPhase';
    yield serializers.serialize(
      object.dataRekeyPhase,
      specifiedType: const FullType(AttachmentChunkDataDataRekeyPhaseEnum),
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
    yield r'chunkKeyEpoch';
    yield serializers.serialize(
      object.chunkKeyEpoch,
      specifiedType: const FullType(int),
    );
    yield r'chunkIndex';
    yield serializers.serialize(
      object.chunkIndex,
      specifiedType: const FullType(int),
    );
    yield r'ciphertext';
    yield serializers.serialize(
      object.ciphertext,
      specifiedType: const FullType(String),
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
    AttachmentChunkData object, {
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
    required AttachmentChunkDataBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'dataRekeyPhase':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      AttachmentChunkDataDataRekeyPhaseEnum,
                    ),
                  )
                  as AttachmentChunkDataDataRekeyPhaseEnum;
          result.dataRekeyPhase = valueDes;
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
        case r'chunkKeyEpoch':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.chunkKeyEpoch = valueDes;
          break;
        case r'chunkIndex':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.chunkIndex = valueDes;
          break;
        case r'ciphertext':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.ciphertext = valueDes;
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
  AttachmentChunkData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = AttachmentChunkDataBuilder();
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

class AttachmentChunkDataDataRekeyPhaseEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'ready')
  static const AttachmentChunkDataDataRekeyPhaseEnum ready =
      _$attachmentChunkDataDataRekeyPhaseEnum_ready;
  @BuiltValueEnumConst(wireName: r'rekey-pending')
  static const AttachmentChunkDataDataRekeyPhaseEnum rekeyPending =
      _$attachmentChunkDataDataRekeyPhaseEnum_rekeyPending;

  static Serializer<AttachmentChunkDataDataRekeyPhaseEnum> get serializer =>
      _$attachmentChunkDataDataRekeyPhaseEnumSerializer;

  const AttachmentChunkDataDataRekeyPhaseEnum._(String name) : super(name);

  static BuiltSet<AttachmentChunkDataDataRekeyPhaseEnum> get values =>
      _$attachmentChunkDataDataRekeyPhaseEnumValues;
  static AttachmentChunkDataDataRekeyPhaseEnum valueOf(String name) =>
      _$attachmentChunkDataDataRekeyPhaseEnumValueOf(name);
}
