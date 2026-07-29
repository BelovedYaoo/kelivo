//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/data_rekey_lease_claim_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'claim_data_rekey_lease_response.g.dart';

/// ClaimDataRekeyLeaseResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class ClaimDataRekeyLeaseResponse
    implements
        Built<ClaimDataRekeyLeaseResponse, ClaimDataRekeyLeaseResponseBuilder> {
  @BuiltValueField(wireName: r'data')
  DataRekeyLeaseClaimData get data;

  ClaimDataRekeyLeaseResponse._();

  factory ClaimDataRekeyLeaseResponse([
    void updates(ClaimDataRekeyLeaseResponseBuilder b),
  ]) = _$ClaimDataRekeyLeaseResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ClaimDataRekeyLeaseResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ClaimDataRekeyLeaseResponse> get serializer =>
      _$ClaimDataRekeyLeaseResponseSerializer();
}

class _$ClaimDataRekeyLeaseResponseSerializer
    implements PrimitiveSerializer<ClaimDataRekeyLeaseResponse> {
  @override
  final Iterable<Type> types = const [
    ClaimDataRekeyLeaseResponse,
    _$ClaimDataRekeyLeaseResponse,
  ];

  @override
  final String wireName = r'ClaimDataRekeyLeaseResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ClaimDataRekeyLeaseResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(DataRekeyLeaseClaimData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ClaimDataRekeyLeaseResponse object, {
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
    required ClaimDataRekeyLeaseResponseBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'data':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(DataRekeyLeaseClaimData),
                  )
                  as DataRekeyLeaseClaimData;
          result.data.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ClaimDataRekeyLeaseResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ClaimDataRekeyLeaseResponseBuilder();
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
