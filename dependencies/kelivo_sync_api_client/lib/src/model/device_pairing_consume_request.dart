//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'device_pairing_consume_request.g.dart';

/// DevicePairingConsumeRequest
///
/// Properties:
/// * [protocolVersion]
/// * [pairingId]
@BuiltValue()
abstract class DevicePairingConsumeRequest
    implements
        Built<DevicePairingConsumeRequest, DevicePairingConsumeRequestBuilder> {
  @BuiltValueField(wireName: r'protocolVersion')
  int get protocolVersion;

  @BuiltValueField(wireName: r'pairingId')
  String get pairingId;

  DevicePairingConsumeRequest._();

  factory DevicePairingConsumeRequest([
    void updates(DevicePairingConsumeRequestBuilder b),
  ]) = _$DevicePairingConsumeRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DevicePairingConsumeRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DevicePairingConsumeRequest> get serializer =>
      _$DevicePairingConsumeRequestSerializer();
}

class _$DevicePairingConsumeRequestSerializer
    implements PrimitiveSerializer<DevicePairingConsumeRequest> {
  @override
  final Iterable<Type> types = const [
    DevicePairingConsumeRequest,
    _$DevicePairingConsumeRequest,
  ];

  @override
  final String wireName = r'DevicePairingConsumeRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DevicePairingConsumeRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'protocolVersion';
    yield serializers.serialize(
      object.protocolVersion,
      specifiedType: const FullType(int),
    );
    yield r'pairingId';
    yield serializers.serialize(
      object.pairingId,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    DevicePairingConsumeRequest object, {
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
    required DevicePairingConsumeRequestBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'protocolVersion':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.protocolVersion = valueDes;
          break;
        case r'pairingId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.pairingId = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  DevicePairingConsumeRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DevicePairingConsumeRequestBuilder();
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
