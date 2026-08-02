//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'data_rekey_verification_pending_data.g.dart';

/// DataRekeyVerificationPendingData
///
/// Properties:
/// * [result]
/// * [operationId]
/// * [phase]
/// * [sourceRecordCount]
/// * [sourceAttachmentCount]
/// * [stagedRecordCount]
/// * [stagedAttachmentCount]
@BuiltValue()
abstract class DataRekeyVerificationPendingData
    implements
        Built<
          DataRekeyVerificationPendingData,
          DataRekeyVerificationPendingDataBuilder
        > {
  @BuiltValueField(wireName: r'result')
  DataRekeyVerificationPendingDataResultEnum get result;
  // enum resultEnum {  verification-pending,  };

  @BuiltValueField(wireName: r'operationId')
  String get operationId;

  @BuiltValueField(wireName: r'phase')
  DataRekeyVerificationPendingDataPhaseEnum get phase;
  // enum phaseEnum {  source-records,  source-attachments,  staged-records,  staged-attachments,  verified,  };

  @BuiltValueField(wireName: r'sourceRecordCount')
  int get sourceRecordCount;

  @BuiltValueField(wireName: r'sourceAttachmentCount')
  int get sourceAttachmentCount;

  @BuiltValueField(wireName: r'stagedRecordCount')
  int get stagedRecordCount;

  @BuiltValueField(wireName: r'stagedAttachmentCount')
  int get stagedAttachmentCount;

  DataRekeyVerificationPendingData._();

  factory DataRekeyVerificationPendingData([
    void updates(DataRekeyVerificationPendingDataBuilder b),
  ]) = _$DataRekeyVerificationPendingData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DataRekeyVerificationPendingDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DataRekeyVerificationPendingData> get serializer =>
      _$DataRekeyVerificationPendingDataSerializer();
}

class _$DataRekeyVerificationPendingDataSerializer
    implements PrimitiveSerializer<DataRekeyVerificationPendingData> {
  @override
  final Iterable<Type> types = const [
    DataRekeyVerificationPendingData,
    _$DataRekeyVerificationPendingData,
  ];

  @override
  final String wireName = r'DataRekeyVerificationPendingData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DataRekeyVerificationPendingData object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'result';
    yield serializers.serialize(
      object.result,
      specifiedType: const FullType(DataRekeyVerificationPendingDataResultEnum),
    );
    yield r'operationId';
    yield serializers.serialize(
      object.operationId,
      specifiedType: const FullType(String),
    );
    yield r'phase';
    yield serializers.serialize(
      object.phase,
      specifiedType: const FullType(DataRekeyVerificationPendingDataPhaseEnum),
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
    yield r'stagedRecordCount';
    yield serializers.serialize(
      object.stagedRecordCount,
      specifiedType: const FullType(int),
    );
    yield r'stagedAttachmentCount';
    yield serializers.serialize(
      object.stagedAttachmentCount,
      specifiedType: const FullType(int),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    DataRekeyVerificationPendingData object, {
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
    required DataRekeyVerificationPendingDataBuilder result,
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
                      DataRekeyVerificationPendingDataResultEnum,
                    ),
                  )
                  as DataRekeyVerificationPendingDataResultEnum;
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
        case r'phase':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      DataRekeyVerificationPendingDataPhaseEnum,
                    ),
                  )
                  as DataRekeyVerificationPendingDataPhaseEnum;
          result.phase = valueDes;
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
        case r'stagedRecordCount':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.stagedRecordCount = valueDes;
          break;
        case r'stagedAttachmentCount':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.stagedAttachmentCount = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  DataRekeyVerificationPendingData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DataRekeyVerificationPendingDataBuilder();
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

class DataRekeyVerificationPendingDataResultEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'verification-pending')
  static const DataRekeyVerificationPendingDataResultEnum verificationPending =
      _$dataRekeyVerificationPendingDataResultEnum_verificationPending;

  static Serializer<DataRekeyVerificationPendingDataResultEnum>
  get serializer => _$dataRekeyVerificationPendingDataResultEnumSerializer;

  const DataRekeyVerificationPendingDataResultEnum._(String name) : super(name);

  static BuiltSet<DataRekeyVerificationPendingDataResultEnum> get values =>
      _$dataRekeyVerificationPendingDataResultEnumValues;
  static DataRekeyVerificationPendingDataResultEnum valueOf(String name) =>
      _$dataRekeyVerificationPendingDataResultEnumValueOf(name);
}

class DataRekeyVerificationPendingDataPhaseEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'source-records')
  static const DataRekeyVerificationPendingDataPhaseEnum sourceRecords =
      _$dataRekeyVerificationPendingDataPhaseEnum_sourceRecords;
  @BuiltValueEnumConst(wireName: r'source-attachments')
  static const DataRekeyVerificationPendingDataPhaseEnum sourceAttachments =
      _$dataRekeyVerificationPendingDataPhaseEnum_sourceAttachments;
  @BuiltValueEnumConst(wireName: r'staged-records')
  static const DataRekeyVerificationPendingDataPhaseEnum stagedRecords =
      _$dataRekeyVerificationPendingDataPhaseEnum_stagedRecords;
  @BuiltValueEnumConst(wireName: r'staged-attachments')
  static const DataRekeyVerificationPendingDataPhaseEnum stagedAttachments =
      _$dataRekeyVerificationPendingDataPhaseEnum_stagedAttachments;
  @BuiltValueEnumConst(wireName: r'verified')
  static const DataRekeyVerificationPendingDataPhaseEnum verified =
      _$dataRekeyVerificationPendingDataPhaseEnum_verified;

  static Serializer<DataRekeyVerificationPendingDataPhaseEnum> get serializer =>
      _$dataRekeyVerificationPendingDataPhaseEnumSerializer;

  const DataRekeyVerificationPendingDataPhaseEnum._(String name) : super(name);

  static BuiltSet<DataRekeyVerificationPendingDataPhaseEnum> get values =>
      _$dataRekeyVerificationPendingDataPhaseEnumValues;
  static DataRekeyVerificationPendingDataPhaseEnum valueOf(String name) =>
      _$dataRekeyVerificationPendingDataPhaseEnumValueOf(name);
}
