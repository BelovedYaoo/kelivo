//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:kelivo_sync_api_client/src/model/data_rekey_completion_proof_data_source_attachment_cursor_end.dart';
import 'package:kelivo_sync_api_client/src/model/data_rekey_completion_proof_data.dart';
import 'package:kelivo_sync_api_client/src/model/data_rekey_pending_lease_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'data_rekey_pending_state_data.g.dart';

/// DataRekeyPendingStateData
///
/// Properties:
/// * [phase]
/// * [dataGeneration]
/// * [dataKeyEpoch]
/// * [changeWatermark]
/// * [operationId]
/// * [targetKeyEpoch]
/// * [sourceRecordCount]
/// * [sourceAttachmentCount]
/// * [sourceMaximumChangeSeq]
/// * [sourceRecordCursorEnd]
/// * [sourceAttachmentCursorEnd]
/// * [lease]
/// * [lastCompletion]
/// * [updatedAt]
@BuiltValue()
abstract class DataRekeyPendingStateData
    implements
        Built<DataRekeyPendingStateData, DataRekeyPendingStateDataBuilder> {
  @BuiltValueField(wireName: r'phase')
  DataRekeyPendingStateDataPhaseEnum get phase;
  // enum phaseEnum {  rekey-pending,  };

  @BuiltValueField(wireName: r'dataGeneration')
  int get dataGeneration;

  @BuiltValueField(wireName: r'dataKeyEpoch')
  int get dataKeyEpoch;

  @BuiltValueField(wireName: r'changeWatermark')
  int get changeWatermark;

  @BuiltValueField(wireName: r'operationId')
  String get operationId;

  @BuiltValueField(wireName: r'targetKeyEpoch')
  int get targetKeyEpoch;

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

  @BuiltValueField(wireName: r'lease')
  DataRekeyPendingLeaseData? get lease;

  @BuiltValueField(wireName: r'lastCompletion')
  DataRekeyCompletionProofData? get lastCompletion;

  @BuiltValueField(wireName: r'updatedAt')
  DateTime get updatedAt;

  DataRekeyPendingStateData._();

  factory DataRekeyPendingStateData([
    void updates(DataRekeyPendingStateDataBuilder b),
  ]) = _$DataRekeyPendingStateData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DataRekeyPendingStateDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DataRekeyPendingStateData> get serializer =>
      _$DataRekeyPendingStateDataSerializer();
}

class _$DataRekeyPendingStateDataSerializer
    implements PrimitiveSerializer<DataRekeyPendingStateData> {
  @override
  final Iterable<Type> types = const [
    DataRekeyPendingStateData,
    _$DataRekeyPendingStateData,
  ];

  @override
  final String wireName = r'DataRekeyPendingStateData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DataRekeyPendingStateData object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'phase';
    yield serializers.serialize(
      object.phase,
      specifiedType: const FullType(DataRekeyPendingStateDataPhaseEnum),
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
    yield r'operationId';
    yield serializers.serialize(
      object.operationId,
      specifiedType: const FullType(String),
    );
    yield r'targetKeyEpoch';
    yield serializers.serialize(
      object.targetKeyEpoch,
      specifiedType: const FullType(int),
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
    yield r'lease';
    yield object.lease == null
        ? null
        : serializers.serialize(
            object.lease,
            specifiedType: const FullType.nullable(DataRekeyPendingLeaseData),
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
    DataRekeyPendingStateData object, {
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
    required DataRekeyPendingStateDataBuilder result,
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
                      DataRekeyPendingStateDataPhaseEnum,
                    ),
                  )
                  as DataRekeyPendingStateDataPhaseEnum;
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
        case r'operationId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.operationId = valueDes;
          break;
        case r'targetKeyEpoch':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.targetKeyEpoch = valueDes;
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
        case r'lease':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType.nullable(
                      DataRekeyPendingLeaseData,
                    ),
                  )
                  as DataRekeyPendingLeaseData?;
          if (valueDes == null) continue;
          result.lease.replace(valueDes);
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
  DataRekeyPendingStateData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DataRekeyPendingStateDataBuilder();
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

class DataRekeyPendingStateDataPhaseEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'rekey-pending')
  static const DataRekeyPendingStateDataPhaseEnum rekeyPending =
      _$dataRekeyPendingStateDataPhaseEnum_rekeyPending;

  static Serializer<DataRekeyPendingStateDataPhaseEnum> get serializer =>
      _$dataRekeyPendingStateDataPhaseEnumSerializer;

  const DataRekeyPendingStateDataPhaseEnum._(String name) : super(name);

  static BuiltSet<DataRekeyPendingStateDataPhaseEnum> get values =>
      _$dataRekeyPendingStateDataPhaseEnumValues;
  static DataRekeyPendingStateDataPhaseEnum valueOf(String name) =>
      _$dataRekeyPendingStateDataPhaseEnumValueOf(name);
}
