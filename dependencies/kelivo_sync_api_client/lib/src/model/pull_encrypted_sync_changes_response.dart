//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/sync_pull_response_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'pull_encrypted_sync_changes_response.g.dart';

/// PullEncryptedSyncChangesResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class PullEncryptedSyncChangesResponse
    implements
        Built<
          PullEncryptedSyncChangesResponse,
          PullEncryptedSyncChangesResponseBuilder
        > {
  @BuiltValueField(wireName: r'data')
  SyncPullResponseData get data;

  PullEncryptedSyncChangesResponse._();

  factory PullEncryptedSyncChangesResponse([
    void updates(PullEncryptedSyncChangesResponseBuilder b),
  ]) = _$PullEncryptedSyncChangesResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(PullEncryptedSyncChangesResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<PullEncryptedSyncChangesResponse> get serializer =>
      _$PullEncryptedSyncChangesResponseSerializer();
}

class _$PullEncryptedSyncChangesResponseSerializer
    implements PrimitiveSerializer<PullEncryptedSyncChangesResponse> {
  @override
  final Iterable<Type> types = const [
    PullEncryptedSyncChangesResponse,
    _$PullEncryptedSyncChangesResponse,
  ];

  @override
  final String wireName = r'PullEncryptedSyncChangesResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    PullEncryptedSyncChangesResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(SyncPullResponseData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    PullEncryptedSyncChangesResponse object, {
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
    required PullEncryptedSyncChangesResponseBuilder result,
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
                    specifiedType: const FullType(SyncPullResponseData),
                  )
                  as SyncPullResponseData;
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
  PullEncryptedSyncChangesResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = PullEncryptedSyncChangesResponseBuilder();
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
