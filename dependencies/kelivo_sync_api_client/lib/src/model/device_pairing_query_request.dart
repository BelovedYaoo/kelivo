//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'device_pairing_query_request.g.dart';

/// DevicePairingQueryRequest
///
/// Properties:
/// * [protocolVersion]
/// * [pairingId]
@BuiltValue()
abstract class DevicePairingQueryRequest
    implements
        Built<DevicePairingQueryRequest, DevicePairingQueryRequestBuilder> {
  @BuiltValueField(wireName: r'protocolVersion')
  int get protocolVersion;

  @BuiltValueField(wireName: r'pairingId')
  String get pairingId;

  DevicePairingQueryRequest._();

  factory DevicePairingQueryRequest([
    void updates(DevicePairingQueryRequestBuilder b),
  ]) = _$DevicePairingQueryRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DevicePairingQueryRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DevicePairingQueryRequest> get serializer =>
      _$DevicePairingQueryRequestSerializer();
}

class _$DevicePairingQueryRequestSerializer
    implements PrimitiveSerializer<DevicePairingQueryRequest> {
  @override
  final Iterable<Type> types = const [
    DevicePairingQueryRequest,
    _$DevicePairingQueryRequest,
  ];

  @override
  final String wireName = r'DevicePairingQueryRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DevicePairingQueryRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'protocolVersion';
    yield serializers.serialize(
      object.protocolVersion,
      specifiedType: const FullType(int),
    );
    yield r'pairingId';
    yield serializers.serialize(
      object.pairingId,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    DevicePairingQueryRequest object, {
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
    required DevicePairingQueryRequestBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'protocolVersion':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.protocolVersion = valueDes;
          break;
        case r'pairingId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.pairingId = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  DevicePairingQueryRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DevicePairingQueryRequestBuilder();
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
