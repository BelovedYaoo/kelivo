//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/self_revocation_request_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'create_self_revocation_response.g.dart';

/// CreateSelfRevocationResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class CreateSelfRevocationResponse
    implements
        Built<
          CreateSelfRevocationResponse,
          CreateSelfRevocationResponseBuilder
        > {
  @BuiltValueField(wireName: r'data')
  SelfRevocationRequestData get data;

  CreateSelfRevocationResponse._();

  factory CreateSelfRevocationResponse([
    void updates(CreateSelfRevocationResponseBuilder b),
  ]) = _$CreateSelfRevocationResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(CreateSelfRevocationResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<CreateSelfRevocationResponse> get serializer =>
      _$CreateSelfRevocationResponseSerializer();
}

class _$CreateSelfRevocationResponseSerializer
    implements PrimitiveSerializer<CreateSelfRevocationResponse> {
  @override
  final Iterable<Type> types = const [
    CreateSelfRevocationResponse,
    _$CreateSelfRevocationResponse,
  ];

  @override
  final String wireName = r'CreateSelfRevocationResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    CreateSelfRevocationResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(SelfRevocationRequestData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    CreateSelfRevocationResponse object, {
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
    required CreateSelfRevocationResponseBuilder result,
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
                    specifiedType: const FullType(SelfRevocationRequestData),
                  )
                  as SelfRevocationRequestData;
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
  CreateSelfRevocationResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = CreateSelfRevocationResponseBuilder();
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
