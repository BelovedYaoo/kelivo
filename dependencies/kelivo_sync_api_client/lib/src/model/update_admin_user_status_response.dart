//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/update_admin_user_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'update_admin_user_status_response.g.dart';

/// UpdateAdminUserStatusResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class UpdateAdminUserStatusResponse
    implements
        Built<
          UpdateAdminUserStatusResponse,
          UpdateAdminUserStatusResponseBuilder
        > {
  @BuiltValueField(wireName: r'data')
  UpdateAdminUserData get data;

  UpdateAdminUserStatusResponse._();

  factory UpdateAdminUserStatusResponse([
    void updates(UpdateAdminUserStatusResponseBuilder b),
  ]) = _$UpdateAdminUserStatusResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(UpdateAdminUserStatusResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<UpdateAdminUserStatusResponse> get serializer =>
      _$UpdateAdminUserStatusResponseSerializer();
}

class _$UpdateAdminUserStatusResponseSerializer
    implements PrimitiveSerializer<UpdateAdminUserStatusResponse> {
  @override
  final Iterable<Type> types = const [
    UpdateAdminUserStatusResponse,
    _$UpdateAdminUserStatusResponse,
  ];

  @override
  final String wireName = r'UpdateAdminUserStatusResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    UpdateAdminUserStatusResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(UpdateAdminUserData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    UpdateAdminUserStatusResponse object, {
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
    required UpdateAdminUserStatusResponseBuilder result,
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
                    specifiedType: const FullType(UpdateAdminUserData),
                  )
                  as UpdateAdminUserData;
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
  UpdateAdminUserStatusResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = UpdateAdminUserStatusResponseBuilder();
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
