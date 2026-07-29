//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/data_rekey_source_record_list_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'list_data_rekey_source_records_response.g.dart';

/// ListDataRekeySourceRecordsResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class ListDataRekeySourceRecordsResponse
    implements
        Built<
          ListDataRekeySourceRecordsResponse,
          ListDataRekeySourceRecordsResponseBuilder
        > {
  @BuiltValueField(wireName: r'data')
  DataRekeySourceRecordListData get data;

  ListDataRekeySourceRecordsResponse._();

  factory ListDataRekeySourceRecordsResponse([
    void updates(ListDataRekeySourceRecordsResponseBuilder b),
  ]) = _$ListDataRekeySourceRecordsResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ListDataRekeySourceRecordsResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ListDataRekeySourceRecordsResponse> get serializer =>
      _$ListDataRekeySourceRecordsResponseSerializer();
}

class _$ListDataRekeySourceRecordsResponseSerializer
    implements PrimitiveSerializer<ListDataRekeySourceRecordsResponse> {
  @override
  final Iterable<Type> types = const [
    ListDataRekeySourceRecordsResponse,
    _$ListDataRekeySourceRecordsResponse,
  ];

  @override
  final String wireName = r'ListDataRekeySourceRecordsResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ListDataRekeySourceRecordsResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(DataRekeySourceRecordListData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ListDataRekeySourceRecordsResponse object, {
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
    required ListDataRekeySourceRecordsResponseBuilder result,
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
                    specifiedType: const FullType(
                      DataRekeySourceRecordListData,
                    ),
                  )
                  as DataRekeySourceRecordListData;
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
  ListDataRekeySourceRecordsResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ListDataRekeySourceRecordsResponseBuilder();
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
