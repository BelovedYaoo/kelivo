//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/account_recovery_resume_commit_request_envelope.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'account_recovery_resume_commit_request.g.dart';

/// AccountRecoveryResumeCommitRequest
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
/// * [rekeyOperationId]
@BuiltValue()
abstract class AccountRecoveryResumeCommitRequest
    implements
        Built<
          AccountRecoveryResumeCommitRequest,
          AccountRecoveryResumeCommitRequestBuilder
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

  @BuiltValueField(wireName: r'rekeyOperationId')
  String get rekeyOperationId;

  AccountRecoveryResumeCommitRequest._();

  factory AccountRecoveryResumeCommitRequest([
    void updates(AccountRecoveryResumeCommitRequestBuilder b),
  ]) = _$AccountRecoveryResumeCommitRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(AccountRecoveryResumeCommitRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AccountRecoveryResumeCommitRequest> get serializer =>
      _$AccountRecoveryResumeCommitRequestSerializer();
}

class _$AccountRecoveryResumeCommitRequestSerializer
    implements PrimitiveSerializer<AccountRecoveryResumeCommitRequest> {
  @override
  final Iterable<Type> types = const [
    AccountRecoveryResumeCommitRequest,
    _$AccountRecoveryResumeCommitRequest,
  ];

  @override
  final String wireName = r'AccountRecoveryResumeCommitRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AccountRecoveryResumeCommitRequest object, {
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
    yield r'rekeyOperationId';
    yield serializers.serialize(
      object.rekeyOperationId,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    AccountRecoveryResumeCommitRequest object, {
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
    required AccountRecoveryResumeCommitRequestBuilder result,
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
        case r'rekeyOperationId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.rekeyOperationId = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  AccountRecoveryResumeCommitRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = AccountRecoveryResumeCommitRequestBuilder();
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
