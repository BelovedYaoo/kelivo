//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/list_trusted_devices_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'list_trusted_devices_response.g.dart';

/// ListTrustedDevicesResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class ListTrustedDevicesResponse
    implements
        Built<ListTrustedDevicesResponse, ListTrustedDevicesResponseBuilder> {
  @BuiltValueField(wireName: r'data')
  ListTrustedDevicesData get data;

  ListTrustedDevicesResponse._();

  factory ListTrustedDevicesResponse([
    void updates(ListTrustedDevicesResponseBuilder b),
  ]) = _$ListTrustedDevicesResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ListTrustedDevicesResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ListTrustedDevicesResponse> get serializer =>
      _$ListTrustedDevicesResponseSerializer();
}

class _$ListTrustedDevicesResponseSerializer
    implements PrimitiveSerializer<ListTrustedDevicesResponse> {
  @override
  final Iterable<Type> types = const [
    ListTrustedDevicesResponse,
    _$ListTrustedDevicesResponse,
  ];

  @override
  final String wireName = r'ListTrustedDevicesResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ListTrustedDevicesResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(ListTrustedDevicesData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ListTrustedDevicesResponse object, {
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
    required ListTrustedDevicesResponseBuilder result,
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
                    specifiedType: const FullType(ListTrustedDevicesData),
                  )
                  as ListTrustedDevicesData;
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
  ListTrustedDevicesResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ListTrustedDevicesResponseBuilder();
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
