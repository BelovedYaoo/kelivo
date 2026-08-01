//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/account_recovery_state_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'get_account_recovery_state_response.g.dart';

/// GetAccountRecoveryStateResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class GetAccountRecoveryStateResponse
    implements
        Built<
          GetAccountRecoveryStateResponse,
          GetAccountRecoveryStateResponseBuilder
        > {
  @BuiltValueField(wireName: r'data')
  AccountRecoveryStateData get data;

  GetAccountRecoveryStateResponse._();

  factory GetAccountRecoveryStateResponse([
    void updates(GetAccountRecoveryStateResponseBuilder b),
  ]) = _$GetAccountRecoveryStateResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(GetAccountRecoveryStateResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<GetAccountRecoveryStateResponse> get serializer =>
      _$GetAccountRecoveryStateResponseSerializer();
}

class _$GetAccountRecoveryStateResponseSerializer
    implements PrimitiveSerializer<GetAccountRecoveryStateResponse> {
  @override
  final Iterable<Type> types = const [
    GetAccountRecoveryStateResponse,
    _$GetAccountRecoveryStateResponse,
  ];

  @override
  final String wireName = r'GetAccountRecoveryStateResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    GetAccountRecoveryStateResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(AccountRecoveryStateData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    GetAccountRecoveryStateResponse object, {
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
    required GetAccountRecoveryStateResponseBuilder result,
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
                    specifiedType: const FullType(AccountRecoveryStateData),
                  )
                  as AccountRecoveryStateData;
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
  GetAccountRecoveryStateResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = GetAccountRecoveryStateResponseBuilder();
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
