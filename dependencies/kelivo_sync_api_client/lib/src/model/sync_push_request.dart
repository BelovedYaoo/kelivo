//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:kelivo_sync_api_client/src/model/sync_mutation.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'sync_push_request.g.dart';

/// 单批最多 10 条 mutation；所有 put 密文的解码字节总和不得超过 1 MiB，delete 按 0 字节计算
///
/// Properties:
/// * [mutations]
@BuiltValue()
abstract class SyncPushRequest
    implements Built<SyncPushRequest, SyncPushRequestBuilder> {
  @BuiltValueField(wireName: r'mutations')
  BuiltList<SyncMutation> get mutations;

  SyncPushRequest._();

  factory SyncPushRequest([void updates(SyncPushRequestBuilder b)]) =
      _$SyncPushRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SyncPushRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<SyncPushRequest> get serializer =>
      _$SyncPushRequestSerializer();
}

class _$SyncPushRequestSerializer
    implements PrimitiveSerializer<SyncPushRequest> {
  @override
  final Iterable<Type> types = const [SyncPushRequest, _$SyncPushRequest];

  @override
  final String wireName = r'SyncPushRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    SyncPushRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'mutations';
    yield serializers.serialize(
      object.mutations,
      specifiedType: const FullType(BuiltList, [FullType(SyncMutation)]),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    SyncPushRequest object, {
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
    required SyncPushRequestBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'mutations':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(BuiltList, [
                      FullType(SyncMutation),
                    ]),
                  )
                  as BuiltList<SyncMutation>;
          result.mutations.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  SyncPushRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SyncPushRequestBuilder();
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
