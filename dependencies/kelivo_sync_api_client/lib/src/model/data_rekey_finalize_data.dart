//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/data_rekey_finalized_data.dart';
import 'package:built_collection/built_collection.dart';
import 'package:kelivo_sync_api_client/src/model/data_rekey_completion_proof_data.dart';
import 'package:kelivo_sync_api_client/src/model/data_rekey_verification_pending_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:one_of/one_of.dart';

part 'data_rekey_finalize_data.g.dart';

/// DataRekeyFinalizeData
///
/// Properties:
/// * [result]
/// * [dataGeneration]
/// * [dataKeyEpoch]
/// * [changeWatermark]
/// * [completion]
/// * [operationId]
/// * [phase]
/// * [sourceRecordCount]
/// * [sourceAttachmentCount]
/// * [stagedRecordCount]
/// * [stagedAttachmentCount]
@BuiltValue()
abstract class DataRekeyFinalizeData
    implements Built<DataRekeyFinalizeData, DataRekeyFinalizeDataBuilder> {
  /// One Of [DataRekeyFinalizedData], [DataRekeyVerificationPendingData]
  OneOf get oneOf;

  static const String discriminatorFieldName = r'result';

  static const Map<String, Type> discriminatorMapping = {
    r'finalized': DataRekeyFinalizedData,
    r'verification-pending': DataRekeyVerificationPendingData,
  };

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

extension DataRekeyFinalizeDataDiscriminatorExt on DataRekeyFinalizeData {
  String? get discriminatorValue {
    if (this is DataRekeyFinalizedData) {
      return r'finalized';
    }
    if (this is DataRekeyVerificationPendingData) {
      return r'verification-pending';
    }
    return null;
  }
}

extension DataRekeyFinalizeDataBuilderDiscriminatorExt
    on DataRekeyFinalizeDataBuilder {
  String? get discriminatorValue {
    if (this is DataRekeyFinalizedDataBuilder) {
      return r'finalized';
    }
    if (this is DataRekeyVerificationPendingDataBuilder) {
      return r'verification-pending';
    }
    return null;
  }
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
  }) sync* {}

  @override
  Object serialize(
    Serializers serializers,
    DataRekeyFinalizeData object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final oneOf = object.oneOf;
    return serializers.serialize(
      oneOf.value,
      specifiedType: FullType(oneOf.valueType),
    )!;
  }

  @override
  DataRekeyFinalizeData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DataRekeyFinalizeDataBuilder();
    Object? oneOfDataSrc;
    final serializedList = (serialized as Iterable<Object?>).toList();
    final discIndex =
        serializedList.indexOf(DataRekeyFinalizeData.discriminatorFieldName) +
        1;
    final discValue =
        serializers.deserialize(
              serializedList[discIndex],
              specifiedType: FullType(String),
            )
            as String;
    oneOfDataSrc = serialized;
    final oneOfTypes = [
      DataRekeyFinalizedData,
      DataRekeyVerificationPendingData,
    ];
    Object oneOfResult;
    Type oneOfType;
    switch (discValue) {
      case r'finalized':
        oneOfResult =
            serializers.deserialize(
                  oneOfDataSrc,
                  specifiedType: FullType(DataRekeyFinalizedData),
                )
                as DataRekeyFinalizedData;
        oneOfType = DataRekeyFinalizedData;
        break;
      case r'verification-pending':
        oneOfResult =
            serializers.deserialize(
                  oneOfDataSrc,
                  specifiedType: FullType(DataRekeyVerificationPendingData),
                )
                as DataRekeyVerificationPendingData;
        oneOfType = DataRekeyVerificationPendingData;
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

class DataRekeyFinalizeDataResultEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'verification-pending')
  static const DataRekeyFinalizeDataResultEnum verificationPending =
      _$dataRekeyFinalizeDataResultEnum_verificationPending;

  static Serializer<DataRekeyFinalizeDataResultEnum> get serializer =>
      _$dataRekeyFinalizeDataResultEnumSerializer;

  const DataRekeyFinalizeDataResultEnum._(String name) : super(name);

  static BuiltSet<DataRekeyFinalizeDataResultEnum> get values =>
      _$dataRekeyFinalizeDataResultEnumValues;
  static DataRekeyFinalizeDataResultEnum valueOf(String name) =>
      _$dataRekeyFinalizeDataResultEnumValueOf(name);
}

class DataRekeyFinalizeDataPhaseEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'source-records')
  static const DataRekeyFinalizeDataPhaseEnum sourceRecords =
      _$dataRekeyFinalizeDataPhaseEnum_sourceRecords;
  @BuiltValueEnumConst(wireName: r'source-attachments')
  static const DataRekeyFinalizeDataPhaseEnum sourceAttachments =
      _$dataRekeyFinalizeDataPhaseEnum_sourceAttachments;
  @BuiltValueEnumConst(wireName: r'staged-records')
  static const DataRekeyFinalizeDataPhaseEnum stagedRecords =
      _$dataRekeyFinalizeDataPhaseEnum_stagedRecords;
  @BuiltValueEnumConst(wireName: r'staged-attachments')
  static const DataRekeyFinalizeDataPhaseEnum stagedAttachments =
      _$dataRekeyFinalizeDataPhaseEnum_stagedAttachments;
  @BuiltValueEnumConst(wireName: r'verified')
  static const DataRekeyFinalizeDataPhaseEnum verified =
      _$dataRekeyFinalizeDataPhaseEnum_verified;

  static Serializer<DataRekeyFinalizeDataPhaseEnum> get serializer =>
      _$dataRekeyFinalizeDataPhaseEnumSerializer;

  const DataRekeyFinalizeDataPhaseEnum._(String name) : super(name);

  static BuiltSet<DataRekeyFinalizeDataPhaseEnum> get values =>
      _$dataRekeyFinalizeDataPhaseEnumValues;
  static DataRekeyFinalizeDataPhaseEnum valueOf(String name) =>
      _$dataRekeyFinalizeDataPhaseEnumValueOf(name);
}
