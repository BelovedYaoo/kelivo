//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'attachment_deleted_data.g.dart';

/// AttachmentDeletedData
///
/// Properties:
/// * [attachmentId]
/// * [uploadId]
/// * [chunkKeyEpoch]
/// * [manifestKeyEpoch]
/// * [manifestRevision]
/// * [status]
/// * [deletedAt]
@BuiltValue()
abstract class AttachmentDeletedData
    implements Built<AttachmentDeletedData, AttachmentDeletedDataBuilder> {
  @BuiltValueField(wireName: r'attachmentId')
  String get attachmentId;

  @BuiltValueField(wireName: r'uploadId')
  String get uploadId;

  @BuiltValueField(wireName: r'chunkKeyEpoch')
  int get chunkKeyEpoch;

  @BuiltValueField(wireName: r'manifestKeyEpoch')
  int get manifestKeyEpoch;

  @BuiltValueField(wireName: r'manifestRevision')
  int get manifestRevision;

  @BuiltValueField(wireName: r'status')
  AttachmentDeletedDataStatusEnum get status;
  // enum statusEnum {  deleted,  };

  @BuiltValueField(wireName: r'deletedAt')
  DateTime get deletedAt;

  AttachmentDeletedData._();

  factory AttachmentDeletedData([
    void updates(AttachmentDeletedDataBuilder b),
  ]) = _$AttachmentDeletedData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(AttachmentDeletedDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AttachmentDeletedData> get serializer =>
      _$AttachmentDeletedDataSerializer();
}

class _$AttachmentDeletedDataSerializer
    implements PrimitiveSerializer<AttachmentDeletedData> {
  @override
  final Iterable<Type> types = const [
    AttachmentDeletedData,
    _$AttachmentDeletedData,
  ];

  @override
  final String wireName = r'AttachmentDeletedData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AttachmentDeletedData object, {
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
    yield r'chunkKeyEpoch';
    yield serializers.serialize(
      object.chunkKeyEpoch,
      specifiedType: const FullType(int),
    );
    yield r'manifestKeyEpoch';
    yield serializers.serialize(
      object.manifestKeyEpoch,
      specifiedType: const FullType(int),
    );
    yield r'manifestRevision';
    yield serializers.serialize(
      object.manifestRevision,
      specifiedType: const FullType(int),
    );
    yield r'status';
    yield serializers.serialize(
      object.status,
      specifiedType: const FullType(AttachmentDeletedDataStatusEnum),
    );
    yield r'deletedAt';
    yield serializers.serialize(
      object.deletedAt,
      specifiedType: const FullType(DateTime),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    AttachmentDeletedData object, {
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
    required AttachmentDeletedDataBuilder result,
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
        case r'chunkKeyEpoch':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.chunkKeyEpoch = valueDes;
          break;
        case r'manifestKeyEpoch':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.manifestKeyEpoch = valueDes;
          break;
        case r'manifestRevision':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.manifestRevision = valueDes;
          break;
        case r'status':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      AttachmentDeletedDataStatusEnum,
                    ),
                  )
                  as AttachmentDeletedDataStatusEnum;
          result.status = valueDes;
          break;
        case r'deletedAt':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(DateTime),
                  )
                  as DateTime;
          result.deletedAt = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  AttachmentDeletedData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = AttachmentDeletedDataBuilder();
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

class AttachmentDeletedDataStatusEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'deleted')
  static const AttachmentDeletedDataStatusEnum deleted =
      _$attachmentDeletedDataStatusEnum_deleted;

  static Serializer<AttachmentDeletedDataStatusEnum> get serializer =>
      _$attachmentDeletedDataStatusEnumSerializer;

  const AttachmentDeletedDataStatusEnum._(String name) : super(name);

  static BuiltSet<AttachmentDeletedDataStatusEnum> get values =>
      _$attachmentDeletedDataStatusEnumValues;
  static AttachmentDeletedDataStatusEnum valueOf(String name) =>
      _$attachmentDeletedDataStatusEnumValueOf(name);
}
