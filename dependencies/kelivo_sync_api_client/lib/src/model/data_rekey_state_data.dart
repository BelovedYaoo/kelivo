//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/data_rekey_ready_state_data.dart';
import 'package:built_collection/built_collection.dart';
import 'package:kelivo_sync_api_client/src/model/data_rekey_pending_state_data.dart';
import 'package:kelivo_sync_api_client/src/model/data_rekey_completion_proof_data.dart';
import 'package:kelivo_sync_api_client/src/model/data_rekey_pending_lease_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:one_of/one_of.dart';

part 'data_rekey_state_data.g.dart';

/// DataRekeyStateData
///
/// Properties:
/// * [phase]
/// * [dataGeneration]
/// * [dataKeyEpoch]
/// * [changeWatermark]
/// * [lastCompletion]
/// * [updatedAt]
/// * [operationId]
/// * [targetKeyEpoch]
/// * [sourceRecordCount]
/// * [sourceAttachmentCount]
/// * [sourceMaximumChangeSeq]
/// * [lease]
@BuiltValue()
abstract class DataRekeyStateData
    implements Built<DataRekeyStateData, DataRekeyStateDataBuilder> {
  /// One Of [DataRekeyPendingStateData], [DataRekeyReadyStateData]
  OneOf get oneOf;

  static const String discriminatorFieldName = r'phase';

  static const Map<String, Type> discriminatorMapping = {
    r'ready': DataRekeyReadyStateData,
    r'rekey-pending': DataRekeyPendingStateData,
  };

  DataRekeyStateData._();

  factory DataRekeyStateData([void updates(DataRekeyStateDataBuilder b)]) =
      _$DataRekeyStateData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DataRekeyStateDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DataRekeyStateData> get serializer =>
      _$DataRekeyStateDataSerializer();
}

extension DataRekeyStateDataDiscriminatorExt on DataRekeyStateData {
  String? get discriminatorValue {
    if (this is DataRekeyReadyStateData) {
      return r'ready';
    }
    if (this is DataRekeyPendingStateData) {
      return r'rekey-pending';
    }
    return null;
  }
}

extension DataRekeyStateDataBuilderDiscriminatorExt
    on DataRekeyStateDataBuilder {
  String? get discriminatorValue {
    if (this is DataRekeyReadyStateDataBuilder) {
      return r'ready';
    }
    if (this is DataRekeyPendingStateDataBuilder) {
      return r'rekey-pending';
    }
    return null;
  }
}

class _$DataRekeyStateDataSerializer
    implements PrimitiveSerializer<DataRekeyStateData> {
  @override
  final Iterable<Type> types = const [DataRekeyStateData, _$DataRekeyStateData];

  @override
  final String wireName = r'DataRekeyStateData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DataRekeyStateData object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {}

  @override
  Object serialize(
    Serializers serializers,
    DataRekeyStateData object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final oneOf = object.oneOf;
    return serializers.serialize(
      oneOf.value,
      specifiedType: FullType(oneOf.valueType),
    )!;
  }

  @override
  DataRekeyStateData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DataRekeyStateDataBuilder();
    Object? oneOfDataSrc;
    final serializedList = (serialized as Iterable<Object?>).toList();
    final discIndex =
        serializedList.indexOf(DataRekeyStateData.discriminatorFieldName) + 1;
    final discValue =
        serializers.deserialize(
              serializedList[discIndex],
              specifiedType: FullType(String),
            )
            as String;
    oneOfDataSrc = serialized;
    final oneOfTypes = [DataRekeyReadyStateData, DataRekeyPendingStateData];
    Object oneOfResult;
    Type oneOfType;
    switch (discValue) {
      case r'ready':
        oneOfResult =
            serializers.deserialize(
                  oneOfDataSrc,
                  specifiedType: FullType(DataRekeyReadyStateData),
                )
                as DataRekeyReadyStateData;
        oneOfType = DataRekeyReadyStateData;
        break;
      case r'rekey-pending':
        oneOfResult =
            serializers.deserialize(
                  oneOfDataSrc,
                  specifiedType: FullType(DataRekeyPendingStateData),
                )
                as DataRekeyPendingStateData;
        oneOfType = DataRekeyPendingStateData;
        break;
      default:
        throw UnsupportedError(
          "Couldn't deserialize oneOf for the discriminator value: ${discValue}",
        );
    }
    result.oneOf = OneOfDynamic(
      typeIndex: oneOfTypes.indexOf(oneOfType),
      types: oneOfTypes,
      value: oneOfResult,
    );
    return result.build();
  }
}

class DataRekeyStateDataPhaseEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'rekey-pending')
  static const DataRekeyStateDataPhaseEnum rekeyPending =
      _$dataRekeyStateDataPhaseEnum_rekeyPending;

  static Serializer<DataRekeyStateDataPhaseEnum> get serializer =>
      _$dataRekeyStateDataPhaseEnumSerializer;

  const DataRekeyStateDataPhaseEnum._(String name) : super(name);

  static BuiltSet<DataRekeyStateDataPhaseEnum> get values =>
      _$dataRekeyStateDataPhaseEnumValues;
  static DataRekeyStateDataPhaseEnum valueOf(String name) =>
      _$dataRekeyStateDataPhaseEnumValueOf(name);
}
