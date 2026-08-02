//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/account_recovery_replacement_challenge_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'create_account_recovery_replacement_challenge_response.g.dart';

/// CreateAccountRecoveryReplacementChallengeResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class CreateAccountRecoveryReplacementChallengeResponse
    implements
        Built<
          CreateAccountRecoveryReplacementChallengeResponse,
          CreateAccountRecoveryReplacementChallengeResponseBuilder
        > {
  @BuiltValueField(wireName: r'data')
  AccountRecoveryReplacementChallengeData get data;

  CreateAccountRecoveryReplacementChallengeResponse._();

  factory CreateAccountRecoveryReplacementChallengeResponse([
    void updates(CreateAccountRecoveryReplacementChallengeResponseBuilder b),
  ]) = _$CreateAccountRecoveryReplacementChallengeResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(
    CreateAccountRecoveryReplacementChallengeResponseBuilder b,
  ) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<CreateAccountRecoveryReplacementChallengeResponse>
  get serializer =>
      _$CreateAccountRecoveryReplacementChallengeResponseSerializer();
}

class _$CreateAccountRecoveryReplacementChallengeResponseSerializer
    implements
        PrimitiveSerializer<CreateAccountRecoveryReplacementChallengeResponse> {
  @override
  final Iterable<Type> types = const [
    CreateAccountRecoveryReplacementChallengeResponse,
    _$CreateAccountRecoveryReplacementChallengeResponse,
  ];

  @override
  final String wireName = r'CreateAccountRecoveryReplacementChallengeResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    CreateAccountRecoveryReplacementChallengeResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(AccountRecoveryReplacementChallengeData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    CreateAccountRecoveryReplacementChallengeResponse object, {
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
    required CreateAccountRecoveryReplacementChallengeResponseBuilder result,
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
                      AccountRecoveryReplacementChallengeData,
                    ),
                  )
                  as AccountRecoveryReplacementChallengeData;
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
  CreateAccountRecoveryReplacementChallengeResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = CreateAccountRecoveryReplacementChallengeResponseBuilder();
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
