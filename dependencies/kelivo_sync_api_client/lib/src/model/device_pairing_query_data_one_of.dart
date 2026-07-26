//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/device_pairing_create_data_target_device.dart';
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'device_pairing_query_data_one_of.g.dart';

/// DevicePairingQueryDataOneOf
///
/// Properties:
/// * [protocolVersion]
/// * [pairingId]
/// * [accountContextId]
/// * [challenge]
/// * [expiresAt]
/// * [targetDevice]
/// * [status]
@BuiltValue()
abstract class DevicePairingQueryDataOneOf
    implements
        Built<DevicePairingQueryDataOneOf, DevicePairingQueryDataOneOfBuilder> {
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

  @BuiltValueField(wireName: r'status')
  DevicePairingQueryDataOneOfStatusEnum get status;
  // enum statusEnum {  pending,  };

  DevicePairingQueryDataOneOf._();

  factory DevicePairingQueryDataOneOf([
    void updates(DevicePairingQueryDataOneOfBuilder b),
  ]) = _$DevicePairingQueryDataOneOf;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DevicePairingQueryDataOneOfBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DevicePairingQueryDataOneOf> get serializer =>
      _$DevicePairingQueryDataOneOfSerializer();
}

class _$DevicePairingQueryDataOneOfSerializer
    implements PrimitiveSerializer<DevicePairingQueryDataOneOf> {
  @override
  final Iterable<Type> types = const [
    DevicePairingQueryDataOneOf,
    _$DevicePairingQueryDataOneOf,
  ];

  @override
  final String wireName = r'DevicePairingQueryDataOneOf';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DevicePairingQueryDataOneOf object, {
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
    yield r'status';
    yield serializers.serialize(
      object.status,
      specifiedType: const FullType(DevicePairingQueryDataOneOfStatusEnum),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    DevicePairingQueryDataOneOf object, {
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
    required DevicePairingQueryDataOneOfBuilder result,
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
        case r'status':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      DevicePairingQueryDataOneOfStatusEnum,
                    ),
                  )
                  as DevicePairingQueryDataOneOfStatusEnum;
          result.status = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  DevicePairingQueryDataOneOf deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DevicePairingQueryDataOneOfBuilder();
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

class DevicePairingQueryDataOneOfStatusEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'pending')
  static const DevicePairingQueryDataOneOfStatusEnum pending =
      _$devicePairingQueryDataOneOfStatusEnum_pending;

  static Serializer<DevicePairingQueryDataOneOfStatusEnum> get serializer =>
      _$devicePairingQueryDataOneOfStatusEnumSerializer;

  const DevicePairingQueryDataOneOfStatusEnum._(String name) : super(name);

  static BuiltSet<DevicePairingQueryDataOneOfStatusEnum> get values =>
      _$devicePairingQueryDataOneOfStatusEnumValues;
  static DevicePairingQueryDataOneOfStatusEnum valueOf(String name) =>
      _$devicePairingQueryDataOneOfStatusEnumValueOf(name);
}
