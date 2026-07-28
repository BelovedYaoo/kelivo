//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'attachment_committed_data.g.dart';

/// AttachmentCommittedData
///
/// Properties:
/// * [attachmentId]
/// * [uploadId]
/// * [keyEpoch]
/// * [status]
/// * [committedAt]
@BuiltValue()
abstract class AttachmentCommittedData
    implements Built<AttachmentCommittedData, AttachmentCommittedDataBuilder> {
  @BuiltValueField(wireName: r'attachmentId')
  String get attachmentId;

  @BuiltValueField(wireName: r'uploadId')
  String get uploadId;

  @BuiltValueField(wireName: r'keyEpoch')
  int get keyEpoch;

  @BuiltValueField(wireName: r'status')
  AttachmentCommittedDataStatusEnum get status;
  // enum statusEnum {  committed,  };

  @BuiltValueField(wireName: r'committedAt')
  DateTime get committedAt;

  AttachmentCommittedData._();

  factory AttachmentCommittedData([
    void updates(AttachmentCommittedDataBuilder b),
  ]) = _$AttachmentCommittedData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(AttachmentCommittedDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AttachmentCommittedData> get serializer =>
      _$AttachmentCommittedDataSerializer();
}

class _$AttachmentCommittedDataSerializer
    implements PrimitiveSerializer<AttachmentCommittedData> {
  @override
  final Iterable<Type> types = const [
    AttachmentCommittedData,
    _$AttachmentCommittedData,
  ];

  @override
  final String wireName = r'AttachmentCommittedData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AttachmentCommittedData object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
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
    yield r'keyEpoch';
    yield serializers.serialize(
      object.keyEpoch,
      specifiedType: const FullType(int),
    );
    yield r'status';
    yield serializers.serialize(
      object.status,
      specifiedType: const FullType(AttachmentCommittedDataStatusEnum),
    );
    yield r'committedAt';
    yield serializers.serialize(
      object.committedAt,
      specifiedType: const FullType(DateTime),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    AttachmentCommittedData object, {
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
    required AttachmentCommittedDataBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
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
        case r'keyEpoch':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.keyEpoch = valueDes;
          break;
        case r'status':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      AttachmentCommittedDataStatusEnum,
                    ),
                  )
                  as AttachmentCommittedDataStatusEnum;
          result.status = valueDes;
          break;
        case r'committedAt':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(DateTime),
                  )
                  as DateTime;
          result.committedAt = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  AttachmentCommittedData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = AttachmentCommittedDataBuilder();
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

class AttachmentCommittedDataStatusEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'committed')
  static const AttachmentCommittedDataStatusEnum committed =
      _$attachmentCommittedDataStatusEnum_committed;

  static Serializer<AttachmentCommittedDataStatusEnum> get serializer =>
      _$attachmentCommittedDataStatusEnumSerializer;

  const AttachmentCommittedDataStatusEnum._(String name) : super(name);

  static BuiltSet<AttachmentCommittedDataStatusEnum> get values =>
      _$attachmentCommittedDataStatusEnumValues;
  static AttachmentCommittedDataStatusEnum valueOf(String name) =>
      _$attachmentCommittedDataStatusEnumValueOf(name);
}
