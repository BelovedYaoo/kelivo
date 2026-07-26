//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/opaque_registration_finish_data_device.dart';
import 'package:built_collection/built_collection.dart';
import 'package:kelivo_sync_api_client/src/model/opaque_registration_finish_data_user.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'opaque_login_finish_data_one_of.g.dart';

/// OpaqueLoginFinishDataOneOf
///
/// Properties:
/// * [protocolVersion]
/// * [result]
/// * [keyEpoch]
/// * [token]
/// * [tokenExpiresAt]
/// * [user]
/// * [device]
@BuiltValue()
abstract class OpaqueLoginFinishDataOneOf
    implements
        Built<OpaqueLoginFinishDataOneOf, OpaqueLoginFinishDataOneOfBuilder> {
  @BuiltValueField(wireName: r'protocolVersion')
  int get protocolVersion;

  @BuiltValueField(wireName: r'result')
  OpaqueLoginFinishDataOneOfResultEnum get result;
  // enum resultEnum {  authenticated,  };

  @BuiltValueField(wireName: r'keyEpoch')
  int get keyEpoch;

  @BuiltValueField(wireName: r'token')
  String get token;

  @BuiltValueField(wireName: r'tokenExpiresAt')
  DateTime get tokenExpiresAt;

  @BuiltValueField(wireName: r'user')
  OpaqueRegistrationFinishDataUser get user;

  @BuiltValueField(wireName: r'device')
  OpaqueRegistrationFinishDataDevice get device;

  OpaqueLoginFinishDataOneOf._();

  factory OpaqueLoginFinishDataOneOf([
    void updates(OpaqueLoginFinishDataOneOfBuilder b),
  ]) = _$OpaqueLoginFinishDataOneOf;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(OpaqueLoginFinishDataOneOfBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<OpaqueLoginFinishDataOneOf> get serializer =>
      _$OpaqueLoginFinishDataOneOfSerializer();
}

class _$OpaqueLoginFinishDataOneOfSerializer
    implements PrimitiveSerializer<OpaqueLoginFinishDataOneOf> {
  @override
  final Iterable<Type> types = const [
    OpaqueLoginFinishDataOneOf,
    _$OpaqueLoginFinishDataOneOf,
  ];

  @override
  final String wireName = r'OpaqueLoginFinishDataOneOf';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    OpaqueLoginFinishDataOneOf object, {
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
      specifiedType: const FullType(OpaqueLoginFinishDataOneOfResultEnum),
    );
    yield r'keyEpoch';
    yield serializers.serialize(
      object.keyEpoch,
      specifiedType: const FullType(int),
    );
    yield r'token';
    yield serializers.serialize(
      object.token,
      specifiedType: const FullType(String),
    );
    yield r'tokenExpiresAt';
    yield serializers.serialize(
      object.tokenExpiresAt,
      specifiedType: const FullType(DateTime),
    );
    yield r'user';
    yield serializers.serialize(
      object.user,
      specifiedType: const FullType(OpaqueRegistrationFinishDataUser),
    );
    yield r'device';
    yield serializers.serialize(
      object.device,
      specifiedType: const FullType(OpaqueRegistrationFinishDataDevice),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    OpaqueLoginFinishDataOneOf object, {
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
    required OpaqueLoginFinishDataOneOfBuilder result,
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
                      OpaqueLoginFinishDataOneOfResultEnum,
                    ),
                  )
                  as OpaqueLoginFinishDataOneOfResultEnum;
          result.result = valueDes;
          break;
        case r'keyEpoch':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.keyEpoch = valueDes;
          break;
        case r'token':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.token = valueDes;
          break;
        case r'tokenExpiresAt':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(DateTime),
                  )
                  as DateTime;
          result.tokenExpiresAt = valueDes;
          break;
        case r'user':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      OpaqueRegistrationFinishDataUser,
                    ),
                  )
                  as OpaqueRegistrationFinishDataUser;
          result.user.replace(valueDes);
          break;
        case r'device':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      OpaqueRegistrationFinishDataDevice,
                    ),
                  )
                  as OpaqueRegistrationFinishDataDevice;
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
  OpaqueLoginFinishDataOneOf deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = OpaqueLoginFinishDataOneOfBuilder();
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

class OpaqueLoginFinishDataOneOfResultEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'authenticated')
  static const OpaqueLoginFinishDataOneOfResultEnum authenticated =
      _$opaqueLoginFinishDataOneOfResultEnum_authenticated;

  static Serializer<OpaqueLoginFinishDataOneOfResultEnum> get serializer =>
      _$opaqueLoginFinishDataOneOfResultEnumSerializer;

  const OpaqueLoginFinishDataOneOfResultEnum._(String name) : super(name);

  static BuiltSet<OpaqueLoginFinishDataOneOfResultEnum> get values =>
      _$opaqueLoginFinishDataOneOfResultEnumValues;
  static OpaqueLoginFinishDataOneOfResultEnum valueOf(String name) =>
      _$opaqueLoginFinishDataOneOfResultEnumValueOf(name);
}
