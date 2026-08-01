//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'account_recovery_history_list_request.g.dart';

/// AccountRecoveryHistoryListRequest
///
/// Properties:
/// * [afterGeneration]
/// * [pageSize]
/// * [attemptId]
/// * [challengeRequestDigest]
@BuiltValue()
abstract class AccountRecoveryHistoryListRequest
    implements
        Built<
          AccountRecoveryHistoryListRequest,
          AccountRecoveryHistoryListRequestBuilder
        > {
  @BuiltValueField(wireName: r'afterGeneration')
  int get afterGeneration;

  @BuiltValueField(wireName: r'pageSize')
  int get pageSize;

  @BuiltValueField(wireName: r'attemptId')
  String get attemptId;

  @BuiltValueField(wireName: r'challengeRequestDigest')
  String get challengeRequestDigest;

  AccountRecoveryHistoryListRequest._();

  factory AccountRecoveryHistoryListRequest([
    void updates(AccountRecoveryHistoryListRequestBuilder b),
  ]) = _$AccountRecoveryHistoryListRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(AccountRecoveryHistoryListRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AccountRecoveryHistoryListRequest> get serializer =>
      _$AccountRecoveryHistoryListRequestSerializer();
}

class _$AccountRecoveryHistoryListRequestSerializer
    implements PrimitiveSerializer<AccountRecoveryHistoryListRequest> {
  @override
  final Iterable<Type> types = const [
    AccountRecoveryHistoryListRequest,
    _$AccountRecoveryHistoryListRequest,
  ];

  @override
  final String wireName = r'AccountRecoveryHistoryListRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AccountRecoveryHistoryListRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'afterGeneration';
    yield serializers.serialize(
      object.afterGeneration,
      specifiedType: const FullType(int),
    );
    yield r'pageSize';
    yield serializers.serialize(
      object.pageSize,
      specifiedType: const FullType(int),
    );
    yield r'attemptId';
    yield serializers.serialize(
      object.attemptId,
      specifiedType: const FullType(String),
    );
    yield r'challengeRequestDigest';
    yield serializers.serialize(
      object.challengeRequestDigest,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    AccountRecoveryHistoryListRequest object, {
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
    required AccountRecoveryHistoryListRequestBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'afterGeneration':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.afterGeneration = valueDes;
          break;
        case r'pageSize':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.pageSize = valueDes;
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
        case r'challengeRequestDigest':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.challengeRequestDigest = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  AccountRecoveryHistoryListRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = AccountRecoveryHistoryListRequestBuilder();
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
