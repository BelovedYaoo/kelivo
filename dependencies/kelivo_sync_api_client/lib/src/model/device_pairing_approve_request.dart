//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'device_pairing_approve_request.g.dart';

/// DevicePairingApproveRequest
///
/// Properties:
/// * [protocolVersion]
/// * [pairingId]
/// * [keyEpoch]
/// * [expectedSecurityGeneration]
/// * [expectedMembershipManifestDigest]
/// * [nextMembershipManifest]
/// * [nextMembershipManifestDigest]
/// * [accountKeyEnvelope]
/// * [deviceProof]
/// * [pairingAuthenticator]
@BuiltValue()
abstract class DevicePairingApproveRequest
    implements
        Built<DevicePairingApproveRequest, DevicePairingApproveRequestBuilder> {
  @BuiltValueField(wireName: r'protocolVersion')
  int get protocolVersion;

  @BuiltValueField(wireName: r'pairingId')
  String get pairingId;

  @BuiltValueField(wireName: r'keyEpoch')
  int get keyEpoch;

  @BuiltValueField(wireName: r'expectedSecurityGeneration')
  int get expectedSecurityGeneration;

  @BuiltValueField(wireName: r'expectedMembershipManifestDigest')
  String get expectedMembershipManifestDigest;

  @BuiltValueField(wireName: r'nextMembershipManifest')
  String get nextMembershipManifest;

  @BuiltValueField(wireName: r'nextMembershipManifestDigest')
  String get nextMembershipManifestDigest;

  @BuiltValueField(wireName: r'accountKeyEnvelope')
  String get accountKeyEnvelope;

  @BuiltValueField(wireName: r'deviceProof')
  String get deviceProof;

  @BuiltValueField(wireName: r'pairingAuthenticator')
  String get pairingAuthenticator;

  DevicePairingApproveRequest._();

  factory DevicePairingApproveRequest([
    void updates(DevicePairingApproveRequestBuilder b),
  ]) = _$DevicePairingApproveRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DevicePairingApproveRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DevicePairingApproveRequest> get serializer =>
      _$DevicePairingApproveRequestSerializer();
}

class _$DevicePairingApproveRequestSerializer
    implements PrimitiveSerializer<DevicePairingApproveRequest> {
  @override
  final Iterable<Type> types = const [
    DevicePairingApproveRequest,
    _$DevicePairingApproveRequest,
  ];

  @override
  final String wireName = r'DevicePairingApproveRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DevicePairingApproveRequest object, {
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
    yield r'keyEpoch';
    yield serializers.serialize(
      object.keyEpoch,
      specifiedType: const FullType(int),
    );
    yield r'expectedSecurityGeneration';
    yield serializers.serialize(
      object.expectedSecurityGeneration,
      specifiedType: const FullType(int),
    );
    yield r'expectedMembershipManifestDigest';
    yield serializers.serialize(
      object.expectedMembershipManifestDigest,
      specifiedType: const FullType(String),
    );
    yield r'nextMembershipManifest';
    yield serializers.serialize(
      object.nextMembershipManifest,
      specifiedType: const FullType(String),
    );
    yield r'nextMembershipManifestDigest';
    yield serializers.serialize(
      object.nextMembershipManifestDigest,
      specifiedType: const FullType(String),
    );
    yield r'accountKeyEnvelope';
    yield serializers.serialize(
      object.accountKeyEnvelope,
      specifiedType: const FullType(String),
    );
    yield r'deviceProof';
    yield serializers.serialize(
      object.deviceProof,
      specifiedType: const FullType(String),
    );
    yield r'pairingAuthenticator';
    yield serializers.serialize(
      object.pairingAuthenticator,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    DevicePairingApproveRequest object, {
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
    required DevicePairingApproveRequestBuilder result,
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
        case r'keyEpoch':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.keyEpoch = valueDes;
          break;
        case r'expectedSecurityGeneration':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.expectedSecurityGeneration = valueDes;
          break;
        case r'expectedMembershipManifestDigest':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.expectedMembershipManifestDigest = valueDes;
          break;
        case r'nextMembershipManifest':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.nextMembershipManifest = valueDes;
          break;
        case r'nextMembershipManifestDigest':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.nextMembershipManifestDigest = valueDes;
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
        case r'deviceProof':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.deviceProof = valueDes;
          break;
        case r'pairingAuthenticator':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.pairingAuthenticator = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  DevicePairingApproveRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DevicePairingApproveRequestBuilder();
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
