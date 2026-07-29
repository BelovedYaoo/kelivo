//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/data_rekey_source_record_list_data_records_inner.dart';
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'data_rekey_source_record_list_data.g.dart';

/// DataRekeySourceRecordListData
///
/// Properties:
/// * [records]
/// * [nextAfterRecordId]
/// * [hasMore]
@BuiltValue()
abstract class DataRekeySourceRecordListData
    implements
        Built<
          DataRekeySourceRecordListData,
          DataRekeySourceRecordListDataBuilder
        > {
  @BuiltValueField(wireName: r'records')
  BuiltList<DataRekeySourceRecordListDataRecordsInner> get records;

  @BuiltValueField(wireName: r'nextAfterRecordId')
  String? get nextAfterRecordId;

  @BuiltValueField(wireName: r'hasMore')
  bool get hasMore;

  DataRekeySourceRecordListData._();

  factory DataRekeySourceRecordListData([
    void updates(DataRekeySourceRecordListDataBuilder b),
  ]) = _$DataRekeySourceRecordListData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DataRekeySourceRecordListDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DataRekeySourceRecordListData> get serializer =>
      _$DataRekeySourceRecordListDataSerializer();
}

class _$DataRekeySourceRecordListDataSerializer
    implements PrimitiveSerializer<DataRekeySourceRecordListData> {
  @override
  final Iterable<Type> types = const [
    DataRekeySourceRecordListData,
    _$DataRekeySourceRecordListData,
  ];

  @override
  final String wireName = r'DataRekeySourceRecordListData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DataRekeySourceRecordListData object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'records';
    yield serializers.serialize(
      object.records,
      specifiedType: const FullType(BuiltList, [
        FullType(DataRekeySourceRecordListDataRecordsInner),
      ]),
    );
    yield r'nextAfterRecordId';
    yield object.nextAfterRecordId == null
        ? null
        : serializers.serialize(
            object.nextAfterRecordId,
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
    DataRekeySourceRecordListData object, {
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
    required DataRekeySourceRecordListDataBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'records':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(BuiltList, [
                      FullType(DataRekeySourceRecordListDataRecordsInner),
                    ]),
                  )
                  as BuiltList<DataRekeySourceRecordListDataRecordsInner>;
          result.records.replace(valueDes);
          break;
        case r'nextAfterRecordId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType.nullable(String),
                  )
                  as String?;
          if (valueDes == null) continue;
          result.nextAfterRecordId = valueDes;
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
  DataRekeySourceRecordListData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DataRekeySourceRecordListDataBuilder();
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
