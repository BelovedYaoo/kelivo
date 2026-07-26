//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'device_pairing_create_request.g.dart';

/// DevicePairingCreateRequest
///
/// Properties:
/// * [protocolVersion]
/// * [pairingId]
/// * [pairingSecretHash]
@BuiltValue()
abstract class DevicePairingCreateRequest
    implements
        Built<DevicePairingCreateRequest, DevicePairingCreateRequestBuilder> {
  @BuiltValueField(wireName: r'protocolVersion')
  int get protocolVersion;

  @BuiltValueField(wireName: r'pairingId')
  String get pairingId;

  @BuiltValueField(wireName: r'pairingSecretHash')
  String get pairingSecretHash;

  DevicePairingCreateRequest._();

  factory DevicePairingCreateRequest([
    void updates(DevicePairingCreateRequestBuilder b),
  ]) = _$DevicePairingCreateRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DevicePairingCreateRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DevicePairingCreateRequest> get serializer =>
      _$DevicePairingCreateRequestSerializer();
}

class _$DevicePairingCreateRequestSerializer
    implements PrimitiveSerializer<DevicePairingCreateRequest> {
  @override
  final Iterable<Type> types = const [
    DevicePairingCreateRequest,
    _$DevicePairingCreateRequest,
  ];

  @override
  final String wireName = r'DevicePairingCreateRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DevicePairingCreateRequest object, {
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
    yield r'pairingSecretHash';
    yield serializers.serialize(
      object.pairingSecretHash,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    DevicePairingCreateRequest object, {
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
    required DevicePairingCreateRequestBuilder result,
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
        case r'pairingSecretHash':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.pairingSecretHash = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  DevicePairingCreateRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DevicePairingCreateRequestBuilder();
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
