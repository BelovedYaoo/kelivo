//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/data_rekey_finalize_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'finalize_data_rekey_response.g.dart';

/// FinalizeDataRekeyResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class FinalizeDataRekeyResponse
    implements
        Built<FinalizeDataRekeyResponse, FinalizeDataRekeyResponseBuilder> {
  @BuiltValueField(wireName: r'data')
  DataRekeyFinalizeData get data;

  FinalizeDataRekeyResponse._();

  factory FinalizeDataRekeyResponse([
    void updates(FinalizeDataRekeyResponseBuilder b),
  ]) = _$FinalizeDataRekeyResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(FinalizeDataRekeyResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<FinalizeDataRekeyResponse> get serializer =>
      _$FinalizeDataRekeyResponseSerializer();
}

class _$FinalizeDataRekeyResponseSerializer
    implements PrimitiveSerializer<FinalizeDataRekeyResponse> {
  @override
  final Iterable<Type> types = const [
    FinalizeDataRekeyResponse,
    _$FinalizeDataRekeyResponse,
  ];

  @override
  final String wireName = r'FinalizeDataRekeyResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    FinalizeDataRekeyResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(DataRekeyFinalizeData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    FinalizeDataRekeyResponse object, {
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
    required FinalizeDataRekeyResponseBuilder result,
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
                    specifiedType: const FullType(DataRekeyFinalizeData),
                  )
                  as DataRekeyFinalizeData;
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
  FinalizeDataRekeyResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = FinalizeDataRekeyResponseBuilder();
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
