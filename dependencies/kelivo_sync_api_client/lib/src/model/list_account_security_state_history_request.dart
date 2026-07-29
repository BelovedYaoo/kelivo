//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'list_account_security_state_history_request.g.dart';

/// ListAccountSecurityStateHistoryRequest
///
/// Properties:
/// * [afterGeneration]
/// * [pageSize]
@BuiltValue()
abstract class ListAccountSecurityStateHistoryRequest
    implements
        Built<
          ListAccountSecurityStateHistoryRequest,
          ListAccountSecurityStateHistoryRequestBuilder
        > {
  @BuiltValueField(wireName: r'afterGeneration')
  int get afterGeneration;

  @BuiltValueField(wireName: r'pageSize')
  int get pageSize;

  ListAccountSecurityStateHistoryRequest._();

  factory ListAccountSecurityStateHistoryRequest([
    void updates(ListAccountSecurityStateHistoryRequestBuilder b),
  ]) = _$ListAccountSecurityStateHistoryRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ListAccountSecurityStateHistoryRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ListAccountSecurityStateHistoryRequest> get serializer =>
      _$ListAccountSecurityStateHistoryRequestSerializer();
}

class _$ListAccountSecurityStateHistoryRequestSerializer
    implements PrimitiveSerializer<ListAccountSecurityStateHistoryRequest> {
  @override
  final Iterable<Type> types = const [
    ListAccountSecurityStateHistoryRequest,
    _$ListAccountSecurityStateHistoryRequest,
  ];

  @override
  final String wireName = r'ListAccountSecurityStateHistoryRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ListAccountSecurityStateHistoryRequest object, {
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
  }

  @override
  Object serialize(
    Serializers serializers,
    ListAccountSecurityStateHistoryRequest object, {
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
    required ListAccountSecurityStateHistoryRequestBuilder result,
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
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ListAccountSecurityStateHistoryRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ListAccountSecurityStateHistoryRequestBuilder();
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
