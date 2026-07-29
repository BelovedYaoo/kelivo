//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'attachment_upload_data.g.dart';

/// AttachmentUploadData
///
/// Properties:
/// * [attachmentId]
/// * [uploadId]
/// * [chunkKeyEpoch]
/// * [manifestKeyEpoch]
/// * [manifestRevision]
/// * [chunkCount]
/// * [totalCiphertextBytes]
/// * [status]
/// * [createdAt]
@BuiltValue()
abstract class AttachmentUploadData
    implements Built<AttachmentUploadData, AttachmentUploadDataBuilder> {
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

  @BuiltValueField(wireName: r'chunkCount')
  int get chunkCount;

  @BuiltValueField(wireName: r'totalCiphertextBytes')
  int get totalCiphertextBytes;

  @BuiltValueField(wireName: r'status')
  AttachmentUploadDataStatusEnum get status;
  // enum statusEnum {  open,  };

  @BuiltValueField(wireName: r'createdAt')
  DateTime get createdAt;

  AttachmentUploadData._();

  factory AttachmentUploadData([void updates(AttachmentUploadDataBuilder b)]) =
      _$AttachmentUploadData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(AttachmentUploadDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AttachmentUploadData> get serializer =>
      _$AttachmentUploadDataSerializer();
}

class _$AttachmentUploadDataSerializer
    implements PrimitiveSerializer<AttachmentUploadData> {
  @override
  final Iterable<Type> types = const [
    AttachmentUploadData,
    _$AttachmentUploadData,
  ];

  @override
  final String wireName = r'AttachmentUploadData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AttachmentUploadData object, {
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
    yield r'chunkCount';
    yield serializers.serialize(
      object.chunkCount,
      specifiedType: const FullType(int),
    );
    yield r'totalCiphertextBytes';
    yield serializers.serialize(
      object.totalCiphertextBytes,
      specifiedType: const FullType(int),
    );
    yield r'status';
    yield serializers.serialize(
      object.status,
      specifiedType: const FullType(AttachmentUploadDataStatusEnum),
    );
    yield r'createdAt';
    yield serializers.serialize(
      object.createdAt,
      specifiedType: const FullType(DateTime),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    AttachmentUploadData object, {
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
    required AttachmentUploadDataBuilder result,
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
        case r'chunkCount':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.chunkCount = valueDes;
          break;
        case r'totalCiphertextBytes':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.totalCiphertextBytes = valueDes;
          break;
        case r'status':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      AttachmentUploadDataStatusEnum,
                    ),
                  )
                  as AttachmentUploadDataStatusEnum;
          result.status = valueDes;
          break;
        case r'createdAt':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(DateTime),
                  )
                  as DateTime;
          result.createdAt = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  AttachmentUploadData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = AttachmentUploadDataBuilder();
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

class AttachmentUploadDataStatusEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'open')
  static const AttachmentUploadDataStatusEnum open =
      _$attachmentUploadDataStatusEnum_open;

  static Serializer<AttachmentUploadDataStatusEnum> get serializer =>
      _$attachmentUploadDataStatusEnumSerializer;

  const AttachmentUploadDataStatusEnum._(String name) : super(name);

  static BuiltSet<AttachmentUploadDataStatusEnum> get values =>
      _$attachmentUploadDataStatusEnumValues;
  static AttachmentUploadDataStatusEnum valueOf(String name) =>
      _$attachmentUploadDataStatusEnumValueOf(name);
}
