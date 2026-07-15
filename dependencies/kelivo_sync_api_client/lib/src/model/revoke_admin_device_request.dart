//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'revoke_admin_device_request.g.dart';

/// RevokeAdminDeviceRequest
///
/// Properties:
/// * [deviceId]
@BuiltValue()
abstract class RevokeAdminDeviceRequest
    implements
        Built<RevokeAdminDeviceRequest, RevokeAdminDeviceRequestBuilder> {
  @BuiltValueField(wireName: r'deviceId')
  String get deviceId;

  RevokeAdminDeviceRequest._();

  factory RevokeAdminDeviceRequest([
    void updates(RevokeAdminDeviceRequestBuilder b),
  ]) = _$RevokeAdminDeviceRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(RevokeAdminDeviceRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<RevokeAdminDeviceRequest> get serializer =>
      _$RevokeAdminDeviceRequestSerializer();
}

class _$RevokeAdminDeviceRequestSerializer
    implements PrimitiveSerializer<RevokeAdminDeviceRequest> {
  @override
  final Iterable<Type> types = const [
    RevokeAdminDeviceRequest,
    _$RevokeAdminDeviceRequest,
  ];

  @override
  final String wireName = r'RevokeAdminDeviceRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    RevokeAdminDeviceRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'deviceId';
    yield serializers.serialize(
      object.deviceId,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    RevokeAdminDeviceRequest object, {
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
    required RevokeAdminDeviceRequestBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'deviceId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.deviceId = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  RevokeAdminDeviceRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = RevokeAdminDeviceRequestBuilder();
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
