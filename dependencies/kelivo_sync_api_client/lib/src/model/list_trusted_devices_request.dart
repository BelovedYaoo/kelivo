//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'list_trusted_devices_request.g.dart';

/// ListTrustedDevicesRequest
///
/// Properties:
/// * [status]
/// * [pageIndex]
/// * [pageSize]
@BuiltValue()
abstract class ListTrustedDevicesRequest
    implements
        Built<ListTrustedDevicesRequest, ListTrustedDevicesRequestBuilder> {
  @BuiltValueField(wireName: r'status')
  ListTrustedDevicesRequestStatusEnum? get status;
  // enum statusEnum {  active,  revoked,  };

  @BuiltValueField(wireName: r'pageIndex')
  int? get pageIndex;

  @BuiltValueField(wireName: r'pageSize')
  int? get pageSize;

  ListTrustedDevicesRequest._();

  factory ListTrustedDevicesRequest([
    void updates(ListTrustedDevicesRequestBuilder b),
  ]) = _$ListTrustedDevicesRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ListTrustedDevicesRequestBuilder b) => b
    ..pageIndex = 1
    ..pageSize = 20;

  @BuiltValueSerializer(custom: true)
  static Serializer<ListTrustedDevicesRequest> get serializer =>
      _$ListTrustedDevicesRequestSerializer();
}

class _$ListTrustedDevicesRequestSerializer
    implements PrimitiveSerializer<ListTrustedDevicesRequest> {
  @override
  final Iterable<Type> types = const [
    ListTrustedDevicesRequest,
    _$ListTrustedDevicesRequest,
  ];

  @override
  final String wireName = r'ListTrustedDevicesRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ListTrustedDevicesRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    if (object.status != null) {
      yield r'status';
      yield serializers.serialize(
        object.status,
        specifiedType: const FullType(ListTrustedDevicesRequestStatusEnum),
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
    ListTrustedDevicesRequest object, {
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
    required ListTrustedDevicesRequestBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'status':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      ListTrustedDevicesRequestStatusEnum,
                    ),
                  )
                  as ListTrustedDevicesRequestStatusEnum;
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
  ListTrustedDevicesRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ListTrustedDevicesRequestBuilder();
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

class ListTrustedDevicesRequestStatusEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'active')
  static const ListTrustedDevicesRequestStatusEnum active =
      _$listTrustedDevicesRequestStatusEnum_active;
  @BuiltValueEnumConst(wireName: r'revoked')
  static const ListTrustedDevicesRequestStatusEnum revoked =
      _$listTrustedDevicesRequestStatusEnum_revoked;

  static Serializer<ListTrustedDevicesRequestStatusEnum> get serializer =>
      _$listTrustedDevicesRequestStatusEnumSerializer;

  const ListTrustedDevicesRequestStatusEnum._(String name) : super(name);

  static BuiltSet<ListTrustedDevicesRequestStatusEnum> get values =>
      _$listTrustedDevicesRequestStatusEnumValues;
  static ListTrustedDevicesRequestStatusEnum valueOf(String name) =>
      _$listTrustedDevicesRequestStatusEnumValueOf(name);
}
