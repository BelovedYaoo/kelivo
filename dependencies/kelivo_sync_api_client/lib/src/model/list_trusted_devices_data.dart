//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/trusted_device_summary.dart';
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'list_trusted_devices_data.g.dart';

/// ListTrustedDevicesData
///
/// Properties:
/// * [items]
/// * [total]
/// * [pageIndex]
/// * [pageSize]
@BuiltValue()
abstract class ListTrustedDevicesData
    implements Built<ListTrustedDevicesData, ListTrustedDevicesDataBuilder> {
  @BuiltValueField(wireName: r'items')
  BuiltList<TrustedDeviceSummary> get items;

  @BuiltValueField(wireName: r'total')
  int get total;

  @BuiltValueField(wireName: r'pageIndex')
  int get pageIndex;

  @BuiltValueField(wireName: r'pageSize')
  int get pageSize;

  ListTrustedDevicesData._();

  factory ListTrustedDevicesData([
    void updates(ListTrustedDevicesDataBuilder b),
  ]) = _$ListTrustedDevicesData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ListTrustedDevicesDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ListTrustedDevicesData> get serializer =>
      _$ListTrustedDevicesDataSerializer();
}

class _$ListTrustedDevicesDataSerializer
    implements PrimitiveSerializer<ListTrustedDevicesData> {
  @override
  final Iterable<Type> types = const [
    ListTrustedDevicesData,
    _$ListTrustedDevicesData,
  ];

  @override
  final String wireName = r'ListTrustedDevicesData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ListTrustedDevicesData object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'items';
    yield serializers.serialize(
      object.items,
      specifiedType: const FullType(BuiltList, [
        FullType(TrustedDeviceSummary),
      ]),
    );
    yield r'total';
    yield serializers.serialize(
      object.total,
      specifiedType: const FullType(int),
    );
    yield r'pageIndex';
    yield serializers.serialize(
      object.pageIndex,
      specifiedType: const FullType(int),
    );
    yield r'pageSize';
    yield serializers.serialize(
      object.pageSize,
      specifiedType: const FullType(int),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ListTrustedDevicesData object, {
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
    required ListTrustedDevicesDataBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'items':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(BuiltList, [
                      FullType(TrustedDeviceSummary),
                    ]),
                  )
                  as BuiltList<TrustedDeviceSummary>;
          result.items.replace(valueDes);
          break;
        case r'total':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.total = valueDes;
          break;
        case r'pageIndex':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.pageIndex = valueDes;
          break;
        case r'pageSize':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.pageSize = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ListTrustedDevicesData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ListTrustedDevicesDataBuilder();
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
