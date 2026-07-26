//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/device_pairing_approve_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'device_pairing_approve_response.g.dart';

/// DevicePairingApproveResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class DevicePairingApproveResponse
    implements
        Built<
          DevicePairingApproveResponse,
          DevicePairingApproveResponseBuilder
        > {
  @BuiltValueField(wireName: r'data')
  DevicePairingApproveData get data;

  DevicePairingApproveResponse._();

  factory DevicePairingApproveResponse([
    void updates(DevicePairingApproveResponseBuilder b),
  ]) = _$DevicePairingApproveResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DevicePairingApproveResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DevicePairingApproveResponse> get serializer =>
      _$DevicePairingApproveResponseSerializer();
}

class _$DevicePairingApproveResponseSerializer
    implements PrimitiveSerializer<DevicePairingApproveResponse> {
  @override
  final Iterable<Type> types = const [
    DevicePairingApproveResponse,
    _$DevicePairingApproveResponse,
  ];

  @override
  final String wireName = r'DevicePairingApproveResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DevicePairingApproveResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(DevicePairingApproveData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    DevicePairingApproveResponse object, {
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
    required DevicePairingApproveResponseBuilder result,
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
                    specifiedType: const FullType(DevicePairingApproveData),
                  )
                  as DevicePairingApproveData;
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
  DevicePairingApproveResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DevicePairingApproveResponseBuilder();
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
