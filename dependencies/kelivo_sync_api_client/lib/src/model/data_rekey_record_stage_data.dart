//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'data_rekey_record_stage_data.g.dart';

/// DataRekeyRecordStageData
///
/// Properties:
/// * [result]
/// * [operationId]
/// * [mutationId]
/// * [sourceRecordId]
/// * [targetRecordId]
/// * [leaseVersion]
@BuiltValue()
abstract class DataRekeyRecordStageData
    implements
        Built<DataRekeyRecordStageData, DataRekeyRecordStageDataBuilder> {
  @BuiltValueField(wireName: r'result')
  DataRekeyRecordStageDataResultEnum get result;
  // enum resultEnum {  staged,  };

  @BuiltValueField(wireName: r'operationId')
  String get operationId;

  @BuiltValueField(wireName: r'mutationId')
  String get mutationId;

  @BuiltValueField(wireName: r'sourceRecordId')
  String get sourceRecordId;

  @BuiltValueField(wireName: r'targetRecordId')
  String get targetRecordId;

  @BuiltValueField(wireName: r'leaseVersion')
  int get leaseVersion;

  DataRekeyRecordStageData._();

  factory DataRekeyRecordStageData([
    void updates(DataRekeyRecordStageDataBuilder b),
  ]) = _$DataRekeyRecordStageData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DataRekeyRecordStageDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DataRekeyRecordStageData> get serializer =>
      _$DataRekeyRecordStageDataSerializer();
}

class _$DataRekeyRecordStageDataSerializer
    implements PrimitiveSerializer<DataRekeyRecordStageData> {
  @override
  final Iterable<Type> types = const [
    DataRekeyRecordStageData,
    _$DataRekeyRecordStageData,
  ];

  @override
  final String wireName = r'DataRekeyRecordStageData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DataRekeyRecordStageData object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'result';
    yield serializers.serialize(
      object.result,
      specifiedType: const FullType(DataRekeyRecordStageDataResultEnum),
    );
    yield r'operationId';
    yield serializers.serialize(
      object.operationId,
      specifiedType: const FullType(String),
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
    yield r'leaseVersion';
    yield serializers.serialize(
      object.leaseVersion,
      specifiedType: const FullType(int),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    DataRekeyRecordStageData object, {
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
    required DataRekeyRecordStageDataBuilder result,
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
                      DataRekeyRecordStageDataResultEnum,
                    ),
                  )
                  as DataRekeyRecordStageDataResultEnum;
          result.result = valueDes;
          break;
        case r'operationId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.operationId = valueDes;
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
        case r'leaseVersion':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.leaseVersion = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  DataRekeyRecordStageData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DataRekeyRecordStageDataBuilder();
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

class DataRekeyRecordStageDataResultEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'staged')
  static const DataRekeyRecordStageDataResultEnum staged =
      _$dataRekeyRecordStageDataResultEnum_staged;

  static Serializer<DataRekeyRecordStageDataResultEnum> get serializer =>
      _$dataRekeyRecordStageDataResultEnumSerializer;

  const DataRekeyRecordStageDataResultEnum._(String name) : super(name);

  static BuiltSet<DataRekeyRecordStageDataResultEnum> get values =>
      _$dataRekeyRecordStageDataResultEnumValues;
  static DataRekeyRecordStageDataResultEnum valueOf(String name) =>
      _$dataRekeyRecordStageDataResultEnumValueOf(name);
}
