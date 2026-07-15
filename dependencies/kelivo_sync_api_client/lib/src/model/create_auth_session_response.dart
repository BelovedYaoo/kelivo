//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/auth_session_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'create_auth_session_response.g.dart';

/// CreateAuthSessionResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class CreateAuthSessionResponse
    implements
        Built<CreateAuthSessionResponse, CreateAuthSessionResponseBuilder> {
  @BuiltValueField(wireName: r'data')
  AuthSessionData get data;

  CreateAuthSessionResponse._();

  factory CreateAuthSessionResponse([
    void updates(CreateAuthSessionResponseBuilder b),
  ]) = _$CreateAuthSessionResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(CreateAuthSessionResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<CreateAuthSessionResponse> get serializer =>
      _$CreateAuthSessionResponseSerializer();
}

class _$CreateAuthSessionResponseSerializer
    implements PrimitiveSerializer<CreateAuthSessionResponse> {
  @override
  final Iterable<Type> types = const [
    CreateAuthSessionResponse,
    _$CreateAuthSessionResponse,
  ];

  @override
  final String wireName = r'CreateAuthSessionResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    CreateAuthSessionResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(AuthSessionData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    CreateAuthSessionResponse object, {
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
    required CreateAuthSessionResponseBuilder result,
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
                    specifiedType: const FullType(AuthSessionData),
                  )
                  as AuthSessionData;
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
  CreateAuthSessionResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = CreateAuthSessionResponseBuilder();
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
