//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/account_security_state_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'get_device_security_state_response.g.dart';

/// GetDeviceSecurityStateResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class GetDeviceSecurityStateResponse
    implements
        Built<
          GetDeviceSecurityStateResponse,
          GetDeviceSecurityStateResponseBuilder
        > {
  @BuiltValueField(wireName: r'data')
  AccountSecurityStateData get data;

  GetDeviceSecurityStateResponse._();

  factory GetDeviceSecurityStateResponse([
    void updates(GetDeviceSecurityStateResponseBuilder b),
  ]) = _$GetDeviceSecurityStateResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(GetDeviceSecurityStateResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<GetDeviceSecurityStateResponse> get serializer =>
      _$GetDeviceSecurityStateResponseSerializer();
}

class _$GetDeviceSecurityStateResponseSerializer
    implements PrimitiveSerializer<GetDeviceSecurityStateResponse> {
  @override
  final Iterable<Type> types = const [
    GetDeviceSecurityStateResponse,
    _$GetDeviceSecurityStateResponse,
  ];

  @override
  final String wireName = r'GetDeviceSecurityStateResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    GetDeviceSecurityStateResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(AccountSecurityStateData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    GetDeviceSecurityStateResponse object, {
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
    required GetDeviceSecurityStateResponseBuilder result,
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
                    specifiedType: const FullType(AccountSecurityStateData),
                  )
                  as AccountSecurityStateData;
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
  GetDeviceSecurityStateResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = GetDeviceSecurityStateResponseBuilder();
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
