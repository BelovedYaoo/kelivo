//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:kelivo_sync_api_client/src/model/data_rekey_source_attachment_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'data_rekey_source_attachment_list_data.g.dart';

/// DataRekeySourceAttachmentListData
///
/// Properties:
/// * [attachments]
/// * [nextAfterAttachmentId]
/// * [nextAfterUploadId]
/// * [hasMore]
@BuiltValue()
abstract class DataRekeySourceAttachmentListData
    implements
        Built<
          DataRekeySourceAttachmentListData,
          DataRekeySourceAttachmentListDataBuilder
        > {
  @BuiltValueField(wireName: r'attachments')
  BuiltList<DataRekeySourceAttachmentData> get attachments;

  @BuiltValueField(wireName: r'nextAfterAttachmentId')
  String? get nextAfterAttachmentId;

  @BuiltValueField(wireName: r'nextAfterUploadId')
  String? get nextAfterUploadId;

  @BuiltValueField(wireName: r'hasMore')
  bool get hasMore;

  DataRekeySourceAttachmentListData._();

  factory DataRekeySourceAttachmentListData([
    void updates(DataRekeySourceAttachmentListDataBuilder b),
  ]) = _$DataRekeySourceAttachmentListData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DataRekeySourceAttachmentListDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DataRekeySourceAttachmentListData> get serializer =>
      _$DataRekeySourceAttachmentListDataSerializer();
}

class _$DataRekeySourceAttachmentListDataSerializer
    implements PrimitiveSerializer<DataRekeySourceAttachmentListData> {
  @override
  final Iterable<Type> types = const [
    DataRekeySourceAttachmentListData,
    _$DataRekeySourceAttachmentListData,
  ];

  @override
  final String wireName = r'DataRekeySourceAttachmentListData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DataRekeySourceAttachmentListData object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'attachments';
    yield serializers.serialize(
      object.attachments,
      specifiedType: const FullType(BuiltList, [
        FullType(DataRekeySourceAttachmentData),
      ]),
    );
    yield r'nextAfterAttachmentId';
    yield object.nextAfterAttachmentId == null
        ? null
        : serializers.serialize(
            object.nextAfterAttachmentId,
            specifiedType: const FullType.nullable(String),
          );
    yield r'nextAfterUploadId';
    yield object.nextAfterUploadId == null
        ? null
        : serializers.serialize(
            object.nextAfterUploadId,
            specifiedType: const FullType.nullable(String),
          );
    yield r'hasMore';
    yield serializers.serialize(
      object.hasMore,
      specifiedType: const FullType(bool),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    DataRekeySourceAttachmentListData object, {
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
    required DataRekeySourceAttachmentListDataBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'attachments':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(BuiltList, [
                      FullType(DataRekeySourceAttachmentData),
                    ]),
                  )
                  as BuiltList<DataRekeySourceAttachmentData>;
          result.attachments.replace(valueDes);
          break;
        case r'nextAfterAttachmentId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType.nullable(String),
                  )
                  as String?;
          if (valueDes == null) continue;
          result.nextAfterAttachmentId = valueDes;
          break;
        case r'nextAfterUploadId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType.nullable(String),
                  )
                  as String?;
          if (valueDes == null) continue;
          result.nextAfterUploadId = valueDes;
          break;
        case r'hasMore':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(bool),
                  )
                  as bool;
          result.hasMore = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  DataRekeySourceAttachmentListData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DataRekeySourceAttachmentListDataBuilder();
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
