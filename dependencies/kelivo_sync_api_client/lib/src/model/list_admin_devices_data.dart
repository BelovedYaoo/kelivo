//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:kelivo_sync_api_client/src/model/admin_device_summary.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'list_admin_devices_data.g.dart';

/// ListAdminDevicesData
///
/// Properties:
/// * [items]
/// * [total]
/// * [pageIndex]
/// * [pageSize]
@BuiltValue()
abstract class ListAdminDevicesData
    implements Built<ListAdminDevicesData, ListAdminDevicesDataBuilder> {
  @BuiltValueField(wireName: r'items')
  BuiltList<AdminDeviceSummary> get items;

  @BuiltValueField(wireName: r'total')
  int get total;

  @BuiltValueField(wireName: r'pageIndex')
  int get pageIndex;

  @BuiltValueField(wireName: r'pageSize')
  int get pageSize;

  ListAdminDevicesData._();

  factory ListAdminDevicesData([void updates(ListAdminDevicesDataBuilder b)]) =
      _$ListAdminDevicesData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ListAdminDevicesDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ListAdminDevicesData> get serializer =>
      _$ListAdminDevicesDataSerializer();
}

class _$ListAdminDevicesDataSerializer
    implements PrimitiveSerializer<ListAdminDevicesData> {
  @override
  final Iterable<Type> types = const [
    ListAdminDevicesData,
    _$ListAdminDevicesData,
  ];

  @override
  final String wireName = r'ListAdminDevicesData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ListAdminDevicesData object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'items';
    yield serializers.serialize(
      object.items,
      specifiedType: const FullType(BuiltList, [FullType(AdminDeviceSummary)]),
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
    ListAdminDevicesData object, {
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
    required ListAdminDevicesDataBuilder result,
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
                      FullType(AdminDeviceSummary),
                    ]),
                  )
                  as BuiltList<AdminDeviceSummary>;
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
  ListAdminDevicesData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ListAdminDevicesDataBuilder();
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
