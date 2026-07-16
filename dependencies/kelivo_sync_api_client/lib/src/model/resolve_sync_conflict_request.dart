//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'resolve_sync_conflict_request.g.dart';

/// ResolveSyncConflictRequest
///
/// Properties:
/// * [conflictId]
@BuiltValue()
abstract class ResolveSyncConflictRequest
    implements
        Built<ResolveSyncConflictRequest, ResolveSyncConflictRequestBuilder> {
  @BuiltValueField(wireName: r'conflictId')
  String get conflictId;

  ResolveSyncConflictRequest._();

  factory ResolveSyncConflictRequest([
    void updates(ResolveSyncConflictRequestBuilder b),
  ]) = _$ResolveSyncConflictRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ResolveSyncConflictRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ResolveSyncConflictRequest> get serializer =>
      _$ResolveSyncConflictRequestSerializer();
}

class _$ResolveSyncConflictRequestSerializer
    implements PrimitiveSerializer<ResolveSyncConflictRequest> {
  @override
  final Iterable<Type> types = const [
    ResolveSyncConflictRequest,
    _$ResolveSyncConflictRequest,
  ];

  @override
  final String wireName = r'ResolveSyncConflictRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ResolveSyncConflictRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'conflictId';
    yield serializers.serialize(
      object.conflictId,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ResolveSyncConflictRequest object, {
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
    required ResolveSyncConflictRequestBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'conflictId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.conflictId = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ResolveSyncConflictRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ResolveSyncConflictRequestBuilder();
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
