//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:kelivo_sync_api_client/src/model/data_rekey_completion_proof_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'data_rekey_finalized_data.g.dart';

/// DataRekeyFinalizedData
///
/// Properties:
/// * [result]
/// * [dataGeneration]
/// * [dataKeyEpoch]
/// * [changeWatermark]
/// * [completion]
@BuiltValue()
abstract class DataRekeyFinalizedData
    implements Built<DataRekeyFinalizedData, DataRekeyFinalizedDataBuilder> {
  @BuiltValueField(wireName: r'result')
  DataRekeyFinalizedDataResultEnum get result;
  // enum resultEnum {  finalized,  };

  @BuiltValueField(wireName: r'dataGeneration')
  int get dataGeneration;

  @BuiltValueField(wireName: r'dataKeyEpoch')
  int get dataKeyEpoch;

  @BuiltValueField(wireName: r'changeWatermark')
  int get changeWatermark;

  @BuiltValueField(wireName: r'completion')
  DataRekeyCompletionProofData get completion;

  DataRekeyFinalizedData._();

  factory DataRekeyFinalizedData([
    void updates(DataRekeyFinalizedDataBuilder b),
  ]) = _$DataRekeyFinalizedData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DataRekeyFinalizedDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DataRekeyFinalizedData> get serializer =>
      _$DataRekeyFinalizedDataSerializer();
}

class _$DataRekeyFinalizedDataSerializer
    implements PrimitiveSerializer<DataRekeyFinalizedData> {
  @override
  final Iterable<Type> types = const [
    DataRekeyFinalizedData,
    _$DataRekeyFinalizedData,
  ];

  @override
  final String wireName = r'DataRekeyFinalizedData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DataRekeyFinalizedData object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'result';
    yield serializers.serialize(
      object.result,
      specifiedType: const FullType(DataRekeyFinalizedDataResultEnum),
    );
    yield r'dataGeneration';
    yield serializers.serialize(
      object.dataGeneration,
      specifiedType: const FullType(int),
    );
    yield r'dataKeyEpoch';
    yield serializers.serialize(
      object.dataKeyEpoch,
      specifiedType: const FullType(int),
    );
    yield r'changeWatermark';
    yield serializers.serialize(
      object.changeWatermark,
      specifiedType: const FullType(int),
    );
    yield r'completion';
    yield serializers.serialize(
      object.completion,
      specifiedType: const FullType(DataRekeyCompletionProofData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    DataRekeyFinalizedData object, {
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
    required DataRekeyFinalizedDataBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'result':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      DataRekeyFinalizedDataResultEnum,
                    ),
                  )
                  as DataRekeyFinalizedDataResultEnum;
          result.result = valueDes;
          break;
        case r'dataGeneration':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.dataGeneration = valueDes;
          break;
        case r'dataKeyEpoch':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.dataKeyEpoch = valueDes;
          break;
        case r'changeWatermark':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.changeWatermark = valueDes;
          break;
        case r'completion':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(DataRekeyCompletionProofData),
                  )
                  as DataRekeyCompletionProofData;
          result.completion.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  DataRekeyFinalizedData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DataRekeyFinalizedDataBuilder();
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

class DataRekeyFinalizedDataResultEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'finalized')
  static const DataRekeyFinalizedDataResultEnum finalized =
      _$dataRekeyFinalizedDataResultEnum_finalized;

  static Serializer<DataRekeyFinalizedDataResultEnum> get serializer =>
      _$dataRekeyFinalizedDataResultEnumSerializer;

  const DataRekeyFinalizedDataResultEnum._(String name) : super(name);

  static BuiltSet<DataRekeyFinalizedDataResultEnum> get values =>
      _$dataRekeyFinalizedDataResultEnumValues;
  static DataRekeyFinalizedDataResultEnum valueOf(String name) =>
      _$dataRekeyFinalizedDataResultEnumValueOf(name);
}
