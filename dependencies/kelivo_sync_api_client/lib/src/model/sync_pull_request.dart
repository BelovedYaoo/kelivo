//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'sync_pull_request.g.dart';

/// SyncPullRequest
///
/// Properties:
/// * [cursor]
/// * [limit]
@BuiltValue()
abstract class SyncPullRequest
    implements Built<SyncPullRequest, SyncPullRequestBuilder> {
  @BuiltValueField(wireName: r'cursor')
  String? get cursor;

  @BuiltValueField(wireName: r'limit')
  int? get limit;

  SyncPullRequest._();

  factory SyncPullRequest([void updates(SyncPullRequestBuilder b)]) =
      _$SyncPullRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SyncPullRequestBuilder b) => b..limit = 100;

  @BuiltValueSerializer(custom: true)
  static Serializer<SyncPullRequest> get serializer =>
      _$SyncPullRequestSerializer();
}

class _$SyncPullRequestSerializer
    implements PrimitiveSerializer<SyncPullRequest> {
  @override
  final Iterable<Type> types = const [SyncPullRequest, _$SyncPullRequest];

  @override
  final String wireName = r'SyncPullRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    SyncPullRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    if (object.cursor != null) {
      yield r'cursor';
      yield serializers.serialize(
        object.cursor,
        specifiedType: const FullType.nullable(String),
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
    SyncPullRequest object, {
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
    required SyncPullRequestBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'cursor':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType.nullable(String),
                  )
                  as String?;
          if (valueDes == null) continue;
          result.cursor = valueDes;
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
  SyncPullRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SyncPullRequestBuilder();
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
