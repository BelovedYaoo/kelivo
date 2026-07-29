//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/device_security_state_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'initialize_device_security_state_response.g.dart';

/// InitializeDeviceSecurityStateResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class InitializeDeviceSecurityStateResponse
    implements
        Built<
          InitializeDeviceSecurityStateResponse,
          InitializeDeviceSecurityStateResponseBuilder
        > {
  @BuiltValueField(wireName: r'data')
  DeviceSecurityStateData get data;

  InitializeDeviceSecurityStateResponse._();

  factory InitializeDeviceSecurityStateResponse([
    void updates(InitializeDeviceSecurityStateResponseBuilder b),
  ]) = _$InitializeDeviceSecurityStateResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(InitializeDeviceSecurityStateResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<InitializeDeviceSecurityStateResponse> get serializer =>
      _$InitializeDeviceSecurityStateResponseSerializer();
}

class _$InitializeDeviceSecurityStateResponseSerializer
    implements PrimitiveSerializer<InitializeDeviceSecurityStateResponse> {
  @override
  final Iterable<Type> types = const [
    InitializeDeviceSecurityStateResponse,
    _$InitializeDeviceSecurityStateResponse,
  ];

  @override
  final String wireName = r'InitializeDeviceSecurityStateResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    InitializeDeviceSecurityStateResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(DeviceSecurityStateData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    InitializeDeviceSecurityStateResponse object, {
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
    required InitializeDeviceSecurityStateResponseBuilder result,
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
                    specifiedType: const FullType(DeviceSecurityStateData),
                  )
                  as DeviceSecurityStateData;
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
  InitializeDeviceSecurityStateResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = InitializeDeviceSecurityStateResponseBuilder();
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
