//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/account_recovery_history_list_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'list_account_recovery_history_response.g.dart';

/// ListAccountRecoveryHistoryResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class ListAccountRecoveryHistoryResponse
    implements
        Built<
          ListAccountRecoveryHistoryResponse,
          ListAccountRecoveryHistoryResponseBuilder
        > {
  @BuiltValueField(wireName: r'data')
  AccountRecoveryHistoryListData get data;

  ListAccountRecoveryHistoryResponse._();

  factory ListAccountRecoveryHistoryResponse([
    void updates(ListAccountRecoveryHistoryResponseBuilder b),
  ]) = _$ListAccountRecoveryHistoryResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ListAccountRecoveryHistoryResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ListAccountRecoveryHistoryResponse> get serializer =>
      _$ListAccountRecoveryHistoryResponseSerializer();
}

class _$ListAccountRecoveryHistoryResponseSerializer
    implements PrimitiveSerializer<ListAccountRecoveryHistoryResponse> {
  @override
  final Iterable<Type> types = const [
    ListAccountRecoveryHistoryResponse,
    _$ListAccountRecoveryHistoryResponse,
  ];

  @override
  final String wireName = r'ListAccountRecoveryHistoryResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ListAccountRecoveryHistoryResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(AccountRecoveryHistoryListData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ListAccountRecoveryHistoryResponse object, {
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
    required ListAccountRecoveryHistoryResponseBuilder result,
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
                      AccountRecoveryHistoryListData,
                    ),
                  )
                  as AccountRecoveryHistoryListData;
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
  ListAccountRecoveryHistoryResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ListAccountRecoveryHistoryResponseBuilder();
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
