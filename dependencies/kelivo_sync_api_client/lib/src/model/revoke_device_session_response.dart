//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/revoke_device_session_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'revoke_device_session_response.g.dart';

/// RevokeDeviceSessionResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class RevokeDeviceSessionResponse
    implements
        Built<RevokeDeviceSessionResponse, RevokeDeviceSessionResponseBuilder> {
  @BuiltValueField(wireName: r'data')
  RevokeDeviceSessionData get data;

  RevokeDeviceSessionResponse._();

  factory RevokeDeviceSessionResponse([
    void updates(RevokeDeviceSessionResponseBuilder b),
  ]) = _$RevokeDeviceSessionResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(RevokeDeviceSessionResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<RevokeDeviceSessionResponse> get serializer =>
      _$RevokeDeviceSessionResponseSerializer();
}

class _$RevokeDeviceSessionResponseSerializer
    implements PrimitiveSerializer<RevokeDeviceSessionResponse> {
  @override
  final Iterable<Type> types = const [
    RevokeDeviceSessionResponse,
    _$RevokeDeviceSessionResponse,
  ];

  @override
  final String wireName = r'RevokeDeviceSessionResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    RevokeDeviceSessionResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(RevokeDeviceSessionData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    RevokeDeviceSessionResponse object, {
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
    required RevokeDeviceSessionResponseBuilder result,
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
                    specifiedType: const FullType(RevokeDeviceSessionData),
                  )
                  as RevokeDeviceSessionData;
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
  RevokeDeviceSessionResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = RevokeDeviceSessionResponseBuilder();
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
