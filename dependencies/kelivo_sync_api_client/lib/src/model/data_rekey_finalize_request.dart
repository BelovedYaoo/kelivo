//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/data_rekey_finalize_request_proof.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'data_rekey_finalize_request.g.dart';

/// DataRekeyFinalizeRequest
///
/// Properties:
/// * [operationId]
/// * [sourceDataGeneration]
/// * [sourceKeyEpoch]
/// * [targetKeyEpoch]
/// * [leaseToken]
/// * [leaseVersion]
/// * [mutationId]
/// * [proof]
@BuiltValue()
abstract class DataRekeyFinalizeRequest
    implements
        Built<DataRekeyFinalizeRequest, DataRekeyFinalizeRequestBuilder> {
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

  @BuiltValueField(wireName: r'proof')
  DataRekeyFinalizeRequestProof get proof;

  DataRekeyFinalizeRequest._();

  factory DataRekeyFinalizeRequest([
    void updates(DataRekeyFinalizeRequestBuilder b),
  ]) = _$DataRekeyFinalizeRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DataRekeyFinalizeRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DataRekeyFinalizeRequest> get serializer =>
      _$DataRekeyFinalizeRequestSerializer();
}

class _$DataRekeyFinalizeRequestSerializer
    implements PrimitiveSerializer<DataRekeyFinalizeRequest> {
  @override
  final Iterable<Type> types = const [
    DataRekeyFinalizeRequest,
    _$DataRekeyFinalizeRequest,
  ];

  @override
  final String wireName = r'DataRekeyFinalizeRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DataRekeyFinalizeRequest object, {
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
    yield r'proof';
    yield serializers.serialize(
      object.proof,
      specifiedType: const FullType(DataRekeyFinalizeRequestProof),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    DataRekeyFinalizeRequest object, {
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
    required DataRekeyFinalizeRequestBuilder result,
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
        case r'proof':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      DataRekeyFinalizeRequestProof,
                    ),
                  )
                  as DataRekeyFinalizeRequestProof;
          result.proof.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  DataRekeyFinalizeRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DataRekeyFinalizeRequestBuilder();
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
