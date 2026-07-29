//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/data_rekey_state_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'get_data_rekey_state_response.g.dart';

/// GetDataRekeyStateResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class GetDataRekeyStateResponse
    implements
        Built<GetDataRekeyStateResponse, GetDataRekeyStateResponseBuilder> {
  @BuiltValueField(wireName: r'data')
  DataRekeyStateData get data;

  GetDataRekeyStateResponse._();

  factory GetDataRekeyStateResponse([
    void updates(GetDataRekeyStateResponseBuilder b),
  ]) = _$GetDataRekeyStateResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(GetDataRekeyStateResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<GetDataRekeyStateResponse> get serializer =>
      _$GetDataRekeyStateResponseSerializer();
}

class _$GetDataRekeyStateResponseSerializer
    implements PrimitiveSerializer<GetDataRekeyStateResponse> {
  @override
  final Iterable<Type> types = const [
    GetDataRekeyStateResponse,
    _$GetDataRekeyStateResponse,
  ];

  @override
  final String wireName = r'GetDataRekeyStateResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    GetDataRekeyStateResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(DataRekeyStateData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    GetDataRekeyStateResponse object, {
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
    required GetDataRekeyStateResponseBuilder result,
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
                    specifiedType: const FullType(DataRekeyStateData),
                  )
                  as DataRekeyStateData;
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
  GetDataRekeyStateResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = GetDataRekeyStateResponseBuilder();
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
