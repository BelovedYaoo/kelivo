//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'device_pairing_approve_data.g.dart';

/// DevicePairingApproveData
///
/// Properties:
/// * [protocolVersion]
/// * [pairingId]
/// * [result]
/// * [approvedAt]
@BuiltValue()
abstract class DevicePairingApproveData
    implements
        Built<DevicePairingApproveData, DevicePairingApproveDataBuilder> {
  @BuiltValueField(wireName: r'protocolVersion')
  int get protocolVersion;

  @BuiltValueField(wireName: r'pairingId')
  String get pairingId;

  @BuiltValueField(wireName: r'result')
  DevicePairingApproveDataResultEnum get result;
  // enum resultEnum {  approved,  };

  @BuiltValueField(wireName: r'approvedAt')
  DateTime get approvedAt;

  DevicePairingApproveData._();

  factory DevicePairingApproveData([
    void updates(DevicePairingApproveDataBuilder b),
  ]) = _$DevicePairingApproveData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DevicePairingApproveDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DevicePairingApproveData> get serializer =>
      _$DevicePairingApproveDataSerializer();
}

class _$DevicePairingApproveDataSerializer
    implements PrimitiveSerializer<DevicePairingApproveData> {
  @override
  final Iterable<Type> types = const [
    DevicePairingApproveData,
    _$DevicePairingApproveData,
  ];

  @override
  final String wireName = r'DevicePairingApproveData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DevicePairingApproveData object, {
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
      specifiedType: const FullType(DevicePairingApproveDataResultEnum),
    );
    yield r'approvedAt';
    yield serializers.serialize(
      object.approvedAt,
      specifiedType: const FullType(DateTime),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    DevicePairingApproveData object, {
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
    required DevicePairingApproveDataBuilder result,
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
                      DevicePairingApproveDataResultEnum,
                    ),
                  )
                  as DevicePairingApproveDataResultEnum;
          result.result = valueDes;
          break;
        case r'approvedAt':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(DateTime),
                  )
                  as DateTime;
          result.approvedAt = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  DevicePairingApproveData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DevicePairingApproveDataBuilder();
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

class DevicePairingApproveDataResultEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'approved')
  static const DevicePairingApproveDataResultEnum approved =
      _$devicePairingApproveDataResultEnum_approved;

  static Serializer<DevicePairingApproveDataResultEnum> get serializer =>
      _$devicePairingApproveDataResultEnumSerializer;

  const DevicePairingApproveDataResultEnum._(String name) : super(name);

  static BuiltSet<DevicePairingApproveDataResultEnum> get values =>
      _$devicePairingApproveDataResultEnumValues;
  static DevicePairingApproveDataResultEnum valueOf(String name) =>
      _$devicePairingApproveDataResultEnumValueOf(name);
}
