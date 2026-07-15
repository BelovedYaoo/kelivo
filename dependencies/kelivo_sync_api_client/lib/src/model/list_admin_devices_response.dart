//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/list_admin_devices_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'list_admin_devices_response.g.dart';

/// ListAdminDevicesResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class ListAdminDevicesResponse
    implements
        Built<ListAdminDevicesResponse, ListAdminDevicesResponseBuilder> {
  @BuiltValueField(wireName: r'data')
  ListAdminDevicesData get data;

  ListAdminDevicesResponse._();

  factory ListAdminDevicesResponse([
    void updates(ListAdminDevicesResponseBuilder b),
  ]) = _$ListAdminDevicesResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ListAdminDevicesResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ListAdminDevicesResponse> get serializer =>
      _$ListAdminDevicesResponseSerializer();
}

class _$ListAdminDevicesResponseSerializer
    implements PrimitiveSerializer<ListAdminDevicesResponse> {
  @override
  final Iterable<Type> types = const [
    ListAdminDevicesResponse,
    _$ListAdminDevicesResponse,
  ];

  @override
  final String wireName = r'ListAdminDevicesResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ListAdminDevicesResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(ListAdminDevicesData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ListAdminDevicesResponse object, {
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
    required ListAdminDevicesResponseBuilder result,
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
                    specifiedType: const FullType(ListAdminDevicesData),
                  )
                  as ListAdminDevicesData;
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
  ListAdminDevicesResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ListAdminDevicesResponseBuilder();
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
