//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:kelivo_sync_api_client/src/model/data_rekey_completion_proof_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'data_rekey_ready_state_data.g.dart';

/// DataRekeyReadyStateData
///
/// Properties:
/// * [phase]
/// * [dataGeneration]
/// * [dataKeyEpoch]
/// * [changeWatermark]
/// * [lastCompletion]
/// * [updatedAt]
@BuiltValue()
abstract class DataRekeyReadyStateData
    implements Built<DataRekeyReadyStateData, DataRekeyReadyStateDataBuilder> {
  @BuiltValueField(wireName: r'phase')
  DataRekeyReadyStateDataPhaseEnum get phase;
  // enum phaseEnum {  ready,  };

  @BuiltValueField(wireName: r'dataGeneration')
  int get dataGeneration;

  @BuiltValueField(wireName: r'dataKeyEpoch')
  int get dataKeyEpoch;

  @BuiltValueField(wireName: r'changeWatermark')
  int get changeWatermark;

  @BuiltValueField(wireName: r'lastCompletion')
  DataRekeyCompletionProofData? get lastCompletion;

  @BuiltValueField(wireName: r'updatedAt')
  DateTime get updatedAt;

  DataRekeyReadyStateData._();

  factory DataRekeyReadyStateData([
    void updates(DataRekeyReadyStateDataBuilder b),
  ]) = _$DataRekeyReadyStateData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DataRekeyReadyStateDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DataRekeyReadyStateData> get serializer =>
      _$DataRekeyReadyStateDataSerializer();
}

class _$DataRekeyReadyStateDataSerializer
    implements PrimitiveSerializer<DataRekeyReadyStateData> {
  @override
  final Iterable<Type> types = const [
    DataRekeyReadyStateData,
    _$DataRekeyReadyStateData,
  ];

  @override
  final String wireName = r'DataRekeyReadyStateData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DataRekeyReadyStateData object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'phase';
    yield serializers.serialize(
      object.phase,
      specifiedType: const FullType(DataRekeyReadyStateDataPhaseEnum),
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
    yield r'lastCompletion';
    yield object.lastCompletion == null
        ? null
        : serializers.serialize(
            object.lastCompletion,
            specifiedType: const FullType.nullable(
              DataRekeyCompletionProofData,
            ),
          );
    yield r'updatedAt';
    yield serializers.serialize(
      object.updatedAt,
      specifiedType: const FullType(DateTime),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    DataRekeyReadyStateData object, {
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
    required DataRekeyReadyStateDataBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'phase':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      DataRekeyReadyStateDataPhaseEnum,
                    ),
                  )
                  as DataRekeyReadyStateDataPhaseEnum;
          result.phase = valueDes;
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
        case r'lastCompletion':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType.nullable(
                      DataRekeyCompletionProofData,
                    ),
                  )
                  as DataRekeyCompletionProofData?;
          if (valueDes == null) continue;
          result.lastCompletion.replace(valueDes);
          break;
        case r'updatedAt':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(DateTime),
                  )
                  as DateTime;
          result.updatedAt = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  DataRekeyReadyStateData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DataRekeyReadyStateDataBuilder();
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

class DataRekeyReadyStateDataPhaseEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'ready')
  static const DataRekeyReadyStateDataPhaseEnum ready =
      _$dataRekeyReadyStateDataPhaseEnum_ready;

  static Serializer<DataRekeyReadyStateDataPhaseEnum> get serializer =>
      _$dataRekeyReadyStateDataPhaseEnumSerializer;

  const DataRekeyReadyStateDataPhaseEnum._(String name) : super(name);

  static BuiltSet<DataRekeyReadyStateDataPhaseEnum> get values =>
      _$dataRekeyReadyStateDataPhaseEnumValues;
  static DataRekeyReadyStateDataPhaseEnum valueOf(String name) =>
      _$dataRekeyReadyStateDataPhaseEnumValueOf(name);
}
