//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'data_rekey_completion_proof_data_source_attachment_cursor_end.g.dart';

/// DataRekeyCompletionProofDataSourceAttachmentCursorEnd
///
/// Properties:
/// * [attachmentId]
/// * [uploadId]
@BuiltValue()
abstract class DataRekeyCompletionProofDataSourceAttachmentCursorEnd
    implements
        Built<
          DataRekeyCompletionProofDataSourceAttachmentCursorEnd,
          DataRekeyCompletionProofDataSourceAttachmentCursorEndBuilder
        > {
  @BuiltValueField(wireName: r'attachmentId')
  String get attachmentId;

  @BuiltValueField(wireName: r'uploadId')
  String get uploadId;

  DataRekeyCompletionProofDataSourceAttachmentCursorEnd._();

  factory DataRekeyCompletionProofDataSourceAttachmentCursorEnd([
    void updates(
      DataRekeyCompletionProofDataSourceAttachmentCursorEndBuilder b,
    ),
  ]) = _$DataRekeyCompletionProofDataSourceAttachmentCursorEnd;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(
    DataRekeyCompletionProofDataSourceAttachmentCursorEndBuilder b,
  ) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DataRekeyCompletionProofDataSourceAttachmentCursorEnd>
  get serializer =>
      _$DataRekeyCompletionProofDataSourceAttachmentCursorEndSerializer();
}

class _$DataRekeyCompletionProofDataSourceAttachmentCursorEndSerializer
    implements
        PrimitiveSerializer<
          DataRekeyCompletionProofDataSourceAttachmentCursorEnd
        > {
  @override
  final Iterable<Type> types = const [
    DataRekeyCompletionProofDataSourceAttachmentCursorEnd,
    _$DataRekeyCompletionProofDataSourceAttachmentCursorEnd,
  ];

  @override
  final String wireName =
      r'DataRekeyCompletionProofDataSourceAttachmentCursorEnd';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DataRekeyCompletionProofDataSourceAttachmentCursorEnd object, {
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
  }

  @override
  Object serialize(
    Serializers serializers,
    DataRekeyCompletionProofDataSourceAttachmentCursorEnd object, {
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
    required DataRekeyCompletionProofDataSourceAttachmentCursorEndBuilder
    result,
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
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  DataRekeyCompletionProofDataSourceAttachmentCursorEnd deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result =
        DataRekeyCompletionProofDataSourceAttachmentCursorEndBuilder();
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
