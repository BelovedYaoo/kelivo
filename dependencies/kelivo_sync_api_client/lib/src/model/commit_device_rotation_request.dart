//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:kelivo_sync_api_client/src/model/initialize_device_security_state_envelope.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'commit_device_rotation_request.g.dart';

/// CommitDeviceRotationRequest
///
/// Properties:
/// * [expectedGeneration]
/// * [expectedKeyEpoch]
/// * [expectedMembershipManifestDigest]
/// * [operationId]
/// * [revokeDeviceId]
/// * [nextMembershipManifestVersion]
/// * [nextMembershipManifest]
/// * [nextMembershipManifestDigest]
/// * [nextRecoveryCapsuleVersion]
/// * [nextRecoveryCapsule]
/// * [envelopes]
@BuiltValue()
abstract class CommitDeviceRotationRequest
    implements
        Built<CommitDeviceRotationRequest, CommitDeviceRotationRequestBuilder> {
  @BuiltValueField(wireName: r'expectedGeneration')
  int get expectedGeneration;

  @BuiltValueField(wireName: r'expectedKeyEpoch')
  int get expectedKeyEpoch;

  @BuiltValueField(wireName: r'expectedMembershipManifestDigest')
  String get expectedMembershipManifestDigest;

  @BuiltValueField(wireName: r'operationId')
  String get operationId;

  @BuiltValueField(wireName: r'revokeDeviceId')
  String get revokeDeviceId;

  @BuiltValueField(wireName: r'nextMembershipManifestVersion')
  int get nextMembershipManifestVersion;

  @BuiltValueField(wireName: r'nextMembershipManifest')
  String get nextMembershipManifest;

  @BuiltValueField(wireName: r'nextMembershipManifestDigest')
  String get nextMembershipManifestDigest;

  @BuiltValueField(wireName: r'nextRecoveryCapsuleVersion')
  int get nextRecoveryCapsuleVersion;

  @BuiltValueField(wireName: r'nextRecoveryCapsule')
  String get nextRecoveryCapsule;

  @BuiltValueField(wireName: r'envelopes')
  BuiltList<InitializeDeviceSecurityStateEnvelope> get envelopes;

  CommitDeviceRotationRequest._();

  factory CommitDeviceRotationRequest([
    void updates(CommitDeviceRotationRequestBuilder b),
  ]) = _$CommitDeviceRotationRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(CommitDeviceRotationRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<CommitDeviceRotationRequest> get serializer =>
      _$CommitDeviceRotationRequestSerializer();
}

class _$CommitDeviceRotationRequestSerializer
    implements PrimitiveSerializer<CommitDeviceRotationRequest> {
  @override
  final Iterable<Type> types = const [
    CommitDeviceRotationRequest,
    _$CommitDeviceRotationRequest,
  ];

  @override
  final String wireName = r'CommitDeviceRotationRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    CommitDeviceRotationRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'expectedGeneration';
    yield serializers.serialize(
      object.expectedGeneration,
      specifiedType: const FullType(int),
    );
    yield r'expectedKeyEpoch';
    yield serializers.serialize(
      object.expectedKeyEpoch,
      specifiedType: const FullType(int),
    );
    yield r'expectedMembershipManifestDigest';
    yield serializers.serialize(
      object.expectedMembershipManifestDigest,
      specifiedType: const FullType(String),
    );
    yield r'operationId';
    yield serializers.serialize(
      object.operationId,
      specifiedType: const FullType(String),
    );
    yield r'revokeDeviceId';
    yield serializers.serialize(
      object.revokeDeviceId,
      specifiedType: const FullType(String),
    );
    yield r'nextMembershipManifestVersion';
    yield serializers.serialize(
      object.nextMembershipManifestVersion,
      specifiedType: const FullType(int),
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
    yield r'nextRecoveryCapsuleVersion';
    yield serializers.serialize(
      object.nextRecoveryCapsuleVersion,
      specifiedType: const FullType(int),
    );
    yield r'nextRecoveryCapsule';
    yield serializers.serialize(
      object.nextRecoveryCapsule,
      specifiedType: const FullType(String),
    );
    yield r'envelopes';
    yield serializers.serialize(
      object.envelopes,
      specifiedType: const FullType(BuiltList, [
        FullType(InitializeDeviceSecurityStateEnvelope),
      ]),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    CommitDeviceRotationRequest object, {
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
    required CommitDeviceRotationRequestBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'expectedGeneration':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.expectedGeneration = valueDes;
          break;
        case r'expectedKeyEpoch':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.expectedKeyEpoch = valueDes;
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
        case r'operationId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.operationId = valueDes;
          break;
        case r'revokeDeviceId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.revokeDeviceId = valueDes;
          break;
        case r'nextMembershipManifestVersion':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.nextMembershipManifestVersion = valueDes;
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
        case r'nextRecoveryCapsuleVersion':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.nextRecoveryCapsuleVersion = valueDes;
          break;
        case r'nextRecoveryCapsule':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.nextRecoveryCapsule = valueDes;
          break;
        case r'envelopes':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(BuiltList, [
                      FullType(InitializeDeviceSecurityStateEnvelope),
                    ]),
                  )
                  as BuiltList<InitializeDeviceSecurityStateEnvelope>;
          result.envelopes.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  CommitDeviceRotationRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = CommitDeviceRotationRequestBuilder();
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
