//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:kelivo_sync_api_client/src/model/account_security_state_history_item.dart';
import 'package:kelivo_sync_api_client/src/model/data_rekey_completion_proof_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'self_revocation_status_data_one_of1_receipt.g.dart';

/// SelfRevocationStatusDataOneOf1Receipt
///
/// Properties:
/// * [securityStates]
/// * [completion]
@BuiltValue()
abstract class SelfRevocationStatusDataOneOf1Receipt
    implements
        Built<
          SelfRevocationStatusDataOneOf1Receipt,
          SelfRevocationStatusDataOneOf1ReceiptBuilder
        > {
  @BuiltValueField(wireName: r'securityStates')
  BuiltList<AccountSecurityStateHistoryItem> get securityStates;

  @BuiltValueField(wireName: r'completion')
  DataRekeyCompletionProofData get completion;

  SelfRevocationStatusDataOneOf1Receipt._();

  factory SelfRevocationStatusDataOneOf1Receipt([
    void updates(SelfRevocationStatusDataOneOf1ReceiptBuilder b),
  ]) = _$SelfRevocationStatusDataOneOf1Receipt;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SelfRevocationStatusDataOneOf1ReceiptBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<SelfRevocationStatusDataOneOf1Receipt> get serializer =>
      _$SelfRevocationStatusDataOneOf1ReceiptSerializer();
}

class _$SelfRevocationStatusDataOneOf1ReceiptSerializer
    implements PrimitiveSerializer<SelfRevocationStatusDataOneOf1Receipt> {
  @override
  final Iterable<Type> types = const [
    SelfRevocationStatusDataOneOf1Receipt,
    _$SelfRevocationStatusDataOneOf1Receipt,
  ];

  @override
  final String wireName = r'SelfRevocationStatusDataOneOf1Receipt';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    SelfRevocationStatusDataOneOf1Receipt object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'securityStates';
    yield serializers.serialize(
      object.securityStates,
      specifiedType: const FullType(BuiltList, [
        FullType(AccountSecurityStateHistoryItem),
      ]),
    );
    yield r'completion';
    yield serializers.serialize(
      object.completion,
      specifiedType: const FullType(DataRekeyCompletionProofData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    SelfRevocationStatusDataOneOf1Receipt object, {
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
    required SelfRevocationStatusDataOneOf1ReceiptBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'securityStates':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(BuiltList, [
                      FullType(AccountSecurityStateHistoryItem),
                    ]),
                  )
                  as BuiltList<AccountSecurityStateHistoryItem>;
          result.securityStates.replace(valueDes);
          break;
        case r'completion':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(DataRekeyCompletionProofData),
                  )
                  as DataRekeyCompletionProofData;
          result.completion.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  SelfRevocationStatusDataOneOf1Receipt deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SelfRevocationStatusDataOneOf1ReceiptBuilder();
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
