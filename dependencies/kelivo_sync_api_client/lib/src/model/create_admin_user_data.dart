//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/admin_user_summary.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'create_admin_user_data.g.dart';

/// CreateAdminUserData
///
/// Properties:
/// * [user]
@BuiltValue()
abstract class CreateAdminUserData
    implements Built<CreateAdminUserData, CreateAdminUserDataBuilder> {
  @BuiltValueField(wireName: r'user')
  AdminUserSummary get user;

  CreateAdminUserData._();

  factory CreateAdminUserData([void updates(CreateAdminUserDataBuilder b)]) =
      _$CreateAdminUserData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(CreateAdminUserDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<CreateAdminUserData> get serializer =>
      _$CreateAdminUserDataSerializer();
}

class _$CreateAdminUserDataSerializer
    implements PrimitiveSerializer<CreateAdminUserData> {
  @override
  final Iterable<Type> types = const [
    CreateAdminUserData,
    _$CreateAdminUserData,
  ];

  @override
  final String wireName = r'CreateAdminUserData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    CreateAdminUserData object, {
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
    CreateAdminUserData object, {
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
    required CreateAdminUserDataBuilder result,
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
  CreateAdminUserData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = CreateAdminUserDataBuilder();
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
