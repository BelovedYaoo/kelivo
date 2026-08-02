//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'account_recovery_replacement_challenge_request.g.dart';

/// AccountRecoveryReplacementChallengeRequest
///
/// Properties:
/// * [protocolVersion]
/// * [challengeId]
/// * [expectedGeneration]
/// * [expectedKeyEpoch]
/// * [expectedMembershipManifestDigest]
/// * [expectedMembershipOperationId]
/// * [dataGeneration]
/// * [dataKeyEpoch]
/// * [sourceRekeyOperationId]
/// * [sourceCompletionProofDigest]
@BuiltValue()
abstract class AccountRecoveryReplacementChallengeRequest
    implements
        Built<
          AccountRecoveryReplacementChallengeRequest,
          AccountRecoveryReplacementChallengeRequestBuilder
        > {
  @BuiltValueField(wireName: r'protocolVersion')
  int get protocolVersion;

  @BuiltValueField(wireName: r'challengeId')
  String get challengeId;

  @BuiltValueField(wireName: r'expectedGeneration')
  int get expectedGeneration;

  @BuiltValueField(wireName: r'expectedKeyEpoch')
  int get expectedKeyEpoch;

  @BuiltValueField(wireName: r'expectedMembershipManifestDigest')
  String get expectedMembershipManifestDigest;

  @BuiltValueField(wireName: r'expectedMembershipOperationId')
  String get expectedMembershipOperationId;

  @BuiltValueField(wireName: r'dataGeneration')
  int get dataGeneration;

  @BuiltValueField(wireName: r'dataKeyEpoch')
  int get dataKeyEpoch;

  @BuiltValueField(wireName: r'sourceRekeyOperationId')
  String get sourceRekeyOperationId;

  @BuiltValueField(wireName: r'sourceCompletionProofDigest')
  String get sourceCompletionProofDigest;

  AccountRecoveryReplacementChallengeRequest._();

  factory AccountRecoveryReplacementChallengeRequest([
    void updates(AccountRecoveryReplacementChallengeRequestBuilder b),
  ]) = _$AccountRecoveryReplacementChallengeRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(AccountRecoveryReplacementChallengeRequestBuilder b) =>
      b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AccountRecoveryReplacementChallengeRequest>
  get serializer => _$AccountRecoveryReplacementChallengeRequestSerializer();
}

class _$AccountRecoveryReplacementChallengeRequestSerializer
    implements PrimitiveSerializer<AccountRecoveryReplacementChallengeRequest> {
  @override
  final Iterable<Type> types = const [
    AccountRecoveryReplacementChallengeRequest,
    _$AccountRecoveryReplacementChallengeRequest,
  ];

  @override
  final String wireName = r'AccountRecoveryReplacementChallengeRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AccountRecoveryReplacementChallengeRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'protocolVersion';
    yield serializers.serialize(
      object.protocolVersion,
      specifiedType: const FullType(int),
    );
    yield r'challengeId';
    yield serializers.serialize(
      object.challengeId,
      specifiedType: const FullType(String),
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
    yield r'expectedMembershipOperationId';
    yield serializers.serialize(
      object.expectedMembershipOperationId,
      specifiedType: const FullType(String),
    );
    yield r'dataGeneration';
    yield serializers.serialize(
      object.dataGeneration,
      specifiedType: const FullType(int),
    );
    yield r'dataKeyEpoch';
    yield serializers.serialize(
      object.dataKeyEpoch,
      specifiedType: const FullType(int),
    );
    yield r'sourceRekeyOperationId';
    yield serializers.serialize(
      object.sourceRekeyOperationId,
      specifiedType: const FullType(String),
    );
    yield r'sourceCompletionProofDigest';
    yield serializers.serialize(
      object.sourceCompletionProofDigest,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    AccountRecoveryReplacementChallengeRequest object, {
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
    required AccountRecoveryReplacementChallengeRequestBuilder result,
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
        case r'challengeId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.challengeId = valueDes;
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
        case r'expectedMembershipOperationId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.expectedMembershipOperationId = valueDes;
          break;
        case r'dataGeneration':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.dataGeneration = valueDes;
          break;
        case r'dataKeyEpoch':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.dataKeyEpoch = valueDes;
          break;
        case r'sourceRekeyOperationId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.sourceRekeyOperationId = valueDes;
          break;
        case r'sourceCompletionProofDigest':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.sourceCompletionProofDigest = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  AccountRecoveryReplacementChallengeRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = AccountRecoveryReplacementChallengeRequestBuilder();
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
