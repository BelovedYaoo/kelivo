//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'list_admin_devices_request.g.dart';

/// ListAdminDevicesRequest
///
/// Properties:
/// * [userId]
/// * [status]
/// * [pageIndex]
/// * [pageSize]
@BuiltValue()
abstract class ListAdminDevicesRequest
    implements Built<ListAdminDevicesRequest, ListAdminDevicesRequestBuilder> {
  @BuiltValueField(wireName: r'userId')
  String? get userId;

  @BuiltValueField(wireName: r'status')
  ListAdminDevicesRequestStatusEnum? get status;
  // enum statusEnum {  active,  revoked,  };

  @BuiltValueField(wireName: r'pageIndex')
  int? get pageIndex;

  @BuiltValueField(wireName: r'pageSize')
  int? get pageSize;

  ListAdminDevicesRequest._();

  factory ListAdminDevicesRequest([
    void updates(ListAdminDevicesRequestBuilder b),
  ]) = _$ListAdminDevicesRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ListAdminDevicesRequestBuilder b) => b
    ..pageIndex = 1
    ..pageSize = 20;

  @BuiltValueSerializer(custom: true)
  static Serializer<ListAdminDevicesRequest> get serializer =>
      _$ListAdminDevicesRequestSerializer();
}

class _$ListAdminDevicesRequestSerializer
    implements PrimitiveSerializer<ListAdminDevicesRequest> {
  @override
  final Iterable<Type> types = const [
    ListAdminDevicesRequest,
    _$ListAdminDevicesRequest,
  ];

  @override
  final String wireName = r'ListAdminDevicesRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ListAdminDevicesRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    if (object.userId != null) {
      yield r'userId';
      yield serializers.serialize(
        object.userId,
        specifiedType: const FullType(String),
      );
    }
    if (object.status != null) {
      yield r'status';
      yield serializers.serialize(
        object.status,
        specifiedType: const FullType(ListAdminDevicesRequestStatusEnum),
      );
    }
    if (object.pageIndex != null) {
      yield r'pageIndex';
      yield serializers.serialize(
        object.pageIndex,
        specifiedType: const FullType(int),
      );
    }
    if (object.pageSize != null) {
      yield r'pageSize';
      yield serializers.serialize(
        object.pageSize,
        specifiedType: const FullType(int),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    ListAdminDevicesRequest object, {
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
    required ListAdminDevicesRequestBuilder result,
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
                      ListAdminDevicesRequestStatusEnum,
                    ),
                  )
                  as ListAdminDevicesRequestStatusEnum;
          result.status = valueDes;
          break;
        case r'pageIndex':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.pageIndex = valueDes;
          break;
        case r'pageSize':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.pageSize = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ListAdminDevicesRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ListAdminDevicesRequestBuilder();
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

class ListAdminDevicesRequestStatusEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'active')
  static const ListAdminDevicesRequestStatusEnum active =
      _$listAdminDevicesRequestStatusEnum_active;
  @BuiltValueEnumConst(wireName: r'revoked')
  static const ListAdminDevicesRequestStatusEnum revoked =
      _$listAdminDevicesRequestStatusEnum_revoked;

  static Serializer<ListAdminDevicesRequestStatusEnum> get serializer =>
      _$listAdminDevicesRequestStatusEnumSerializer;

  const ListAdminDevicesRequestStatusEnum._(String name) : super(name);

  static BuiltSet<ListAdminDevicesRequestStatusEnum> get values =>
      _$listAdminDevicesRequestStatusEnumValues;
  static ListAdminDevicesRequestStatusEnum valueOf(String name) =>
      _$listAdminDevicesRequestStatusEnumValueOf(name);
}
