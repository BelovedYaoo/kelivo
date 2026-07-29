//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'data_rekey_record_stage_request.g.dart';

/// DataRekeyRecordStageRequest
///
/// Properties:
/// * [operationId]
/// * [sourceDataGeneration]
/// * [targetKeyEpoch]
/// * [leaseToken]
/// * [leaseVersion]
/// * [mutationId]
/// * [sourceRecordId]
/// * [targetRecordId]
/// * [sourceRevision]
/// * [envelopeVersion]
/// * [ciphertext] - 客户端生成的完整加密信封，使用无填充 Base64URL 编码，解码后最大 1 MiB
@BuiltValue()
abstract class DataRekeyRecordStageRequest
    implements
        Built<DataRekeyRecordStageRequest, DataRekeyRecordStageRequestBuilder> {
  @BuiltValueField(wireName: r'operationId')
  String get operationId;

  @BuiltValueField(wireName: r'sourceDataGeneration')
  int get sourceDataGeneration;

  @BuiltValueField(wireName: r'targetKeyEpoch')
  int get targetKeyEpoch;

  @BuiltValueField(wireName: r'leaseToken')
  String get leaseToken;

  @BuiltValueField(wireName: r'leaseVersion')
  int get leaseVersion;

  @BuiltValueField(wireName: r'mutationId')
  String get mutationId;

  @BuiltValueField(wireName: r'sourceRecordId')
  String get sourceRecordId;

  @BuiltValueField(wireName: r'targetRecordId')
  String get targetRecordId;

  @BuiltValueField(wireName: r'sourceRevision')
  int get sourceRevision;

  @BuiltValueField(wireName: r'envelopeVersion')
  int get envelopeVersion;

  /// 客户端生成的完整加密信封，使用无填充 Base64URL 编码，解码后最大 1 MiB
  @BuiltValueField(wireName: r'ciphertext')
  String get ciphertext;

  DataRekeyRecordStageRequest._();

  factory DataRekeyRecordStageRequest([
    void updates(DataRekeyRecordStageRequestBuilder b),
  ]) = _$DataRekeyRecordStageRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DataRekeyRecordStageRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DataRekeyRecordStageRequest> get serializer =>
      _$DataRekeyRecordStageRequestSerializer();
}

class _$DataRekeyRecordStageRequestSerializer
    implements PrimitiveSerializer<DataRekeyRecordStageRequest> {
  @override
  final Iterable<Type> types = const [
    DataRekeyRecordStageRequest,
    _$DataRekeyRecordStageRequest,
  ];

  @override
  final String wireName = r'DataRekeyRecordStageRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DataRekeyRecordStageRequest object, {
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
    yield r'sourceRecordId';
    yield serializers.serialize(
      object.sourceRecordId,
      specifiedType: const FullType(String),
    );
    yield r'targetRecordId';
    yield serializers.serialize(
      object.targetRecordId,
      specifiedType: const FullType(String),
    );
    yield r'sourceRevision';
    yield serializers.serialize(
      object.sourceRevision,
      specifiedType: const FullType(int),
    );
    yield r'envelopeVersion';
    yield serializers.serialize(
      object.envelopeVersion,
      specifiedType: const FullType(int),
    );
    yield r'ciphertext';
    yield serializers.serialize(
      object.ciphertext,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    DataRekeyRecordStageRequest object, {
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
    required DataRekeyRecordStageRequestBuilder result,
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
        case r'sourceRecordId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.sourceRecordId = valueDes;
          break;
        case r'targetRecordId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.targetRecordId = valueDes;
          break;
        case r'sourceRevision':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.sourceRevision = valueDes;
          break;
        case r'envelopeVersion':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.envelopeVersion = valueDes;
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
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  DataRekeyRecordStageRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DataRekeyRecordStageRequestBuilder();
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
