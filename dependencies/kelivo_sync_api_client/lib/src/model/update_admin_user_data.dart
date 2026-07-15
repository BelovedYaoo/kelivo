//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/admin_user_summary.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'update_admin_user_data.g.dart';

/// UpdateAdminUserData
///
/// Properties:
/// * [user]
@BuiltValue()
abstract class UpdateAdminUserData
    implements Built<UpdateAdminUserData, UpdateAdminUserDataBuilder> {
  @BuiltValueField(wireName: r'user')
  AdminUserSummary get user;

  UpdateAdminUserData._();

  factory UpdateAdminUserData([void updates(UpdateAdminUserDataBuilder b)]) =
      _$UpdateAdminUserData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(UpdateAdminUserDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<UpdateAdminUserData> get serializer =>
      _$UpdateAdminUserDataSerializer();
}

class _$UpdateAdminUserDataSerializer
    implements PrimitiveSerializer<UpdateAdminUserData> {
  @override
  final Iterable<Type> types = const [
    UpdateAdminUserData,
    _$UpdateAdminUserData,
  ];

  @override
  final String wireName = r'UpdateAdminUserData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    UpdateAdminUserData object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'user';
    yield serializers.serialize(
      object.user,
      specifiedType: const FullType(AdminUserSummary),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    UpdateAdminUserData object, {
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
    required UpdateAdminUserDataBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'user':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(AdminUserSummary),
                  )
                  as AdminUserSummary;
          result.user.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  UpdateAdminUserData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = UpdateAdminUserDataBuilder();
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
