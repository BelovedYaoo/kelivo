//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/sync_conflict.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'resolve_sync_conflict_response_data.g.dart';

/// ResolveSyncConflictResponseData
///
/// Properties:
/// * [conflict]
@BuiltValue()
abstract class ResolveSyncConflictResponseData
    implements
        Built<
          ResolveSyncConflictResponseData,
          ResolveSyncConflictResponseDataBuilder
        > {
  @BuiltValueField(wireName: r'conflict')
  SyncConflict get conflict;

  ResolveSyncConflictResponseData._();

  factory ResolveSyncConflictResponseData([
    void updates(ResolveSyncConflictResponseDataBuilder b),
  ]) = _$ResolveSyncConflictResponseData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ResolveSyncConflictResponseDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ResolveSyncConflictResponseData> get serializer =>
      _$ResolveSyncConflictResponseDataSerializer();
}

class _$ResolveSyncConflictResponseDataSerializer
    implements PrimitiveSerializer<ResolveSyncConflictResponseData> {
  @override
  final Iterable<Type> types = const [
    ResolveSyncConflictResponseData,
    _$ResolveSyncConflictResponseData,
  ];

  @override
  final String wireName = r'ResolveSyncConflictResponseData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ResolveSyncConflictResponseData object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'conflict';
    yield serializers.serialize(
      object.conflict,
      specifiedType: const FullType(SyncConflict),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ResolveSyncConflictResponseData object, {
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
    required ResolveSyncConflictResponseDataBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'conflict':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(SyncConflict),
                  )
                  as SyncConflict;
          result.conflict.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ResolveSyncConflictResponseData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ResolveSyncConflictResponseDataBuilder();
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
