//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/account_recovery_membership_commit_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'commit_account_recovery_replacement_response.g.dart';

/// CommitAccountRecoveryReplacementResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class CommitAccountRecoveryReplacementResponse
    implements
        Built<
          CommitAccountRecoveryReplacementResponse,
          CommitAccountRecoveryReplacementResponseBuilder
        > {
  @BuiltValueField(wireName: r'data')
  AccountRecoveryMembershipCommitData get data;

  CommitAccountRecoveryReplacementResponse._();

  factory CommitAccountRecoveryReplacementResponse([
    void updates(CommitAccountRecoveryReplacementResponseBuilder b),
  ]) = _$CommitAccountRecoveryReplacementResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(CommitAccountRecoveryReplacementResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<CommitAccountRecoveryReplacementResponse> get serializer =>
      _$CommitAccountRecoveryReplacementResponseSerializer();
}

class _$CommitAccountRecoveryReplacementResponseSerializer
    implements PrimitiveSerializer<CommitAccountRecoveryReplacementResponse> {
  @override
  final Iterable<Type> types = const [
    CommitAccountRecoveryReplacementResponse,
    _$CommitAccountRecoveryReplacementResponse,
  ];

  @override
  final String wireName = r'CommitAccountRecoveryReplacementResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    CommitAccountRecoveryReplacementResponse object, {
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
    CommitAccountRecoveryReplacementResponse object, {
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
    required CommitAccountRecoveryReplacementResponseBuilder result,
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
  CommitAccountRecoveryReplacementResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = CommitAccountRecoveryReplacementResponseBuilder();
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
