//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/reset_admin_user_password_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'reset_admin_user_password_response.g.dart';

/// ResetAdminUserPasswordResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class ResetAdminUserPasswordResponse
    implements
        Built<
          ResetAdminUserPasswordResponse,
          ResetAdminUserPasswordResponseBuilder
        > {
  @BuiltValueField(wireName: r'data')
  ResetAdminUserPasswordData get data;

  ResetAdminUserPasswordResponse._();

  factory ResetAdminUserPasswordResponse([
    void updates(ResetAdminUserPasswordResponseBuilder b),
  ]) = _$ResetAdminUserPasswordResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ResetAdminUserPasswordResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ResetAdminUserPasswordResponse> get serializer =>
      _$ResetAdminUserPasswordResponseSerializer();
}

class _$ResetAdminUserPasswordResponseSerializer
    implements PrimitiveSerializer<ResetAdminUserPasswordResponse> {
  @override
  final Iterable<Type> types = const [
    ResetAdminUserPasswordResponse,
    _$ResetAdminUserPasswordResponse,
  ];

  @override
  final String wireName = r'ResetAdminUserPasswordResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ResetAdminUserPasswordResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(ResetAdminUserPasswordData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ResetAdminUserPasswordResponse object, {
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
    required ResetAdminUserPasswordResponseBuilder result,
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
                    specifiedType: const FullType(ResetAdminUserPasswordData),
                  )
                  as ResetAdminUserPasswordData;
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
  ResetAdminUserPasswordResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ResetAdminUserPasswordResponseBuilder();
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
