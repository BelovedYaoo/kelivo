//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'device_pairing_cancel_data.g.dart';

/// DevicePairingCancelData
///
/// Properties:
/// * [protocolVersion]
/// * [pairingId]
/// * [result]
/// * [cancelledAt]
@BuiltValue()
abstract class DevicePairingCancelData
    implements Built<DevicePairingCancelData, DevicePairingCancelDataBuilder> {
  @BuiltValueField(wireName: r'protocolVersion')
  int get protocolVersion;

  @BuiltValueField(wireName: r'pairingId')
  String get pairingId;

  @BuiltValueField(wireName: r'result')
  DevicePairingCancelDataResultEnum get result;
  // enum resultEnum {  cancelled,  };

  @BuiltValueField(wireName: r'cancelledAt')
  DateTime get cancelledAt;

  DevicePairingCancelData._();

  factory DevicePairingCancelData([
    void updates(DevicePairingCancelDataBuilder b),
  ]) = _$DevicePairingCancelData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DevicePairingCancelDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DevicePairingCancelData> get serializer =>
      _$DevicePairingCancelDataSerializer();
}

class _$DevicePairingCancelDataSerializer
    implements PrimitiveSerializer<DevicePairingCancelData> {
  @override
  final Iterable<Type> types = const [
    DevicePairingCancelData,
    _$DevicePairingCancelData,
  ];

  @override
  final String wireName = r'DevicePairingCancelData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DevicePairingCancelData object, {
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
    yield r'result';
    yield serializers.serialize(
      object.result,
      specifiedType: const FullType(DevicePairingCancelDataResultEnum),
    );
    yield r'cancelledAt';
    yield serializers.serialize(
      object.cancelledAt,
      specifiedType: const FullType(DateTime),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    DevicePairingCancelData object, {
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
    required DevicePairingCancelDataBuilder result,
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
        case r'result':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      DevicePairingCancelDataResultEnum,
                    ),
                  )
                  as DevicePairingCancelDataResultEnum;
          result.result = valueDes;
          break;
        case r'cancelledAt':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(DateTime),
                  )
                  as DateTime;
          result.cancelledAt = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  DevicePairingCancelData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DevicePairingCancelDataBuilder();
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

class DevicePairingCancelDataResultEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'cancelled')
  static const DevicePairingCancelDataResultEnum cancelled =
      _$devicePairingCancelDataResultEnum_cancelled;

  static Serializer<DevicePairingCancelDataResultEnum> get serializer =>
      _$devicePairingCancelDataResultEnumSerializer;

  const DevicePairingCancelDataResultEnum._(String name) : super(name);

  static BuiltSet<DevicePairingCancelDataResultEnum> get values =>
      _$devicePairingCancelDataResultEnumValues;
  static DevicePairingCancelDataResultEnum valueOf(String name) =>
      _$devicePairingCancelDataResultEnumValueOf(name);
}
