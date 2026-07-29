//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'data_rekey_attachment_stage_request.g.dart';

/// DataRekeyAttachmentStageRequest
///
/// Properties:
/// * [operationId]
/// * [sourceDataGeneration]
/// * [sourceKeyEpoch]
/// * [targetKeyEpoch]
/// * [leaseToken]
/// * [leaseVersion]
/// * [mutationId]
/// * [attachmentId]
/// * [uploadId]
/// * [sourceManifestRevision]
/// * [manifestKeyEpoch]
/// * [manifestRevision]
/// * [manifestCiphertext] - 客户端认证的附件清单密文，使用规范无填充 Base64URL 编码，解码后最大 1 MiB
@BuiltValue()
abstract class DataRekeyAttachmentStageRequest
    implements
        Built<
          DataRekeyAttachmentStageRequest,
          DataRekeyAttachmentStageRequestBuilder
        > {
  @BuiltValueField(wireName: r'operationId')
  String get operationId;

  @BuiltValueField(wireName: r'sourceDataGeneration')
  int get sourceDataGeneration;

  @BuiltValueField(wireName: r'sourceKeyEpoch')
  int get sourceKeyEpoch;

  @BuiltValueField(wireName: r'targetKeyEpoch')
  int get targetKeyEpoch;

  @BuiltValueField(wireName: r'leaseToken')
  String get leaseToken;

  @BuiltValueField(wireName: r'leaseVersion')
  int get leaseVersion;

  @BuiltValueField(wireName: r'mutationId')
  String get mutationId;

  @BuiltValueField(wireName: r'attachmentId')
  String get attachmentId;

  @BuiltValueField(wireName: r'uploadId')
  String get uploadId;

  @BuiltValueField(wireName: r'sourceManifestRevision')
  int get sourceManifestRevision;

  @BuiltValueField(wireName: r'manifestKeyEpoch')
  int get manifestKeyEpoch;

  @BuiltValueField(wireName: r'manifestRevision')
  int get manifestRevision;

  /// 客户端认证的附件清单密文，使用规范无填充 Base64URL 编码，解码后最大 1 MiB
  @BuiltValueField(wireName: r'manifestCiphertext')
  String get manifestCiphertext;

  DataRekeyAttachmentStageRequest._();

  factory DataRekeyAttachmentStageRequest([
    void updates(DataRekeyAttachmentStageRequestBuilder b),
  ]) = _$DataRekeyAttachmentStageRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DataRekeyAttachmentStageRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DataRekeyAttachmentStageRequest> get serializer =>
      _$DataRekeyAttachmentStageRequestSerializer();
}

class _$DataRekeyAttachmentStageRequestSerializer
    implements PrimitiveSerializer<DataRekeyAttachmentStageRequest> {
  @override
  final Iterable<Type> types = const [
    DataRekeyAttachmentStageRequest,
    _$DataRekeyAttachmentStageRequest,
  ];

  @override
  final String wireName = r'DataRekeyAttachmentStageRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DataRekeyAttachmentStageRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'operationId';
    yield serializers.serialize(
      object.operationId,
      specifiedType: const FullType(String),
    );
    yield r'sourceDataGeneration';
    yield serializers.serialize(
      object.sourceDataGeneration,
      specifiedType: const FullType(int),
    );
    yield r'sourceKeyEpoch';
    yield serializers.serialize(
      object.sourceKeyEpoch,
      specifiedType: const FullType(int),
    );
    yield r'targetKeyEpoch';
    yield serializers.serialize(
      object.targetKeyEpoch,
      specifiedType: const FullType(int),
    );
    yield r'leaseToken';
    yield serializers.serialize(
      object.leaseToken,
      specifiedType: const FullType(String),
    );
    yield r'leaseVersion';
    yield serializers.serialize(
      object.leaseVersion,
      specifiedType: const FullType(int),
    );
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
    yield r'sourceManifestRevision';
    yield serializers.serialize(
      object.sourceManifestRevision,
      specifiedType: const FullType(int),
    );
    yield r'manifestKeyEpoch';
    yield serializers.serialize(
      object.manifestKeyEpoch,
      specifiedType: const FullType(int),
    );
    yield r'manifestRevision';
    yield serializers.serialize(
      object.manifestRevision,
      specifiedType: const FullType(int),
    );
    yield r'manifestCiphertext';
    yield serializers.serialize(
      object.manifestCiphertext,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    DataRekeyAttachmentStageRequest object, {
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
    required DataRekeyAttachmentStageRequestBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'operationId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.operationId = valueDes;
          break;
        case r'sourceDataGeneration':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.sourceDataGeneration = valueDes;
          break;
        case r'sourceKeyEpoch':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.sourceKeyEpoch = valueDes;
          break;
        case r'targetKeyEpoch':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.targetKeyEpoch = valueDes;
          break;
        case r'leaseToken':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.leaseToken = valueDes;
          break;
        case r'leaseVersion':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.leaseVersion = valueDes;
          break;
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
        case r'sourceManifestRevision':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.sourceManifestRevision = valueDes;
          break;
        case r'manifestKeyEpoch':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.manifestKeyEpoch = valueDes;
          break;
        case r'manifestRevision':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.manifestRevision = valueDes;
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
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  DataRekeyAttachmentStageRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DataRekeyAttachmentStageRequestBuilder();
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
