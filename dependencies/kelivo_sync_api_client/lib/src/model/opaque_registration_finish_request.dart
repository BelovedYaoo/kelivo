//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/genesis_security_state.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'opaque_registration_finish_request.g.dart';

/// OpaqueRegistrationFinishRequest
///
/// Properties:
/// * [protocolVersion]
/// * [attemptId]
/// * [registrationUpload]
/// * [accountKeyEnvelope]
/// * [securityState]
/// * [deviceProof]
@BuiltValue()
abstract class OpaqueRegistrationFinishRequest
    implements
        Built<
          OpaqueRegistrationFinishRequest,
          OpaqueRegistrationFinishRequestBuilder
        > {
  @BuiltValueField(wireName: r'protocolVersion')
  int get protocolVersion;

  @BuiltValueField(wireName: r'attemptId')
  String get attemptId;

  @BuiltValueField(wireName: r'registrationUpload')
  String get registrationUpload;

  @BuiltValueField(wireName: r'accountKeyEnvelope')
  String get accountKeyEnvelope;

  @BuiltValueField(wireName: r'securityState')
  GenesisSecurityState get securityState;

  @BuiltValueField(wireName: r'deviceProof')
  String get deviceProof;

  OpaqueRegistrationFinishRequest._();

  factory OpaqueRegistrationFinishRequest([
    void updates(OpaqueRegistrationFinishRequestBuilder b),
  ]) = _$OpaqueRegistrationFinishRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(OpaqueRegistrationFinishRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<OpaqueRegistrationFinishRequest> get serializer =>
      _$OpaqueRegistrationFinishRequestSerializer();
}

class _$OpaqueRegistrationFinishRequestSerializer
    implements PrimitiveSerializer<OpaqueRegistrationFinishRequest> {
  @override
  final Iterable<Type> types = const [
    OpaqueRegistrationFinishRequest,
    _$OpaqueRegistrationFinishRequest,
  ];

  @override
  final String wireName = r'OpaqueRegistrationFinishRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    OpaqueRegistrationFinishRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'protocolVersion';
    yield serializers.serialize(
      object.protocolVersion,
      specifiedType: const FullType(int),
    );
    yield r'attemptId';
    yield serializers.serialize(
      object.attemptId,
      specifiedType: const FullType(String),
    );
    yield r'registrationUpload';
    yield serializers.serialize(
      object.registrationUpload,
      specifiedType: const FullType(String),
    );
    yield r'accountKeyEnvelope';
    yield serializers.serialize(
      object.accountKeyEnvelope,
      specifiedType: const FullType(String),
    );
    yield r'securityState';
    yield serializers.serialize(
      object.securityState,
      specifiedType: const FullType(GenesisSecurityState),
    );
    yield r'deviceProof';
    yield serializers.serialize(
      object.deviceProof,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    OpaqueRegistrationFinishRequest object, {
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
    required OpaqueRegistrationFinishRequestBuilder result,
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
        case r'attemptId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.attemptId = valueDes;
          break;
        case r'registrationUpload':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.registrationUpload = valueDes;
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
        case r'securityState':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(GenesisSecurityState),
                  )
                  as GenesisSecurityState;
          result.securityState.replace(valueDes);
          break;
        case r'deviceProof':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.deviceProof = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  OpaqueRegistrationFinishRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = OpaqueRegistrationFinishRequestBuilder();
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
