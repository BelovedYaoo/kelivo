//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/initialize_device_security_state_envelope.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'initialize_device_security_state_request.g.dart';

/// InitializeDeviceSecurityStateRequest
///
/// Properties:
/// * [generation]
/// * [keyEpoch]
/// * [membershipManifestVersion]
/// * [membershipManifest]
/// * [membershipManifestDigest]
/// * [recoveryPublicKeyVersion]
/// * [recoveryPublicKey]
/// * [recoveryCapsuleVersion]
/// * [recoveryCapsule]
/// * [currentDeviceEnvelope]
@BuiltValue()
abstract class InitializeDeviceSecurityStateRequest
    implements
        Built<
          InitializeDeviceSecurityStateRequest,
          InitializeDeviceSecurityStateRequestBuilder
        > {
  @BuiltValueField(wireName: r'generation')
  int get generation;

  @BuiltValueField(wireName: r'keyEpoch')
  int get keyEpoch;

  @BuiltValueField(wireName: r'membershipManifestVersion')
  int get membershipManifestVersion;

  @BuiltValueField(wireName: r'membershipManifest')
  String get membershipManifest;

  @BuiltValueField(wireName: r'membershipManifestDigest')
  String get membershipManifestDigest;

  @BuiltValueField(wireName: r'recoveryPublicKeyVersion')
  int get recoveryPublicKeyVersion;

  @BuiltValueField(wireName: r'recoveryPublicKey')
  String get recoveryPublicKey;

  @BuiltValueField(wireName: r'recoveryCapsuleVersion')
  int get recoveryCapsuleVersion;

  @BuiltValueField(wireName: r'recoveryCapsule')
  String get recoveryCapsule;

  @BuiltValueField(wireName: r'currentDeviceEnvelope')
  InitializeDeviceSecurityStateEnvelope get currentDeviceEnvelope;

  InitializeDeviceSecurityStateRequest._();

  factory InitializeDeviceSecurityStateRequest([
    void updates(InitializeDeviceSecurityStateRequestBuilder b),
  ]) = _$InitializeDeviceSecurityStateRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(InitializeDeviceSecurityStateRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<InitializeDeviceSecurityStateRequest> get serializer =>
      _$InitializeDeviceSecurityStateRequestSerializer();
}

class _$InitializeDeviceSecurityStateRequestSerializer
    implements PrimitiveSerializer<InitializeDeviceSecurityStateRequest> {
  @override
  final Iterable<Type> types = const [
    InitializeDeviceSecurityStateRequest,
    _$InitializeDeviceSecurityStateRequest,
  ];

  @override
  final String wireName = r'InitializeDeviceSecurityStateRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    InitializeDeviceSecurityStateRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'generation';
    yield serializers.serialize(
      object.generation,
      specifiedType: const FullType(int),
    );
    yield r'keyEpoch';
    yield serializers.serialize(
      object.keyEpoch,
      specifiedType: const FullType(int),
    );
    yield r'membershipManifestVersion';
    yield serializers.serialize(
      object.membershipManifestVersion,
      specifiedType: const FullType(int),
    );
    yield r'membershipManifest';
    yield serializers.serialize(
      object.membershipManifest,
      specifiedType: const FullType(String),
    );
    yield r'membershipManifestDigest';
    yield serializers.serialize(
      object.membershipManifestDigest,
      specifiedType: const FullType(String),
    );
    yield r'recoveryPublicKeyVersion';
    yield serializers.serialize(
      object.recoveryPublicKeyVersion,
      specifiedType: const FullType(int),
    );
    yield r'recoveryPublicKey';
    yield serializers.serialize(
      object.recoveryPublicKey,
      specifiedType: const FullType(String),
    );
    yield r'recoveryCapsuleVersion';
    yield serializers.serialize(
      object.recoveryCapsuleVersion,
      specifiedType: const FullType(int),
    );
    yield r'recoveryCapsule';
    yield serializers.serialize(
      object.recoveryCapsule,
      specifiedType: const FullType(String),
    );
    yield r'currentDeviceEnvelope';
    yield serializers.serialize(
      object.currentDeviceEnvelope,
      specifiedType: const FullType(InitializeDeviceSecurityStateEnvelope),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    InitializeDeviceSecurityStateRequest object, {
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
    required InitializeDeviceSecurityStateRequestBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'generation':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.generation = valueDes;
          break;
        case r'keyEpoch':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.keyEpoch = valueDes;
          break;
        case r'membershipManifestVersion':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.membershipManifestVersion = valueDes;
          break;
        case r'membershipManifest':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.membershipManifest = valueDes;
          break;
        case r'membershipManifestDigest':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.membershipManifestDigest = valueDes;
          break;
        case r'recoveryPublicKeyVersion':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.recoveryPublicKeyVersion = valueDes;
          break;
        case r'recoveryPublicKey':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.recoveryPublicKey = valueDes;
          break;
        case r'recoveryCapsuleVersion':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.recoveryCapsuleVersion = valueDes;
          break;
        case r'recoveryCapsule':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.recoveryCapsule = valueDes;
          break;
        case r'currentDeviceEnvelope':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      InitializeDeviceSecurityStateEnvelope,
                    ),
                  )
                  as InitializeDeviceSecurityStateEnvelope;
          result.currentDeviceEnvelope.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  InitializeDeviceSecurityStateRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = InitializeDeviceSecurityStateRequestBuilder();
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
