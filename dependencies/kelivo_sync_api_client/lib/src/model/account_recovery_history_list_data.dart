//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/account_security_state_current_projection.dart';
import 'package:built_collection/built_collection.dart';
import 'package:kelivo_sync_api_client/src/model/account_security_state_history_item.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'account_recovery_history_list_data.g.dart';

/// AccountRecoveryHistoryListData
///
/// Properties:
/// * [items]
/// * [afterGeneration]
/// * [nextAfterGeneration]
/// * [pageSize]
/// * [hasMore]
/// * [currentState]
@BuiltValue()
abstract class AccountRecoveryHistoryListData
    implements
        Built<
          AccountRecoveryHistoryListData,
          AccountRecoveryHistoryListDataBuilder
        > {
  @BuiltValueField(wireName: r'items')
  BuiltList<AccountSecurityStateHistoryItem> get items;

  @BuiltValueField(wireName: r'afterGeneration')
  int get afterGeneration;

  @BuiltValueField(wireName: r'nextAfterGeneration')
  int get nextAfterGeneration;

  @BuiltValueField(wireName: r'pageSize')
  int get pageSize;

  @BuiltValueField(wireName: r'hasMore')
  bool get hasMore;

  @BuiltValueField(wireName: r'currentState')
  AccountSecurityStateCurrentProjection get currentState;

  AccountRecoveryHistoryListData._();

  factory AccountRecoveryHistoryListData([
    void updates(AccountRecoveryHistoryListDataBuilder b),
  ]) = _$AccountRecoveryHistoryListData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(AccountRecoveryHistoryListDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AccountRecoveryHistoryListData> get serializer =>
      _$AccountRecoveryHistoryListDataSerializer();
}

class _$AccountRecoveryHistoryListDataSerializer
    implements PrimitiveSerializer<AccountRecoveryHistoryListData> {
  @override
  final Iterable<Type> types = const [
    AccountRecoveryHistoryListData,
    _$AccountRecoveryHistoryListData,
  ];

  @override
  final String wireName = r'AccountRecoveryHistoryListData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AccountRecoveryHistoryListData object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'items';
    yield serializers.serialize(
      object.items,
      specifiedType: const FullType(BuiltList, [
        FullType(AccountSecurityStateHistoryItem),
      ]),
    );
    yield r'afterGeneration';
    yield serializers.serialize(
      object.afterGeneration,
      specifiedType: const FullType(int),
    );
    yield r'nextAfterGeneration';
    yield serializers.serialize(
      object.nextAfterGeneration,
      specifiedType: const FullType(int),
    );
    yield r'pageSize';
    yield serializers.serialize(
      object.pageSize,
      specifiedType: const FullType(int),
    );
    yield r'hasMore';
    yield serializers.serialize(
      object.hasMore,
      specifiedType: const FullType(bool),
    );
    yield r'currentState';
    yield serializers.serialize(
      object.currentState,
      specifiedType: const FullType(AccountSecurityStateCurrentProjection),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    AccountRecoveryHistoryListData object, {
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
    required AccountRecoveryHistoryListDataBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'items':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(BuiltList, [
                      FullType(AccountSecurityStateHistoryItem),
                    ]),
                  )
                  as BuiltList<AccountSecurityStateHistoryItem>;
          result.items.replace(valueDes);
          break;
        case r'afterGeneration':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.afterGeneration = valueDes;
          break;
        case r'nextAfterGeneration':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.nextAfterGeneration = valueDes;
          break;
        case r'pageSize':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.pageSize = valueDes;
          break;
        case r'hasMore':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(bool),
                  )
                  as bool;
          result.hasMore = valueDes;
          break;
        case r'currentState':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      AccountSecurityStateCurrentProjection,
                    ),
                  )
                  as AccountSecurityStateCurrentProjection;
          result.currentState.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  AccountRecoveryHistoryListData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = AccountRecoveryHistoryListDataBuilder();
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
