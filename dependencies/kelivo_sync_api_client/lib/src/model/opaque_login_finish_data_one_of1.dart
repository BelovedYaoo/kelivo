//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:kelivo_sync_api_client/src/model/opaque_login_finish_data_one_of1_device.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'opaque_login_finish_data_one_of1.g.dart';

/// OpaqueLoginFinishDataOneOf1
///
/// Properties:
/// * [protocolVersion]
/// * [result]
/// * [onboardingToken]
/// * [onboardingTokenExpiresAt]
/// * [device]
@BuiltValue()
abstract class OpaqueLoginFinishDataOneOf1
    implements
        Built<OpaqueLoginFinishDataOneOf1, OpaqueLoginFinishDataOneOf1Builder> {
  @BuiltValueField(wireName: r'protocolVersion')
  int get protocolVersion;

  @BuiltValueField(wireName: r'result')
  OpaqueLoginFinishDataOneOf1ResultEnum get result;
  // enum resultEnum {  device-approval-required,  };

  @BuiltValueField(wireName: r'onboardingToken')
  String get onboardingToken;

  @BuiltValueField(wireName: r'onboardingTokenExpiresAt')
  DateTime get onboardingTokenExpiresAt;

  @BuiltValueField(wireName: r'device')
  OpaqueLoginFinishDataOneOf1Device get device;

  OpaqueLoginFinishDataOneOf1._();

  factory OpaqueLoginFinishDataOneOf1([
    void updates(OpaqueLoginFinishDataOneOf1Builder b),
  ]) = _$OpaqueLoginFinishDataOneOf1;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(OpaqueLoginFinishDataOneOf1Builder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<OpaqueLoginFinishDataOneOf1> get serializer =>
      _$OpaqueLoginFinishDataOneOf1Serializer();
}

class _$OpaqueLoginFinishDataOneOf1Serializer
    implements PrimitiveSerializer<OpaqueLoginFinishDataOneOf1> {
  @override
  final Iterable<Type> types = const [
    OpaqueLoginFinishDataOneOf1,
    _$OpaqueLoginFinishDataOneOf1,
  ];

  @override
  final String wireName = r'OpaqueLoginFinishDataOneOf1';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    OpaqueLoginFinishDataOneOf1 object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'protocolVersion';
    yield serializers.serialize(
      object.protocolVersion,
      specifiedType: const FullType(int),
    );
    yield r'result';
    yield serializers.serialize(
      object.result,
      specifiedType: const FullType(OpaqueLoginFinishDataOneOf1ResultEnum),
    );
    yield r'onboardingToken';
    yield serializers.serialize(
      object.onboardingToken,
      specifiedType: const FullType(String),
    );
    yield r'onboardingTokenExpiresAt';
    yield serializers.serialize(
      object.onboardingTokenExpiresAt,
      specifiedType: const FullType(DateTime),
    );
    yield r'device';
    yield serializers.serialize(
      object.device,
      specifiedType: const FullType(OpaqueLoginFinishDataOneOf1Device),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    OpaqueLoginFinishDataOneOf1 object, {
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
    required OpaqueLoginFinishDataOneOf1Builder result,
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
        case r'result':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      OpaqueLoginFinishDataOneOf1ResultEnum,
                    ),
                  )
                  as OpaqueLoginFinishDataOneOf1ResultEnum;
          result.result = valueDes;
          break;
        case r'onboardingToken':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.onboardingToken = valueDes;
          break;
        case r'onboardingTokenExpiresAt':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(DateTime),
                  )
                  as DateTime;
          result.onboardingTokenExpiresAt = valueDes;
          break;
        case r'device':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      OpaqueLoginFinishDataOneOf1Device,
                    ),
                  )
                  as OpaqueLoginFinishDataOneOf1Device;
          result.device.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  OpaqueLoginFinishDataOneOf1 deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = OpaqueLoginFinishDataOneOf1Builder();
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

class OpaqueLoginFinishDataOneOf1ResultEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'device-approval-required')
  static const OpaqueLoginFinishDataOneOf1ResultEnum deviceApprovalRequired =
      _$opaqueLoginFinishDataOneOf1ResultEnum_deviceApprovalRequired;

  static Serializer<OpaqueLoginFinishDataOneOf1ResultEnum> get serializer =>
      _$opaqueLoginFinishDataOneOf1ResultEnumSerializer;

  const OpaqueLoginFinishDataOneOf1ResultEnum._(String name) : super(name);

  static BuiltSet<OpaqueLoginFinishDataOneOf1ResultEnum> get values =>
      _$opaqueLoginFinishDataOneOf1ResultEnumValues;
  static OpaqueLoginFinishDataOneOf1ResultEnum valueOf(String name) =>
      _$opaqueLoginFinishDataOneOf1ResultEnumValueOf(name);
}
