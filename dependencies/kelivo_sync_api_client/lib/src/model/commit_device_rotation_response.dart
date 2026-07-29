//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/commit_device_rotation_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'commit_device_rotation_response.g.dart';

/// CommitDeviceRotationResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class CommitDeviceRotationResponse
    implements
        Built<
          CommitDeviceRotationResponse,
          CommitDeviceRotationResponseBuilder
        > {
  @BuiltValueField(wireName: r'data')
  CommitDeviceRotationData get data;

  CommitDeviceRotationResponse._();

  factory CommitDeviceRotationResponse([
    void updates(CommitDeviceRotationResponseBuilder b),
  ]) = _$CommitDeviceRotationResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(CommitDeviceRotationResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<CommitDeviceRotationResponse> get serializer =>
      _$CommitDeviceRotationResponseSerializer();
}

class _$CommitDeviceRotationResponseSerializer
    implements PrimitiveSerializer<CommitDeviceRotationResponse> {
  @override
  final Iterable<Type> types = const [
    CommitDeviceRotationResponse,
    _$CommitDeviceRotationResponse,
  ];

  @override
  final String wireName = r'CommitDeviceRotationResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    CommitDeviceRotationResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(CommitDeviceRotationData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    CommitDeviceRotationResponse object, {
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
    required CommitDeviceRotationResponseBuilder result,
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
                    specifiedType: const FullType(CommitDeviceRotationData),
                  )
                  as CommitDeviceRotationData;
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
  CommitDeviceRotationResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = CommitDeviceRotationResponseBuilder();
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
