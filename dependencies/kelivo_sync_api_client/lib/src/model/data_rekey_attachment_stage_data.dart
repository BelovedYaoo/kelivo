//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'data_rekey_attachment_stage_data.g.dart';

/// DataRekeyAttachmentStageData
///
/// Properties:
/// * [result]
/// * [operationId]
/// * [mutationId]
/// * [attachmentId]
/// * [uploadId]
/// * [manifestRevision]
/// * [leaseVersion]
@BuiltValue()
abstract class DataRekeyAttachmentStageData
    implements
        Built<
          DataRekeyAttachmentStageData,
          DataRekeyAttachmentStageDataBuilder
        > {
  @BuiltValueField(wireName: r'result')
  DataRekeyAttachmentStageDataResultEnum get result;
  // enum resultEnum {  staged,  };

  @BuiltValueField(wireName: r'operationId')
  String get operationId;

  @BuiltValueField(wireName: r'mutationId')
  String get mutationId;

  @BuiltValueField(wireName: r'attachmentId')
  String get attachmentId;

  @BuiltValueField(wireName: r'uploadId')
  String get uploadId;

  @BuiltValueField(wireName: r'manifestRevision')
  int get manifestRevision;

  @BuiltValueField(wireName: r'leaseVersion')
  int get leaseVersion;

  DataRekeyAttachmentStageData._();

  factory DataRekeyAttachmentStageData([
    void updates(DataRekeyAttachmentStageDataBuilder b),
  ]) = _$DataRekeyAttachmentStageData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DataRekeyAttachmentStageDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DataRekeyAttachmentStageData> get serializer =>
      _$DataRekeyAttachmentStageDataSerializer();
}

class _$DataRekeyAttachmentStageDataSerializer
    implements PrimitiveSerializer<DataRekeyAttachmentStageData> {
  @override
  final Iterable<Type> types = const [
    DataRekeyAttachmentStageData,
    _$DataRekeyAttachmentStageData,
  ];

  @override
  final String wireName = r'DataRekeyAttachmentStageData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DataRekeyAttachmentStageData object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'result';
    yield serializers.serialize(
      object.result,
      specifiedType: const FullType(DataRekeyAttachmentStageDataResultEnum),
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
    yield r'attachmentId';
    yield serializers.serialize(
      object.attachmentId,
      specifiedType: const FullType(String),
    );
    yield r'uploadId';
    yield serializers.serialize(
      object.uploadId,
      specifiedType: const FullType(String),
    );
    yield r'manifestRevision';
    yield serializers.serialize(
      object.manifestRevision,
      specifiedType: const FullType(int),
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
    DataRekeyAttachmentStageData object, {
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
    required DataRekeyAttachmentStageDataBuilder result,
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
                      DataRekeyAttachmentStageDataResultEnum,
                    ),
                  )
                  as DataRekeyAttachmentStageDataResultEnum;
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
        case r'attachmentId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.attachmentId = valueDes;
          break;
        case r'uploadId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.uploadId = valueDes;
          break;
        case r'manifestRevision':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.manifestRevision = valueDes;
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
  DataRekeyAttachmentStageData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DataRekeyAttachmentStageDataBuilder();
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

class DataRekeyAttachmentStageDataResultEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'staged')
  static const DataRekeyAttachmentStageDataResultEnum staged =
      _$dataRekeyAttachmentStageDataResultEnum_staged;

  static Serializer<DataRekeyAttachmentStageDataResultEnum> get serializer =>
      _$dataRekeyAttachmentStageDataResultEnumSerializer;

  const DataRekeyAttachmentStageDataResultEnum._(String name) : super(name);

  static BuiltSet<DataRekeyAttachmentStageDataResultEnum> get values =>
      _$dataRekeyAttachmentStageDataResultEnumValues;
  static DataRekeyAttachmentStageDataResultEnum valueOf(String name) =>
      _$dataRekeyAttachmentStageDataResultEnumValueOf(name);
}
