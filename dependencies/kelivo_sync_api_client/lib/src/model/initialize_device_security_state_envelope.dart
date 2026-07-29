//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'initialize_device_security_state_envelope.g.dart';

/// InitializeDeviceSecurityStateEnvelope
///
/// Properties:
/// * [targetDeviceId]
/// * [envelopeVersion]
/// * [keyEpoch]
/// * [accountKeyEnvelope]
@BuiltValue()
abstract class InitializeDeviceSecurityStateEnvelope
    implements
        Built<
          InitializeDeviceSecurityStateEnvelope,
          InitializeDeviceSecurityStateEnvelopeBuilder
        > {
  @BuiltValueField(wireName: r'targetDeviceId')
  String get targetDeviceId;

  @BuiltValueField(wireName: r'envelopeVersion')
  int get envelopeVersion;

  @BuiltValueField(wireName: r'keyEpoch')
  int get keyEpoch;

  @BuiltValueField(wireName: r'accountKeyEnvelope')
  String get accountKeyEnvelope;

  InitializeDeviceSecurityStateEnvelope._();

  factory InitializeDeviceSecurityStateEnvelope([
    void updates(InitializeDeviceSecurityStateEnvelopeBuilder b),
  ]) = _$InitializeDeviceSecurityStateEnvelope;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(InitializeDeviceSecurityStateEnvelopeBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<InitializeDeviceSecurityStateEnvelope> get serializer =>
      _$InitializeDeviceSecurityStateEnvelopeSerializer();
}

class _$InitializeDeviceSecurityStateEnvelopeSerializer
    implements PrimitiveSerializer<InitializeDeviceSecurityStateEnvelope> {
  @override
  final Iterable<Type> types = const [
    InitializeDeviceSecurityStateEnvelope,
    _$InitializeDeviceSecurityStateEnvelope,
  ];

  @override
  final String wireName = r'InitializeDeviceSecurityStateEnvelope';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    InitializeDeviceSecurityStateEnvelope object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'targetDeviceId';
    yield serializers.serialize(
      object.targetDeviceId,
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
    InitializeDeviceSecurityStateEnvelope object, {
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
    required InitializeDeviceSecurityStateEnvelopeBuilder result,
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
  InitializeDeviceSecurityStateEnvelope deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = InitializeDeviceSecurityStateEnvelopeBuilder();
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
