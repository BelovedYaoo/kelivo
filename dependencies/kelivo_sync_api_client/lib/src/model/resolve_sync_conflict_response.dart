//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/resolve_sync_conflict_response_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'resolve_sync_conflict_response.g.dart';

/// ResolveSyncConflictResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class ResolveSyncConflictResponse
    implements
        Built<ResolveSyncConflictResponse, ResolveSyncConflictResponseBuilder> {
  @BuiltValueField(wireName: r'data')
  ResolveSyncConflictResponseData get data;

  ResolveSyncConflictResponse._();

  factory ResolveSyncConflictResponse([
    void updates(ResolveSyncConflictResponseBuilder b),
  ]) = _$ResolveSyncConflictResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ResolveSyncConflictResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ResolveSyncConflictResponse> get serializer =>
      _$ResolveSyncConflictResponseSerializer();
}

class _$ResolveSyncConflictResponseSerializer
    implements PrimitiveSerializer<ResolveSyncConflictResponse> {
  @override
  final Iterable<Type> types = const [
    ResolveSyncConflictResponse,
    _$ResolveSyncConflictResponse,
  ];

  @override
  final String wireName = r'ResolveSyncConflictResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ResolveSyncConflictResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(ResolveSyncConflictResponseData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ResolveSyncConflictResponse object, {
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
    required ResolveSyncConflictResponseBuilder result,
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
                    specifiedType: const FullType(
                      ResolveSyncConflictResponseData,
                    ),
                  )
                  as ResolveSyncConflictResponseData;
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
  ResolveSyncConflictResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ResolveSyncConflictResponseBuilder();
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
