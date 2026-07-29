//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'data_rekey_lease_claim_request.g.dart';

/// DataRekeyLeaseClaimRequest
///
/// Properties:
/// * [operationId]
/// * [sourceDataGeneration]
/// * [targetKeyEpoch]
/// * [leaseToken]
/// * [mutationId]
@BuiltValue()
abstract class DataRekeyLeaseClaimRequest
    implements
        Built<DataRekeyLeaseClaimRequest, DataRekeyLeaseClaimRequestBuilder> {
  @BuiltValueField(wireName: r'operationId')
  String get operationId;

  @BuiltValueField(wireName: r'sourceDataGeneration')
  int get sourceDataGeneration;

  @BuiltValueField(wireName: r'targetKeyEpoch')
  int get targetKeyEpoch;

  @BuiltValueField(wireName: r'leaseToken')
  String get leaseToken;

  @BuiltValueField(wireName: r'mutationId')
  String get mutationId;

  DataRekeyLeaseClaimRequest._();

  factory DataRekeyLeaseClaimRequest([
    void updates(DataRekeyLeaseClaimRequestBuilder b),
  ]) = _$DataRekeyLeaseClaimRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DataRekeyLeaseClaimRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DataRekeyLeaseClaimRequest> get serializer =>
      _$DataRekeyLeaseClaimRequestSerializer();
}

class _$DataRekeyLeaseClaimRequestSerializer
    implements PrimitiveSerializer<DataRekeyLeaseClaimRequest> {
  @override
  final Iterable<Type> types = const [
    DataRekeyLeaseClaimRequest,
    _$DataRekeyLeaseClaimRequest,
  ];

  @override
  final String wireName = r'DataRekeyLeaseClaimRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DataRekeyLeaseClaimRequest object, {
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
    yield r'mutationId';
    yield serializers.serialize(
      object.mutationId,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    DataRekeyLeaseClaimRequest object, {
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
    required DataRekeyLeaseClaimRequestBuilder result,
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
        case r'mutationId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.mutationId = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  DataRekeyLeaseClaimRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DataRekeyLeaseClaimRequestBuilder();
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
