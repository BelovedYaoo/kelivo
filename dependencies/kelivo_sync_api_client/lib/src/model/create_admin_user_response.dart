//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/create_admin_user_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'create_admin_user_response.g.dart';

/// CreateAdminUserResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class CreateAdminUserResponse
    implements Built<CreateAdminUserResponse, CreateAdminUserResponseBuilder> {
  @BuiltValueField(wireName: r'data')
  CreateAdminUserData get data;

  CreateAdminUserResponse._();

  factory CreateAdminUserResponse([
    void updates(CreateAdminUserResponseBuilder b),
  ]) = _$CreateAdminUserResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(CreateAdminUserResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<CreateAdminUserResponse> get serializer =>
      _$CreateAdminUserResponseSerializer();
}

class _$CreateAdminUserResponseSerializer
    implements PrimitiveSerializer<CreateAdminUserResponse> {
  @override
  final Iterable<Type> types = const [
    CreateAdminUserResponse,
    _$CreateAdminUserResponse,
  ];

  @override
  final String wireName = r'CreateAdminUserResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    CreateAdminUserResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(CreateAdminUserData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    CreateAdminUserResponse object, {
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
    required CreateAdminUserResponseBuilder result,
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
                    specifiedType: const FullType(CreateAdminUserData),
                  )
                  as CreateAdminUserData;
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
  CreateAdminUserResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = CreateAdminUserResponseBuilder();
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
