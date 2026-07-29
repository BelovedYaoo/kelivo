//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'device_security_state_envelope.g.dart';

/// DeviceSecurityStateEnvelope
///
/// Properties:
/// * [targetDeviceId]
/// * [issuerDeviceId]
/// * [envelopeVersion]
/// * [keyEpoch]
/// * [accountKeyEnvelope]
@BuiltValue()
abstract class DeviceSecurityStateEnvelope
    implements
        Built<DeviceSecurityStateEnvelope, DeviceSecurityStateEnvelopeBuilder> {
  @BuiltValueField(wireName: r'targetDeviceId')
  String get targetDeviceId;

  @BuiltValueField(wireName: r'issuerDeviceId')
  String get issuerDeviceId;

  @BuiltValueField(wireName: r'envelopeVersion')
  int get envelopeVersion;

  @BuiltValueField(wireName: r'keyEpoch')
  int get keyEpoch;

  @BuiltValueField(wireName: r'accountKeyEnvelope')
  String get accountKeyEnvelope;

  DeviceSecurityStateEnvelope._();

  factory DeviceSecurityStateEnvelope([
    void updates(DeviceSecurityStateEnvelopeBuilder b),
  ]) = _$DeviceSecurityStateEnvelope;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DeviceSecurityStateEnvelopeBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DeviceSecurityStateEnvelope> get serializer =>
      _$DeviceSecurityStateEnvelopeSerializer();
}

class _$DeviceSecurityStateEnvelopeSerializer
    implements PrimitiveSerializer<DeviceSecurityStateEnvelope> {
  @override
  final Iterable<Type> types = const [
    DeviceSecurityStateEnvelope,
    _$DeviceSecurityStateEnvelope,
  ];

  @override
  final String wireName = r'DeviceSecurityStateEnvelope';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DeviceSecurityStateEnvelope object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'targetDeviceId';
    yield serializers.serialize(
      object.targetDeviceId,
      specifiedType: const FullType(String),
    );
    yield r'issuerDeviceId';
    yield serializers.serialize(
      object.issuerDeviceId,
      specifiedType: const FullType(String),
    );
    yield r'envelopeVersion';
    yield serializers.serialize(
      object.envelopeVersion,
      specifiedType: const FullType(int),
    );
    yield r'keyEpoch';
    yield serializers.serialize(
      object.keyEpoch,
      specifiedType: const FullType(int),
    );
    yield r'accountKeyEnvelope';
    yield serializers.serialize(
      object.accountKeyEnvelope,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    DeviceSecurityStateEnvelope object, {
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
    required DeviceSecurityStateEnvelopeBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'targetDeviceId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.targetDeviceId = valueDes;
          break;
        case r'issuerDeviceId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.issuerDeviceId = valueDes;
          break;
        case r'envelopeVersion':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.envelopeVersion = valueDes;
          break;
        case r'keyEpoch':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.keyEpoch = valueDes;
          break;
        case r'accountKeyEnvelope':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.accountKeyEnvelope = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  DeviceSecurityStateEnvelope deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DeviceSecurityStateEnvelopeBuilder();
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
