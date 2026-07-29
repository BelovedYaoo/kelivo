//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/list_account_security_state_history_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'list_device_security_state_history_response.g.dart';

/// ListDeviceSecurityStateHistoryResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class ListDeviceSecurityStateHistoryResponse
    implements
        Built<
          ListDeviceSecurityStateHistoryResponse,
          ListDeviceSecurityStateHistoryResponseBuilder
        > {
  @BuiltValueField(wireName: r'data')
  ListAccountSecurityStateHistoryData get data;

  ListDeviceSecurityStateHistoryResponse._();

  factory ListDeviceSecurityStateHistoryResponse([
    void updates(ListDeviceSecurityStateHistoryResponseBuilder b),
  ]) = _$ListDeviceSecurityStateHistoryResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ListDeviceSecurityStateHistoryResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ListDeviceSecurityStateHistoryResponse> get serializer =>
      _$ListDeviceSecurityStateHistoryResponseSerializer();
}

class _$ListDeviceSecurityStateHistoryResponseSerializer
    implements PrimitiveSerializer<ListDeviceSecurityStateHistoryResponse> {
  @override
  final Iterable<Type> types = const [
    ListDeviceSecurityStateHistoryResponse,
    _$ListDeviceSecurityStateHistoryResponse,
  ];

  @override
  final String wireName = r'ListDeviceSecurityStateHistoryResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ListDeviceSecurityStateHistoryResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(ListAccountSecurityStateHistoryData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ListDeviceSecurityStateHistoryResponse object, {
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
    required ListDeviceSecurityStateHistoryResponseBuilder result,
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
                      ListAccountSecurityStateHistoryData,
                    ),
                  )
                  as ListAccountSecurityStateHistoryData;
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
  ListDeviceSecurityStateHistoryResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ListDeviceSecurityStateHistoryResponseBuilder();
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
