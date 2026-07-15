//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'prepare_attachment_upload_data.g.dart';

/// PrepareAttachmentUploadData
///
/// Properties:
/// * [blobId]
/// * [alreadyExists]
/// * [uploadMethod]
/// * [uploadUrl]
/// * [uploadExpiresAt]
/// * [uploadHeaders]
/// * [etag]
@BuiltValue()
abstract class PrepareAttachmentUploadData
    implements
        Built<PrepareAttachmentUploadData, PrepareAttachmentUploadDataBuilder> {
  @BuiltValueField(wireName: r'blobId')
  String get blobId;

  @BuiltValueField(wireName: r'alreadyExists')
  bool get alreadyExists;

  @BuiltValueField(wireName: r'uploadMethod')
  PrepareAttachmentUploadDataUploadMethodEnum get uploadMethod;
  // enum uploadMethodEnum {  PUT,  };

  @BuiltValueField(wireName: r'uploadUrl')
  String? get uploadUrl;

  @BuiltValueField(wireName: r'uploadExpiresAt')
  DateTime? get uploadExpiresAt;

  @BuiltValueField(wireName: r'uploadHeaders')
  BuiltMap<String, String> get uploadHeaders;

  @BuiltValueField(wireName: r'etag')
  String? get etag;

  PrepareAttachmentUploadData._();

  factory PrepareAttachmentUploadData([
    void updates(PrepareAttachmentUploadDataBuilder b),
  ]) = _$PrepareAttachmentUploadData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(PrepareAttachmentUploadDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<PrepareAttachmentUploadData> get serializer =>
      _$PrepareAttachmentUploadDataSerializer();
}

class _$PrepareAttachmentUploadDataSerializer
    implements PrimitiveSerializer<PrepareAttachmentUploadData> {
  @override
  final Iterable<Type> types = const [
    PrepareAttachmentUploadData,
    _$PrepareAttachmentUploadData,
  ];

  @override
  final String wireName = r'PrepareAttachmentUploadData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    PrepareAttachmentUploadData object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'blobId';
    yield serializers.serialize(
      object.blobId,
      specifiedType: const FullType(String),
    );
    yield r'alreadyExists';
    yield serializers.serialize(
      object.alreadyExists,
      specifiedType: const FullType(bool),
    );
    yield r'uploadMethod';
    yield serializers.serialize(
      object.uploadMethod,
      specifiedType: const FullType(
        PrepareAttachmentUploadDataUploadMethodEnum,
      ),
    );
    yield r'uploadUrl';
    yield object.uploadUrl == null
        ? null
        : serializers.serialize(
            object.uploadUrl,
            specifiedType: const FullType.nullable(String),
          );
    yield r'uploadExpiresAt';
    yield object.uploadExpiresAt == null
        ? null
        : serializers.serialize(
            object.uploadExpiresAt,
            specifiedType: const FullType.nullable(DateTime),
          );
    yield r'uploadHeaders';
    yield serializers.serialize(
      object.uploadHeaders,
      specifiedType: const FullType(BuiltMap, [
        FullType(String),
        FullType(String),
      ]),
    );
    yield r'etag';
    yield object.etag == null
        ? null
        : serializers.serialize(
            object.etag,
            specifiedType: const FullType.nullable(String),
          );
  }

  @override
  Object serialize(
    Serializers serializers,
    PrepareAttachmentUploadData object, {
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
    required PrepareAttachmentUploadDataBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'blobId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.blobId = valueDes;
          break;
        case r'alreadyExists':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(bool),
                  )
                  as bool;
          result.alreadyExists = valueDes;
          break;
        case r'uploadMethod':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      PrepareAttachmentUploadDataUploadMethodEnum,
                    ),
                  )
                  as PrepareAttachmentUploadDataUploadMethodEnum;
          result.uploadMethod = valueDes;
          break;
        case r'uploadUrl':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType.nullable(String),
                  )
                  as String?;
          if (valueDes == null) continue;
          result.uploadUrl = valueDes;
          break;
        case r'uploadExpiresAt':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType.nullable(DateTime),
                  )
                  as DateTime?;
          if (valueDes == null) continue;
          result.uploadExpiresAt = valueDes;
          break;
        case r'uploadHeaders':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(BuiltMap, [
                      FullType(String),
                      FullType(String),
                    ]),
                  )
                  as BuiltMap<String, String>;
          result.uploadHeaders.replace(valueDes);
          break;
        case r'etag':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType.nullable(String),
                  )
                  as String?;
          if (valueDes == null) continue;
          result.etag = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  PrepareAttachmentUploadData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = PrepareAttachmentUploadDataBuilder();
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

class PrepareAttachmentUploadDataUploadMethodEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'PUT')
  static const PrepareAttachmentUploadDataUploadMethodEnum PUT =
      _$prepareAttachmentUploadDataUploadMethodEnum_PUT;

  static Serializer<PrepareAttachmentUploadDataUploadMethodEnum>
  get serializer => _$prepareAttachmentUploadDataUploadMethodEnumSerializer;

  const PrepareAttachmentUploadDataUploadMethodEnum._(String name)
    : super(name);

  static BuiltSet<PrepareAttachmentUploadDataUploadMethodEnum> get values =>
      _$prepareAttachmentUploadDataUploadMethodEnumValues;
  static PrepareAttachmentUploadDataUploadMethodEnum valueOf(String name) =>
      _$prepareAttachmentUploadDataUploadMethodEnumValueOf(name);
}
