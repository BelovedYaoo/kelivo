//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'data_rekey_finalize_request_proof.g.dart';

/// DataRekeyFinalizeRequestProof
///
/// Properties:
/// * [issuerDeviceId]
/// * [targetDataGeneration]
/// * [membershipManifestDigest]
/// * [stagedRecordCount]
/// * [stagedAttachmentCount]
/// * [stagedCiphertextSetDigest]
/// * [signature]
@BuiltValue()
abstract class DataRekeyFinalizeRequestProof
    implements
        Built<
          DataRekeyFinalizeRequestProof,
          DataRekeyFinalizeRequestProofBuilder
        > {
  @BuiltValueField(wireName: r'issuerDeviceId')
  String get issuerDeviceId;

  @BuiltValueField(wireName: r'targetDataGeneration')
  int get targetDataGeneration;

  @BuiltValueField(wireName: r'membershipManifestDigest')
  String get membershipManifestDigest;

  @BuiltValueField(wireName: r'stagedRecordCount')
  int get stagedRecordCount;

  @BuiltValueField(wireName: r'stagedAttachmentCount')
  int get stagedAttachmentCount;

  @BuiltValueField(wireName: r'stagedCiphertextSetDigest')
  String get stagedCiphertextSetDigest;

  @BuiltValueField(wireName: r'signature')
  String get signature;

  DataRekeyFinalizeRequestProof._();

  factory DataRekeyFinalizeRequestProof([
    void updates(DataRekeyFinalizeRequestProofBuilder b),
  ]) = _$DataRekeyFinalizeRequestProof;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DataRekeyFinalizeRequestProofBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DataRekeyFinalizeRequestProof> get serializer =>
      _$DataRekeyFinalizeRequestProofSerializer();
}

class _$DataRekeyFinalizeRequestProofSerializer
    implements PrimitiveSerializer<DataRekeyFinalizeRequestProof> {
  @override
  final Iterable<Type> types = const [
    DataRekeyFinalizeRequestProof,
    _$DataRekeyFinalizeRequestProof,
  ];

  @override
  final String wireName = r'DataRekeyFinalizeRequestProof';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DataRekeyFinalizeRequestProof object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'issuerDeviceId';
    yield serializers.serialize(
      object.issuerDeviceId,
      specifiedType: const FullType(String),
    );
    yield r'targetDataGeneration';
    yield serializers.serialize(
      object.targetDataGeneration,
      specifiedType: const FullType(int),
    );
    yield r'membershipManifestDigest';
    yield serializers.serialize(
      object.membershipManifestDigest,
      specifiedType: const FullType(String),
    );
    yield r'stagedRecordCount';
    yield serializers.serialize(
      object.stagedRecordCount,
      specifiedType: const FullType(int),
    );
    yield r'stagedAttachmentCount';
    yield serializers.serialize(
      object.stagedAttachmentCount,
      specifiedType: const FullType(int),
    );
    yield r'stagedCiphertextSetDigest';
    yield serializers.serialize(
      object.stagedCiphertextSetDigest,
      specifiedType: const FullType(String),
    );
    yield r'signature';
    yield serializers.serialize(
      object.signature,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    DataRekeyFinalizeRequestProof object, {
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
    required DataRekeyFinalizeRequestProofBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'issuerDeviceId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.issuerDeviceId = valueDes;
          break;
        case r'targetDataGeneration':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.targetDataGeneration = valueDes;
          break;
        case r'membershipManifestDigest':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.membershipManifestDigest = valueDes;
          break;
        case r'stagedRecordCount':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.stagedRecordCount = valueDes;
          break;
        case r'stagedAttachmentCount':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.stagedAttachmentCount = valueDes;
          break;
        case r'stagedCiphertextSetDigest':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.stagedCiphertextSetDigest = valueDes;
          break;
        case r'signature':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.signature = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  DataRekeyFinalizeRequestProof deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DataRekeyFinalizeRequestProofBuilder();
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
