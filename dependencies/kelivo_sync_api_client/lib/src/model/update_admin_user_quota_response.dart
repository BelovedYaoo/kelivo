//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/update_admin_user_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'update_admin_user_quota_response.g.dart';

/// UpdateAdminUserQuotaResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class UpdateAdminUserQuotaResponse
    implements
        Built<
          UpdateAdminUserQuotaResponse,
          UpdateAdminUserQuotaResponseBuilder
        > {
  @BuiltValueField(wireName: r'data')
  UpdateAdminUserData get data;

  UpdateAdminUserQuotaResponse._();

  factory UpdateAdminUserQuotaResponse([
    void updates(UpdateAdminUserQuotaResponseBuilder b),
  ]) = _$UpdateAdminUserQuotaResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(UpdateAdminUserQuotaResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<UpdateAdminUserQuotaResponse> get serializer =>
      _$UpdateAdminUserQuotaResponseSerializer();
}

class _$UpdateAdminUserQuotaResponseSerializer
    implements PrimitiveSerializer<UpdateAdminUserQuotaResponse> {
  @override
  final Iterable<Type> types = const [
    UpdateAdminUserQuotaResponse,
    _$UpdateAdminUserQuotaResponse,
  ];

  @override
  final String wireName = r'UpdateAdminUserQuotaResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    UpdateAdminUserQuotaResponse object, {
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
    UpdateAdminUserQuotaResponse object, {
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
    required UpdateAdminUserQuotaResponseBuilder result,
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
  UpdateAdminUserQuotaResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = UpdateAdminUserQuotaResponseBuilder();
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
