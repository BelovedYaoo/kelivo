//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/account_recovery_attempt_start_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'start_account_recovery_attempt_response.g.dart';

/// StartAccountRecoveryAttemptResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class StartAccountRecoveryAttemptResponse
    implements
        Built<
          StartAccountRecoveryAttemptResponse,
          StartAccountRecoveryAttemptResponseBuilder
        > {
  @BuiltValueField(wireName: r'data')
  AccountRecoveryAttemptStartData get data;

  StartAccountRecoveryAttemptResponse._();

  factory StartAccountRecoveryAttemptResponse([
    void updates(StartAccountRecoveryAttemptResponseBuilder b),
  ]) = _$StartAccountRecoveryAttemptResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(StartAccountRecoveryAttemptResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<StartAccountRecoveryAttemptResponse> get serializer =>
      _$StartAccountRecoveryAttemptResponseSerializer();
}

class _$StartAccountRecoveryAttemptResponseSerializer
    implements PrimitiveSerializer<StartAccountRecoveryAttemptResponse> {
  @override
  final Iterable<Type> types = const [
    StartAccountRecoveryAttemptResponse,
    _$StartAccountRecoveryAttemptResponse,
  ];

  @override
  final String wireName = r'StartAccountRecoveryAttemptResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    StartAccountRecoveryAttemptResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(AccountRecoveryAttemptStartData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    StartAccountRecoveryAttemptResponse object, {
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
    required StartAccountRecoveryAttemptResponseBuilder result,
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
                      AccountRecoveryAttemptStartData,
                    ),
                  )
                  as AccountRecoveryAttemptStartData;
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
  StartAccountRecoveryAttemptResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = StartAccountRecoveryAttemptResponseBuilder();
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
