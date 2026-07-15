//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/update_auth_password_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'update_auth_password_response.g.dart';

/// UpdateAuthPasswordResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class UpdateAuthPasswordResponse
    implements
        Built<UpdateAuthPasswordResponse, UpdateAuthPasswordResponseBuilder> {
  @BuiltValueField(wireName: r'data')
  UpdateAuthPasswordData get data;

  UpdateAuthPasswordResponse._();

  factory UpdateAuthPasswordResponse([
    void updates(UpdateAuthPasswordResponseBuilder b),
  ]) = _$UpdateAuthPasswordResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(UpdateAuthPasswordResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<UpdateAuthPasswordResponse> get serializer =>
      _$UpdateAuthPasswordResponseSerializer();
}

class _$UpdateAuthPasswordResponseSerializer
    implements PrimitiveSerializer<UpdateAuthPasswordResponse> {
  @override
  final Iterable<Type> types = const [
    UpdateAuthPasswordResponse,
    _$UpdateAuthPasswordResponse,
  ];

  @override
  final String wireName = r'UpdateAuthPasswordResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    UpdateAuthPasswordResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(UpdateAuthPasswordData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    UpdateAuthPasswordResponse object, {
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
    required UpdateAuthPasswordResponseBuilder result,
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
                    specifiedType: const FullType(UpdateAuthPasswordData),
                  )
                  as UpdateAuthPasswordData;
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
  UpdateAuthPasswordResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = UpdateAuthPasswordResponseBuilder();
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
