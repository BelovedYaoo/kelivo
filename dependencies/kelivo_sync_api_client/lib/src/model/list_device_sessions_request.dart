//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'list_device_sessions_request.g.dart';

/// ListDeviceSessionsRequest
///
/// Properties:
/// * [status]
/// * [pageIndex]
/// * [pageSize]
@BuiltValue()
abstract class ListDeviceSessionsRequest
    implements
        Built<ListDeviceSessionsRequest, ListDeviceSessionsRequestBuilder> {
  @BuiltValueField(wireName: r'status')
  ListDeviceSessionsRequestStatusEnum? get status;
  // enum statusEnum {  active,  revoked,  };

  @BuiltValueField(wireName: r'pageIndex')
  int? get pageIndex;

  @BuiltValueField(wireName: r'pageSize')
  int? get pageSize;

  ListDeviceSessionsRequest._();

  factory ListDeviceSessionsRequest([
    void updates(ListDeviceSessionsRequestBuilder b),
  ]) = _$ListDeviceSessionsRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ListDeviceSessionsRequestBuilder b) => b
    ..pageIndex = 1
    ..pageSize = 20;

  @BuiltValueSerializer(custom: true)
  static Serializer<ListDeviceSessionsRequest> get serializer =>
      _$ListDeviceSessionsRequestSerializer();
}

class _$ListDeviceSessionsRequestSerializer
    implements PrimitiveSerializer<ListDeviceSessionsRequest> {
  @override
  final Iterable<Type> types = const [
    ListDeviceSessionsRequest,
    _$ListDeviceSessionsRequest,
  ];

  @override
  final String wireName = r'ListDeviceSessionsRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ListDeviceSessionsRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    if (object.status != null) {
      yield r'status';
      yield serializers.serialize(
        object.status,
        specifiedType: const FullType(ListDeviceSessionsRequestStatusEnum),
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
    ListDeviceSessionsRequest object, {
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
    required ListDeviceSessionsRequestBuilder result,
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
                      ListDeviceSessionsRequestStatusEnum,
                    ),
                  )
                  as ListDeviceSessionsRequestStatusEnum;
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
  ListDeviceSessionsRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ListDeviceSessionsRequestBuilder();
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

class ListDeviceSessionsRequestStatusEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'active')
  static const ListDeviceSessionsRequestStatusEnum active =
      _$listDeviceSessionsRequestStatusEnum_active;
  @BuiltValueEnumConst(wireName: r'revoked')
  static const ListDeviceSessionsRequestStatusEnum revoked =
      _$listDeviceSessionsRequestStatusEnum_revoked;

  static Serializer<ListDeviceSessionsRequestStatusEnum> get serializer =>
      _$listDeviceSessionsRequestStatusEnumSerializer;

  const ListDeviceSessionsRequestStatusEnum._(String name) : super(name);

  static BuiltSet<ListDeviceSessionsRequestStatusEnum> get values =>
      _$listDeviceSessionsRequestStatusEnumValues;
  static ListDeviceSessionsRequestStatusEnum valueOf(String name) =>
      _$listDeviceSessionsRequestStatusEnumValueOf(name);
}
