//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'list_sync_conflicts_request.g.dart';

/// ListSyncConflictsRequest
///
/// Properties:
/// * [state]
/// * [limit]
@BuiltValue()
abstract class ListSyncConflictsRequest
    implements
        Built<ListSyncConflictsRequest, ListSyncConflictsRequestBuilder> {
  @BuiltValueField(wireName: r'state')
  ListSyncConflictsRequestStateEnum? get state;
  // enum stateEnum {  open,  resolved,  };

  @BuiltValueField(wireName: r'limit')
  int? get limit;

  ListSyncConflictsRequest._();

  factory ListSyncConflictsRequest([
    void updates(ListSyncConflictsRequestBuilder b),
  ]) = _$ListSyncConflictsRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ListSyncConflictsRequestBuilder b) => b
    ..state = ListSyncConflictsRequestStateEnum.valueOf('open')
    ..limit = 100;

  @BuiltValueSerializer(custom: true)
  static Serializer<ListSyncConflictsRequest> get serializer =>
      _$ListSyncConflictsRequestSerializer();
}

class _$ListSyncConflictsRequestSerializer
    implements PrimitiveSerializer<ListSyncConflictsRequest> {
  @override
  final Iterable<Type> types = const [
    ListSyncConflictsRequest,
    _$ListSyncConflictsRequest,
  ];

  @override
  final String wireName = r'ListSyncConflictsRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ListSyncConflictsRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    if (object.state != null) {
      yield r'state';
      yield serializers.serialize(
        object.state,
        specifiedType: const FullType(ListSyncConflictsRequestStateEnum),
      );
    }
    if (object.limit != null) {
      yield r'limit';
      yield serializers.serialize(
        object.limit,
        specifiedType: const FullType(int),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    ListSyncConflictsRequest object, {
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
    required ListSyncConflictsRequestBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'state':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      ListSyncConflictsRequestStateEnum,
                    ),
                  )
                  as ListSyncConflictsRequestStateEnum;
          result.state = valueDes;
          break;
        case r'limit':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.limit = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ListSyncConflictsRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ListSyncConflictsRequestBuilder();
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

class ListSyncConflictsRequestStateEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'open')
  static const ListSyncConflictsRequestStateEnum open =
      _$listSyncConflictsRequestStateEnum_open;
  @BuiltValueEnumConst(wireName: r'resolved')
  static const ListSyncConflictsRequestStateEnum resolved =
      _$listSyncConflictsRequestStateEnum_resolved;

  static Serializer<ListSyncConflictsRequestStateEnum> get serializer =>
      _$listSyncConflictsRequestStateEnumSerializer;

  const ListSyncConflictsRequestStateEnum._(String name) : super(name);

  static BuiltSet<ListSyncConflictsRequestStateEnum> get values =>
      _$listSyncConflictsRequestStateEnumValues;
  static ListSyncConflictsRequestStateEnum valueOf(String name) =>
      _$listSyncConflictsRequestStateEnumValueOf(name);
}
