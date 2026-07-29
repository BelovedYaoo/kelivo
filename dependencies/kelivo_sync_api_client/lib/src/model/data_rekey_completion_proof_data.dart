//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'data_rekey_completion_proof_data.g.dart';

/// DataRekeyCompletionProofData
///
/// Properties:
/// * [operationId]
/// * [issuerDeviceId]
/// * [sourceDataGeneration]
/// * [targetDataGeneration]
/// * [targetKeyEpoch]
/// * [membershipManifestDigest]
/// * [stagedRecordCount]
/// * [stagedAttachmentCount]
/// * [stagedCiphertextSetDigest]
/// * [signature]
/// * [finalizedAt]
@BuiltValue()
abstract class DataRekeyCompletionProofData
    implements
        Built<
          DataRekeyCompletionProofData,
          DataRekeyCompletionProofDataBuilder
        > {
  @BuiltValueField(wireName: r'operationId')
  String get operationId;

  @BuiltValueField(wireName: r'issuerDeviceId')
  String get issuerDeviceId;

  @BuiltValueField(wireName: r'sourceDataGeneration')
  int get sourceDataGeneration;

  @BuiltValueField(wireName: r'targetDataGeneration')
  int get targetDataGeneration;

  @BuiltValueField(wireName: r'targetKeyEpoch')
  int get targetKeyEpoch;

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

  @BuiltValueField(wireName: r'finalizedAt')
  DateTime get finalizedAt;

  DataRekeyCompletionProofData._();

  factory DataRekeyCompletionProofData([
    void updates(DataRekeyCompletionProofDataBuilder b),
  ]) = _$DataRekeyCompletionProofData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DataRekeyCompletionProofDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DataRekeyCompletionProofData> get serializer =>
      _$DataRekeyCompletionProofDataSerializer();
}

class _$DataRekeyCompletionProofDataSerializer
    implements PrimitiveSerializer<DataRekeyCompletionProofData> {
  @override
  final Iterable<Type> types = const [
    DataRekeyCompletionProofData,
    _$DataRekeyCompletionProofData,
  ];

  @override
  final String wireName = r'DataRekeyCompletionProofData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DataRekeyCompletionProofData object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'operationId';
    yield serializers.serialize(
      object.operationId,
      specifiedType: const FullType(String),
    );
    yield r'issuerDeviceId';
    yield serializers.serialize(
      object.issuerDeviceId,
      specifiedType: const FullType(String),
    );
    yield r'sourceDataGeneration';
    yield serializers.serialize(
      object.sourceDataGeneration,
      specifiedType: const FullType(int),
    );
    yield r'targetDataGeneration';
    yield serializers.serialize(
      object.targetDataGeneration,
      specifiedType: const FullType(int),
    );
    yield r'targetKeyEpoch';
    yield serializers.serialize(
      object.targetKeyEpoch,
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
    yield r'finalizedAt';
    yield serializers.serialize(
      object.finalizedAt,
      specifiedType: const FullType(DateTime),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    DataRekeyCompletionProofData object, {
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
    required DataRekeyCompletionProofDataBuilder result,
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
        case r'issuerDeviceId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.issuerDeviceId = valueDes;
          break;
        case r'sourceDataGeneration':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.sourceDataGeneration = valueDes;
          break;
        case r'targetDataGeneration':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.targetDataGeneration = valueDes;
          break;
        case r'targetKeyEpoch':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.targetKeyEpoch = valueDes;
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
        case r'finalizedAt':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(DateTime),
                  )
                  as DateTime;
          result.finalizedAt = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  DataRekeyCompletionProofData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DataRekeyCompletionProofDataBuilder();
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
