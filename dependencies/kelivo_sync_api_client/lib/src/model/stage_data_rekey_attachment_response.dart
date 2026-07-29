//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/data_rekey_attachment_stage_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'stage_data_rekey_attachment_response.g.dart';

/// StageDataRekeyAttachmentResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class StageDataRekeyAttachmentResponse
    implements
        Built<
          StageDataRekeyAttachmentResponse,
          StageDataRekeyAttachmentResponseBuilder
        > {
  @BuiltValueField(wireName: r'data')
  DataRekeyAttachmentStageData get data;

  StageDataRekeyAttachmentResponse._();

  factory StageDataRekeyAttachmentResponse([
    void updates(StageDataRekeyAttachmentResponseBuilder b),
  ]) = _$StageDataRekeyAttachmentResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(StageDataRekeyAttachmentResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<StageDataRekeyAttachmentResponse> get serializer =>
      _$StageDataRekeyAttachmentResponseSerializer();
}

class _$StageDataRekeyAttachmentResponseSerializer
    implements PrimitiveSerializer<StageDataRekeyAttachmentResponse> {
  @override
  final Iterable<Type> types = const [
    StageDataRekeyAttachmentResponse,
    _$StageDataRekeyAttachmentResponse,
  ];

  @override
  final String wireName = r'StageDataRekeyAttachmentResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    StageDataRekeyAttachmentResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(DataRekeyAttachmentStageData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    StageDataRekeyAttachmentResponse object, {
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
    required StageDataRekeyAttachmentResponseBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'data':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(DataRekeyAttachmentStageData),
                  )
                  as DataRekeyAttachmentStageData;
          result.data.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  StageDataRekeyAttachmentResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = StageDataRekeyAttachmentResponseBuilder();
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
