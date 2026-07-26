//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'opaque_login_finish_request.g.dart';

/// OpaqueLoginFinishRequest
///
/// Properties:
/// * [protocolVersion]
/// * [attemptId]
/// * [credentialFinalization]
/// * [deviceProof]
@BuiltValue()
abstract class OpaqueLoginFinishRequest
    implements
        Built<OpaqueLoginFinishRequest, OpaqueLoginFinishRequestBuilder> {
  @BuiltValueField(wireName: r'protocolVersion')
  int get protocolVersion;

  @BuiltValueField(wireName: r'attemptId')
  String get attemptId;

  @BuiltValueField(wireName: r'credentialFinalization')
  String get credentialFinalization;

  @BuiltValueField(wireName: r'deviceProof')
  String get deviceProof;

  OpaqueLoginFinishRequest._();

  factory OpaqueLoginFinishRequest([
    void updates(OpaqueLoginFinishRequestBuilder b),
  ]) = _$OpaqueLoginFinishRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(OpaqueLoginFinishRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<OpaqueLoginFinishRequest> get serializer =>
      _$OpaqueLoginFinishRequestSerializer();
}

class _$OpaqueLoginFinishRequestSerializer
    implements PrimitiveSerializer<OpaqueLoginFinishRequest> {
  @override
  final Iterable<Type> types = const [
    OpaqueLoginFinishRequest,
    _$OpaqueLoginFinishRequest,
  ];

  @override
  final String wireName = r'OpaqueLoginFinishRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    OpaqueLoginFinishRequest object, {
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
    yield r'credentialFinalization';
    yield serializers.serialize(
      object.credentialFinalization,
      specifiedType: const FullType(String),
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
    OpaqueLoginFinishRequest object, {
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
    required OpaqueLoginFinishRequestBuilder result,
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
        case r'credentialFinalization':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.credentialFinalization = valueDes;
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
  OpaqueLoginFinishRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = OpaqueLoginFinishRequestBuilder();
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
