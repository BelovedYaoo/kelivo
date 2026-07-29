//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/data_rekey_record_stage_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'stage_data_rekey_record_response.g.dart';

/// StageDataRekeyRecordResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class StageDataRekeyRecordResponse
    implements
        Built<
          StageDataRekeyRecordResponse,
          StageDataRekeyRecordResponseBuilder
        > {
  @BuiltValueField(wireName: r'data')
  DataRekeyRecordStageData get data;

  StageDataRekeyRecordResponse._();

  factory StageDataRekeyRecordResponse([
    void updates(StageDataRekeyRecordResponseBuilder b),
  ]) = _$StageDataRekeyRecordResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(StageDataRekeyRecordResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<StageDataRekeyRecordResponse> get serializer =>
      _$StageDataRekeyRecordResponseSerializer();
}

class _$StageDataRekeyRecordResponseSerializer
    implements PrimitiveSerializer<StageDataRekeyRecordResponse> {
  @override
  final Iterable<Type> types = const [
    StageDataRekeyRecordResponse,
    _$StageDataRekeyRecordResponse,
  ];

  @override
  final String wireName = r'StageDataRekeyRecordResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    StageDataRekeyRecordResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(DataRekeyRecordStageData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    StageDataRekeyRecordResponse object, {
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
    required StageDataRekeyRecordResponseBuilder result,
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
                    specifiedType: const FullType(DataRekeyRecordStageData),
                  )
                  as DataRekeyRecordStageData;
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
  StageDataRekeyRecordResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = StageDataRekeyRecordResponseBuilder();
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
