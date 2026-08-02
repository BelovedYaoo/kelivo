//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/authenticated_session_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'authenticated_session_response.g.dart';

/// AuthenticatedSessionResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class AuthenticatedSessionResponse
    implements
        Built<
          AuthenticatedSessionResponse,
          AuthenticatedSessionResponseBuilder
        > {
  @BuiltValueField(wireName: r'data')
  AuthenticatedSessionData get data;

  AuthenticatedSessionResponse._();

  factory AuthenticatedSessionResponse([
    void updates(AuthenticatedSessionResponseBuilder b),
  ]) = _$AuthenticatedSessionResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(AuthenticatedSessionResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AuthenticatedSessionResponse> get serializer =>
      _$AuthenticatedSessionResponseSerializer();
}

class _$AuthenticatedSessionResponseSerializer
    implements PrimitiveSerializer<AuthenticatedSessionResponse> {
  @override
  final Iterable<Type> types = const [
    AuthenticatedSessionResponse,
    _$AuthenticatedSessionResponse,
  ];

  @override
  final String wireName = r'AuthenticatedSessionResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AuthenticatedSessionResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(AuthenticatedSessionData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    AuthenticatedSessionResponse object, {
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
    required AuthenticatedSessionResponseBuilder result,
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
                    specifiedType: const FullType(AuthenticatedSessionData),
                  )
                  as AuthenticatedSessionData;
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
  AuthenticatedSessionResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = AuthenticatedSessionResponseBuilder();
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
