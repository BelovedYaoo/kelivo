//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:kelivo_sync_api_client/src/model/data_rekey_completion_proof_data_source_attachment_cursor_end.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'data_rekey_lease_claim_data.g.dart';

/// DataRekeyLeaseClaimData
///
/// Properties:
/// * [phase]
/// * [operationId]
/// * [sourceDataGeneration]
/// * [sourceKeyEpoch]
/// * [targetKeyEpoch]
/// * [leaseVersion]
/// * [leaseExpiresAt]
/// * [sourceRecordCount]
/// * [sourceAttachmentCount]
/// * [sourceMaximumChangeSeq]
/// * [sourceRecordCursorEnd]
/// * [sourceAttachmentCursorEnd]
@BuiltValue()
abstract class DataRekeyLeaseClaimData
    implements Built<DataRekeyLeaseClaimData, DataRekeyLeaseClaimDataBuilder> {
  @BuiltValueField(wireName: r'phase')
  DataRekeyLeaseClaimDataPhaseEnum get phase;
  // enum phaseEnum {  rekey-pending,  };

  @BuiltValueField(wireName: r'operationId')
  String get operationId;

  @BuiltValueField(wireName: r'sourceDataGeneration')
  int get sourceDataGeneration;

  @BuiltValueField(wireName: r'sourceKeyEpoch')
  int get sourceKeyEpoch;

  @BuiltValueField(wireName: r'targetKeyEpoch')
  int get targetKeyEpoch;

  @BuiltValueField(wireName: r'leaseVersion')
  int get leaseVersion;

  @BuiltValueField(wireName: r'leaseExpiresAt')
  DateTime get leaseExpiresAt;

  @BuiltValueField(wireName: r'sourceRecordCount')
  int get sourceRecordCount;

  @BuiltValueField(wireName: r'sourceAttachmentCount')
  int get sourceAttachmentCount;

  @BuiltValueField(wireName: r'sourceMaximumChangeSeq')
  int get sourceMaximumChangeSeq;

  @BuiltValueField(wireName: r'sourceRecordCursorEnd')
  String? get sourceRecordCursorEnd;

  @BuiltValueField(wireName: r'sourceAttachmentCursorEnd')
  DataRekeyCompletionProofDataSourceAttachmentCursorEnd?
  get sourceAttachmentCursorEnd;

  DataRekeyLeaseClaimData._();

  factory DataRekeyLeaseClaimData([
    void updates(DataRekeyLeaseClaimDataBuilder b),
  ]) = _$DataRekeyLeaseClaimData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DataRekeyLeaseClaimDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DataRekeyLeaseClaimData> get serializer =>
      _$DataRekeyLeaseClaimDataSerializer();
}

class _$DataRekeyLeaseClaimDataSerializer
    implements PrimitiveSerializer<DataRekeyLeaseClaimData> {
  @override
  final Iterable<Type> types = const [
    DataRekeyLeaseClaimData,
    _$DataRekeyLeaseClaimData,
  ];

  @override
  final String wireName = r'DataRekeyLeaseClaimData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DataRekeyLeaseClaimData object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'phase';
    yield serializers.serialize(
      object.phase,
      specifiedType: const FullType(DataRekeyLeaseClaimDataPhaseEnum),
    );
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
    yield r'sourceKeyEpoch';
    yield serializers.serialize(
      object.sourceKeyEpoch,
      specifiedType: const FullType(int),
    );
    yield r'targetKeyEpoch';
    yield serializers.serialize(
      object.targetKeyEpoch,
      specifiedType: const FullType(int),
    );
    yield r'leaseVersion';
    yield serializers.serialize(
      object.leaseVersion,
      specifiedType: const FullType(int),
    );
    yield r'leaseExpiresAt';
    yield serializers.serialize(
      object.leaseExpiresAt,
      specifiedType: const FullType(DateTime),
    );
    yield r'sourceRecordCount';
    yield serializers.serialize(
      object.sourceRecordCount,
      specifiedType: const FullType(int),
    );
    yield r'sourceAttachmentCount';
    yield serializers.serialize(
      object.sourceAttachmentCount,
      specifiedType: const FullType(int),
    );
    yield r'sourceMaximumChangeSeq';
    yield serializers.serialize(
      object.sourceMaximumChangeSeq,
      specifiedType: const FullType(int),
    );
    yield r'sourceRecordCursorEnd';
    yield object.sourceRecordCursorEnd == null
        ? null
        : serializers.serialize(
            object.sourceRecordCursorEnd,
            specifiedType: const FullType.nullable(String),
          );
    yield r'sourceAttachmentCursorEnd';
    yield object.sourceAttachmentCursorEnd == null
        ? null
        : serializers.serialize(
            object.sourceAttachmentCursorEnd,
            specifiedType: const FullType.nullable(
              DataRekeyCompletionProofDataSourceAttachmentCursorEnd,
            ),
          );
  }

  @override
  Object serialize(
    Serializers serializers,
    DataRekeyLeaseClaimData object, {
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
    required DataRekeyLeaseClaimDataBuilder result,
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
                      DataRekeyLeaseClaimDataPhaseEnum,
                    ),
                  )
                  as DataRekeyLeaseClaimDataPhaseEnum;
          result.phase = valueDes;
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
        case r'sourceDataGeneration':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.sourceDataGeneration = valueDes;
          break;
        case r'sourceKeyEpoch':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.sourceKeyEpoch = valueDes;
          break;
        case r'targetKeyEpoch':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.targetKeyEpoch = valueDes;
          break;
        case r'leaseVersion':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.leaseVersion = valueDes;
          break;
        case r'leaseExpiresAt':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(DateTime),
                  )
                  as DateTime;
          result.leaseExpiresAt = valueDes;
          break;
        case r'sourceRecordCount':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.sourceRecordCount = valueDes;
          break;
        case r'sourceAttachmentCount':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.sourceAttachmentCount = valueDes;
          break;
        case r'sourceMaximumChangeSeq':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.sourceMaximumChangeSeq = valueDes;
          break;
        case r'sourceRecordCursorEnd':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType.nullable(String),
                  )
                  as String?;
          if (valueDes == null) continue;
          result.sourceRecordCursorEnd = valueDes;
          break;
        case r'sourceAttachmentCursorEnd':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType.nullable(
                      DataRekeyCompletionProofDataSourceAttachmentCursorEnd,
                    ),
                  )
                  as DataRekeyCompletionProofDataSourceAttachmentCursorEnd?;
          if (valueDes == null) continue;
          result.sourceAttachmentCursorEnd.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  DataRekeyLeaseClaimData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DataRekeyLeaseClaimDataBuilder();
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

class DataRekeyLeaseClaimDataPhaseEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'rekey-pending')
  static const DataRekeyLeaseClaimDataPhaseEnum rekeyPending =
      _$dataRekeyLeaseClaimDataPhaseEnum_rekeyPending;

  static Serializer<DataRekeyLeaseClaimDataPhaseEnum> get serializer =>
      _$dataRekeyLeaseClaimDataPhaseEnumSerializer;

  const DataRekeyLeaseClaimDataPhaseEnum._(String name) : super(name);

  static BuiltSet<DataRekeyLeaseClaimDataPhaseEnum> get values =>
      _$dataRekeyLeaseClaimDataPhaseEnumValues;
  static DataRekeyLeaseClaimDataPhaseEnum valueOf(String name) =>
      _$dataRekeyLeaseClaimDataPhaseEnumValueOf(name);
}
