//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'update_admin_user_status_request.g.dart';

/// UpdateAdminUserStatusRequest
///
/// Properties:
/// * [userId]
/// * [status]
@BuiltValue()
abstract class UpdateAdminUserStatusRequest
    implements
        Built<
          UpdateAdminUserStatusRequest,
          UpdateAdminUserStatusRequestBuilder
        > {
  @BuiltValueField(wireName: r'userId')
  String get userId;

  @BuiltValueField(wireName: r'status')
  UpdateAdminUserStatusRequestStatusEnum get status;
  // enum statusEnum {  active,  disabled,  };

  UpdateAdminUserStatusRequest._();

  factory UpdateAdminUserStatusRequest([
    void updates(UpdateAdminUserStatusRequestBuilder b),
  ]) = _$UpdateAdminUserStatusRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(UpdateAdminUserStatusRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<UpdateAdminUserStatusRequest> get serializer =>
      _$UpdateAdminUserStatusRequestSerializer();
}

class _$UpdateAdminUserStatusRequestSerializer
    implements PrimitiveSerializer<UpdateAdminUserStatusRequest> {
  @override
  final Iterable<Type> types = const [
    UpdateAdminUserStatusRequest,
    _$UpdateAdminUserStatusRequest,
  ];

  @override
  final String wireName = r'UpdateAdminUserStatusRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    UpdateAdminUserStatusRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'userId';
    yield serializers.serialize(
      object.userId,
      specifiedType: const FullType(String),
    );
    yield r'status';
    yield serializers.serialize(
      object.status,
      specifiedType: const FullType(UpdateAdminUserStatusRequestStatusEnum),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    UpdateAdminUserStatusRequest object, {
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
    required UpdateAdminUserStatusRequestBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'userId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.userId = valueDes;
          break;
        case r'status':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      UpdateAdminUserStatusRequestStatusEnum,
                    ),
                  )
                  as UpdateAdminUserStatusRequestStatusEnum;
          result.status = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  UpdateAdminUserStatusRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = UpdateAdminUserStatusRequestBuilder();
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

class UpdateAdminUserStatusRequestStatusEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'active')
  static const UpdateAdminUserStatusRequestStatusEnum active =
      _$updateAdminUserStatusRequestStatusEnum_active;
  @BuiltValueEnumConst(wireName: r'disabled')
  static const UpdateAdminUserStatusRequestStatusEnum disabled =
      _$updateAdminUserStatusRequestStatusEnum_disabled;

  static Serializer<UpdateAdminUserStatusRequestStatusEnum> get serializer =>
      _$updateAdminUserStatusRequestStatusEnumSerializer;

  const UpdateAdminUserStatusRequestStatusEnum._(String name) : super(name);

  static BuiltSet<UpdateAdminUserStatusRequestStatusEnum> get values =>
      _$updateAdminUserStatusRequestStatusEnumValues;
  static UpdateAdminUserStatusRequestStatusEnum valueOf(String name) =>
      _$updateAdminUserStatusRequestStatusEnumValueOf(name);
}
