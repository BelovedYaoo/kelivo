//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'revoke_device_session_request.g.dart';

/// RevokeDeviceSessionRequest
///
/// Properties:
/// * [deviceId]
@BuiltValue()
abstract class RevokeDeviceSessionRequest
    implements
        Built<RevokeDeviceSessionRequest, RevokeDeviceSessionRequestBuilder> {
  @BuiltValueField(wireName: r'deviceId')
  String get deviceId;

  RevokeDeviceSessionRequest._();

  factory RevokeDeviceSessionRequest([
    void updates(RevokeDeviceSessionRequestBuilder b),
  ]) = _$RevokeDeviceSessionRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(RevokeDeviceSessionRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<RevokeDeviceSessionRequest> get serializer =>
      _$RevokeDeviceSessionRequestSerializer();
}

class _$RevokeDeviceSessionRequestSerializer
    implements PrimitiveSerializer<RevokeDeviceSessionRequest> {
  @override
  final Iterable<Type> types = const [
    RevokeDeviceSessionRequest,
    _$RevokeDeviceSessionRequest,
  ];

  @override
  final String wireName = r'RevokeDeviceSessionRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    RevokeDeviceSessionRequest object, {
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
    RevokeDeviceSessionRequest object, {
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
    required RevokeDeviceSessionRequestBuilder result,
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
  RevokeDeviceSessionRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = RevokeDeviceSessionRequestBuilder();
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
