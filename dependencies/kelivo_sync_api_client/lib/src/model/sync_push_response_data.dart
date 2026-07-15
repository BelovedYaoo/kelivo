//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:kelivo_sync_api_client/src/model/sync_mutation_result.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'sync_push_response_data.g.dart';

/// SyncPushResponseData
///
/// Properties:
/// * [results]
@BuiltValue()
abstract class SyncPushResponseData
    implements Built<SyncPushResponseData, SyncPushResponseDataBuilder> {
  @BuiltValueField(wireName: r'results')
  BuiltList<SyncMutationResult> get results;

  SyncPushResponseData._();

  factory SyncPushResponseData([void updates(SyncPushResponseDataBuilder b)]) =
      _$SyncPushResponseData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SyncPushResponseDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<SyncPushResponseData> get serializer =>
      _$SyncPushResponseDataSerializer();
}

class _$SyncPushResponseDataSerializer
    implements PrimitiveSerializer<SyncPushResponseData> {
  @override
  final Iterable<Type> types = const [
    SyncPushResponseData,
    _$SyncPushResponseData,
  ];

  @override
  final String wireName = r'SyncPushResponseData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    SyncPushResponseData object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'results';
    yield serializers.serialize(
      object.results,
      specifiedType: const FullType(BuiltList, [FullType(SyncMutationResult)]),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    SyncPushResponseData object, {
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
    required SyncPushResponseDataBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'results':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(BuiltList, [
                      FullType(SyncMutationResult),
                    ]),
                  )
                  as BuiltList<SyncMutationResult>;
          result.results.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  SyncPushResponseData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SyncPushResponseDataBuilder();
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
