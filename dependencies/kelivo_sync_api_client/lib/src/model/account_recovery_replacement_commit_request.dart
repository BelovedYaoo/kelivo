//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/account_recovery_replacement_commit_request_authorization.dart';
import 'package:kelivo_sync_api_client/src/model/account_recovery_resume_commit_request_envelope.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'account_recovery_replacement_commit_request.g.dart';

/// AccountRecoveryReplacementCommitRequest
///
/// Properties:
/// * [protocolVersion]
/// * [expectedGeneration]
/// * [expectedKeyEpoch]
/// * [expectedMembershipManifestDigest]
/// * [operationId]
/// * [nextMembershipManifest]
/// * [nextMembershipManifestDigest]
/// * [envelope]
/// * [authorization]
/// * [nextRecoveryCapsuleVersion]
/// * [nextRecoveryCapsule]
/// * [completionSessionId]
/// * [completionSessionToken]
@BuiltValue()
abstract class AccountRecoveryReplacementCommitRequest
    implements
        Built<
          AccountRecoveryReplacementCommitRequest,
          AccountRecoveryReplacementCommitRequestBuilder
        > {
  @BuiltValueField(wireName: r'protocolVersion')
  int get protocolVersion;

  @BuiltValueField(wireName: r'expectedGeneration')
  int get expectedGeneration;

  @BuiltValueField(wireName: r'expectedKeyEpoch')
  int get expectedKeyEpoch;

  @BuiltValueField(wireName: r'expectedMembershipManifestDigest')
  String get expectedMembershipManifestDigest;

  @BuiltValueField(wireName: r'operationId')
  String get operationId;

  @BuiltValueField(wireName: r'nextMembershipManifest')
  String get nextMembershipManifest;

  @BuiltValueField(wireName: r'nextMembershipManifestDigest')
  String get nextMembershipManifestDigest;

  @BuiltValueField(wireName: r'envelope')
  AccountRecoveryResumeCommitRequestEnvelope get envelope;

  @BuiltValueField(wireName: r'authorization')
  AccountRecoveryReplacementCommitRequestAuthorization get authorization;

  @BuiltValueField(wireName: r'nextRecoveryCapsuleVersion')
  int get nextRecoveryCapsuleVersion;

  @BuiltValueField(wireName: r'nextRecoveryCapsule')
  String get nextRecoveryCapsule;

  @BuiltValueField(wireName: r'completionSessionId')
  String get completionSessionId;

  @BuiltValueField(wireName: r'completionSessionToken')
  String get completionSessionToken;

  AccountRecoveryReplacementCommitRequest._();

  factory AccountRecoveryReplacementCommitRequest([
    void updates(AccountRecoveryReplacementCommitRequestBuilder b),
  ]) = _$AccountRecoveryReplacementCommitRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(AccountRecoveryReplacementCommitRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AccountRecoveryReplacementCommitRequest> get serializer =>
      _$AccountRecoveryReplacementCommitRequestSerializer();
}

class _$AccountRecoveryReplacementCommitRequestSerializer
    implements PrimitiveSerializer<AccountRecoveryReplacementCommitRequest> {
  @override
  final Iterable<Type> types = const [
    AccountRecoveryReplacementCommitRequest,
    _$AccountRecoveryReplacementCommitRequest,
  ];

  @override
  final String wireName = r'AccountRecoveryReplacementCommitRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AccountRecoveryReplacementCommitRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'protocolVersion';
    yield serializers.serialize(
      object.protocolVersion,
      specifiedType: const FullType(int),
    );
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
    yield r'envelope';
    yield serializers.serialize(
      object.envelope,
      specifiedType: const FullType(AccountRecoveryResumeCommitRequestEnvelope),
    );
    yield r'authorization';
    yield serializers.serialize(
      object.authorization,
      specifiedType: const FullType(
        AccountRecoveryReplacementCommitRequestAuthorization,
      ),
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
    yield r'completionSessionId';
    yield serializers.serialize(
      object.completionSessionId,
      specifiedType: const FullType(String),
    );
    yield r'completionSessionToken';
    yield serializers.serialize(
      object.completionSessionToken,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    AccountRecoveryReplacementCommitRequest object, {
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
    required AccountRecoveryReplacementCommitRequestBuilder result,
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
        case r'envelope':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      AccountRecoveryResumeCommitRequestEnvelope,
                    ),
                  )
                  as AccountRecoveryResumeCommitRequestEnvelope;
          result.envelope.replace(valueDes);
          break;
        case r'authorization':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      AccountRecoveryReplacementCommitRequestAuthorization,
                    ),
                  )
                  as AccountRecoveryReplacementCommitRequestAuthorization;
          result.authorization.replace(valueDes);
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
        case r'completionSessionId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.completionSessionId = valueDes;
          break;
        case r'completionSessionToken':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.completionSessionToken = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  AccountRecoveryReplacementCommitRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = AccountRecoveryReplacementCommitRequestBuilder();
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
