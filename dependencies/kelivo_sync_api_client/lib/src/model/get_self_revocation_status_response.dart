//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/self_revocation_status_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'get_self_revocation_status_response.g.dart';

/// GetSelfRevocationStatusResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class GetSelfRevocationStatusResponse
    implements
        Built<
          GetSelfRevocationStatusResponse,
          GetSelfRevocationStatusResponseBuilder
        > {
  @BuiltValueField(wireName: r'data')
  SelfRevocationStatusData get data;

  GetSelfRevocationStatusResponse._();

  factory GetSelfRevocationStatusResponse([
    void updates(GetSelfRevocationStatusResponseBuilder b),
  ]) = _$GetSelfRevocationStatusResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(GetSelfRevocationStatusResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<GetSelfRevocationStatusResponse> get serializer =>
      _$GetSelfRevocationStatusResponseSerializer();
}

class _$GetSelfRevocationStatusResponseSerializer
    implements PrimitiveSerializer<GetSelfRevocationStatusResponse> {
  @override
  final Iterable<Type> types = const [
    GetSelfRevocationStatusResponse,
    _$GetSelfRevocationStatusResponse,
  ];

  @override
  final String wireName = r'GetSelfRevocationStatusResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    GetSelfRevocationStatusResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(SelfRevocationStatusData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    GetSelfRevocationStatusResponse object, {
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
    required GetSelfRevocationStatusResponseBuilder result,
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
                    specifiedType: const FullType(SelfRevocationStatusData),
                  )
                  as SelfRevocationStatusData;
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
  GetSelfRevocationStatusResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = GetSelfRevocationStatusResponseBuilder();
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
