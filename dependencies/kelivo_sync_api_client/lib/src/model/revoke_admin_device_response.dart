//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/revoke_admin_device_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'revoke_admin_device_response.g.dart';

/// RevokeAdminDeviceResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class RevokeAdminDeviceResponse
    implements
        Built<RevokeAdminDeviceResponse, RevokeAdminDeviceResponseBuilder> {
  @BuiltValueField(wireName: r'data')
  RevokeAdminDeviceData get data;

  RevokeAdminDeviceResponse._();

  factory RevokeAdminDeviceResponse([
    void updates(RevokeAdminDeviceResponseBuilder b),
  ]) = _$RevokeAdminDeviceResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(RevokeAdminDeviceResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<RevokeAdminDeviceResponse> get serializer =>
      _$RevokeAdminDeviceResponseSerializer();
}

class _$RevokeAdminDeviceResponseSerializer
    implements PrimitiveSerializer<RevokeAdminDeviceResponse> {
  @override
  final Iterable<Type> types = const [
    RevokeAdminDeviceResponse,
    _$RevokeAdminDeviceResponse,
  ];

  @override
  final String wireName = r'RevokeAdminDeviceResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    RevokeAdminDeviceResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(RevokeAdminDeviceData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    RevokeAdminDeviceResponse object, {
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
    required RevokeAdminDeviceResponseBuilder result,
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
                    specifiedType: const FullType(RevokeAdminDeviceData),
                  )
                  as RevokeAdminDeviceData;
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
  RevokeAdminDeviceResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = RevokeAdminDeviceResponseBuilder();
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
