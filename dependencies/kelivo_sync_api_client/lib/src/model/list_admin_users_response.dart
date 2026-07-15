//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/list_admin_users_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'list_admin_users_response.g.dart';

/// ListAdminUsersResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class ListAdminUsersResponse
    implements Built<ListAdminUsersResponse, ListAdminUsersResponseBuilder> {
  @BuiltValueField(wireName: r'data')
  ListAdminUsersData get data;

  ListAdminUsersResponse._();

  factory ListAdminUsersResponse([
    void updates(ListAdminUsersResponseBuilder b),
  ]) = _$ListAdminUsersResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ListAdminUsersResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ListAdminUsersResponse> get serializer =>
      _$ListAdminUsersResponseSerializer();
}

class _$ListAdminUsersResponseSerializer
    implements PrimitiveSerializer<ListAdminUsersResponse> {
  @override
  final Iterable<Type> types = const [
    ListAdminUsersResponse,
    _$ListAdminUsersResponse,
  ];

  @override
  final String wireName = r'ListAdminUsersResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ListAdminUsersResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(ListAdminUsersData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ListAdminUsersResponse object, {
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
    required ListAdminUsersResponseBuilder result,
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
                    specifiedType: const FullType(ListAdminUsersData),
                  )
                  as ListAdminUsersData;
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
  ListAdminUsersResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ListAdminUsersResponseBuilder();
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
