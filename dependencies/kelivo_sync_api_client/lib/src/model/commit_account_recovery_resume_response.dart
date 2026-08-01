//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/account_recovery_membership_commit_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'commit_account_recovery_resume_response.g.dart';

/// CommitAccountRecoveryResumeResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class CommitAccountRecoveryResumeResponse
    implements
        Built<
          CommitAccountRecoveryResumeResponse,
          CommitAccountRecoveryResumeResponseBuilder
        > {
  @BuiltValueField(wireName: r'data')
  AccountRecoveryMembershipCommitData get data;

  CommitAccountRecoveryResumeResponse._();

  factory CommitAccountRecoveryResumeResponse([
    void updates(CommitAccountRecoveryResumeResponseBuilder b),
  ]) = _$CommitAccountRecoveryResumeResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(CommitAccountRecoveryResumeResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<CommitAccountRecoveryResumeResponse> get serializer =>
      _$CommitAccountRecoveryResumeResponseSerializer();
}

class _$CommitAccountRecoveryResumeResponseSerializer
    implements PrimitiveSerializer<CommitAccountRecoveryResumeResponse> {
  @override
  final Iterable<Type> types = const [
    CommitAccountRecoveryResumeResponse,
    _$CommitAccountRecoveryResumeResponse,
  ];

  @override
  final String wireName = r'CommitAccountRecoveryResumeResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    CommitAccountRecoveryResumeResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(AccountRecoveryMembershipCommitData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    CommitAccountRecoveryResumeResponse object, {
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
    required CommitAccountRecoveryResumeResponseBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'data':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      AccountRecoveryMembershipCommitData,
                    ),
                  )
                  as AccountRecoveryMembershipCommitData;
          result.data.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  CommitAccountRecoveryResumeResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = CommitAccountRecoveryResumeResponseBuilder();
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
