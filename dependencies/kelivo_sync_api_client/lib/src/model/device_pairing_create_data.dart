//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/device_pairing_create_data_target_device.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'device_pairing_create_data.g.dart';

/// DevicePairingCreateData
///
/// Properties:
/// * [protocolVersion]
/// * [pairingId]
/// * [accountContextId]
/// * [challenge]
/// * [expiresAt]
/// * [targetDevice]
@BuiltValue()
abstract class DevicePairingCreateData
    implements Built<DevicePairingCreateData, DevicePairingCreateDataBuilder> {
  @BuiltValueField(wireName: r'protocolVersion')
  int get protocolVersion;

  @BuiltValueField(wireName: r'pairingId')
  String get pairingId;

  @BuiltValueField(wireName: r'accountContextId')
  String get accountContextId;

  @BuiltValueField(wireName: r'challenge')
  String get challenge;

  @BuiltValueField(wireName: r'expiresAt')
  DateTime get expiresAt;

  @BuiltValueField(wireName: r'targetDevice')
  DevicePairingCreateDataTargetDevice get targetDevice;

  DevicePairingCreateData._();

  factory DevicePairingCreateData([
    void updates(DevicePairingCreateDataBuilder b),
  ]) = _$DevicePairingCreateData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DevicePairingCreateDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DevicePairingCreateData> get serializer =>
      _$DevicePairingCreateDataSerializer();
}

class _$DevicePairingCreateDataSerializer
    implements PrimitiveSerializer<DevicePairingCreateData> {
  @override
  final Iterable<Type> types = const [
    DevicePairingCreateData,
    _$DevicePairingCreateData,
  ];

  @override
  final String wireName = r'DevicePairingCreateData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DevicePairingCreateData object, {
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
    yield r'accountContextId';
    yield serializers.serialize(
      object.accountContextId,
      specifiedType: const FullType(String),
    );
    yield r'challenge';
    yield serializers.serialize(
      object.challenge,
      specifiedType: const FullType(String),
    );
    yield r'expiresAt';
    yield serializers.serialize(
      object.expiresAt,
      specifiedType: const FullType(DateTime),
    );
    yield r'targetDevice';
    yield serializers.serialize(
      object.targetDevice,
      specifiedType: const FullType(DevicePairingCreateDataTargetDevice),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    DevicePairingCreateData object, {
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
    required DevicePairingCreateDataBuilder result,
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
        case r'accountContextId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.accountContextId = valueDes;
          break;
        case r'challenge':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.challenge = valueDes;
          break;
        case r'expiresAt':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(DateTime),
                  )
                  as DateTime;
          result.expiresAt = valueDes;
          break;
        case r'targetDevice':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      DevicePairingCreateDataTargetDevice,
                    ),
                  )
                  as DevicePairingCreateDataTargetDevice;
          result.targetDevice.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  DevicePairingCreateData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DevicePairingCreateDataBuilder();
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
