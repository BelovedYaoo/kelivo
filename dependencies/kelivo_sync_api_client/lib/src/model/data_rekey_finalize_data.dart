//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:kelivo_sync_api_client/src/model/data_rekey_completion_proof_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'data_rekey_finalize_data.g.dart';

/// DataRekeyFinalizeData
///
/// Properties:
/// * [result]
/// * [dataGeneration]
/// * [dataKeyEpoch]
/// * [changeWatermark]
/// * [completion]
@BuiltValue()
abstract class DataRekeyFinalizeData
    implements Built<DataRekeyFinalizeData, DataRekeyFinalizeDataBuilder> {
  @BuiltValueField(wireName: r'result')
  DataRekeyFinalizeDataResultEnum get result;
  // enum resultEnum {  finalized,  };

  @BuiltValueField(wireName: r'dataGeneration')
  int get dataGeneration;

  @BuiltValueField(wireName: r'dataKeyEpoch')
  int get dataKeyEpoch;

  @BuiltValueField(wireName: r'changeWatermark')
  int get changeWatermark;

  @BuiltValueField(wireName: r'completion')
  DataRekeyCompletionProofData? get completion;

  DataRekeyFinalizeData._();

  factory DataRekeyFinalizeData([
    void updates(DataRekeyFinalizeDataBuilder b),
  ]) = _$DataRekeyFinalizeData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DataRekeyFinalizeDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DataRekeyFinalizeData> get serializer =>
      _$DataRekeyFinalizeDataSerializer();
}

class _$DataRekeyFinalizeDataSerializer
    implements PrimitiveSerializer<DataRekeyFinalizeData> {
  @override
  final Iterable<Type> types = const [
    DataRekeyFinalizeData,
    _$DataRekeyFinalizeData,
  ];

  @override
  final String wireName = r'DataRekeyFinalizeData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DataRekeyFinalizeData object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'result';
    yield serializers.serialize(
      object.result,
      specifiedType: const FullType(DataRekeyFinalizeDataResultEnum),
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
    yield object.completion == null
        ? null
        : serializers.serialize(
            object.completion,
            specifiedType: const FullType.nullable(
              DataRekeyCompletionProofData,
            ),
          );
  }

  @override
  Object serialize(
    Serializers serializers,
    DataRekeyFinalizeData object, {
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
    required DataRekeyFinalizeDataBuilder result,
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
                      DataRekeyFinalizeDataResultEnum,
                    ),
                  )
                  as DataRekeyFinalizeDataResultEnum;
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
                    specifiedType: const FullType.nullable(
                      DataRekeyCompletionProofData,
                    ),
                  )
                  as DataRekeyCompletionProofData?;
          if (valueDes == null) continue;
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
  DataRekeyFinalizeData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DataRekeyFinalizeDataBuilder();
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

class DataRekeyFinalizeDataResultEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'finalized')
  static const DataRekeyFinalizeDataResultEnum finalized =
      _$dataRekeyFinalizeDataResultEnum_finalized;

  static Serializer<DataRekeyFinalizeDataResultEnum> get serializer =>
      _$dataRekeyFinalizeDataResultEnumSerializer;

  const DataRekeyFinalizeDataResultEnum._(String name) : super(name);

  static BuiltSet<DataRekeyFinalizeDataResultEnum> get values =>
      _$dataRekeyFinalizeDataResultEnumValues;
  static DataRekeyFinalizeDataResultEnum valueOf(String name) =>
      _$dataRekeyFinalizeDataResultEnumValueOf(name);
}
