//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/opaque_registration_finish_data_device.dart';
import 'package:built_collection/built_collection.dart';
import 'package:kelivo_sync_api_client/src/model/opaque_registration_finish_data_user.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'opaque_registration_finish_data.g.dart';

/// OpaqueRegistrationFinishData
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
abstract class OpaqueRegistrationFinishData
    implements
        Built<
          OpaqueRegistrationFinishData,
          OpaqueRegistrationFinishDataBuilder
        > {
  @BuiltValueField(wireName: r'protocolVersion')
  int get protocolVersion;

  @BuiltValueField(wireName: r'result')
  OpaqueRegistrationFinishDataResultEnum get result;
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

  OpaqueRegistrationFinishData._();

  factory OpaqueRegistrationFinishData([
    void updates(OpaqueRegistrationFinishDataBuilder b),
  ]) = _$OpaqueRegistrationFinishData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(OpaqueRegistrationFinishDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<OpaqueRegistrationFinishData> get serializer =>
      _$OpaqueRegistrationFinishDataSerializer();
}

class _$OpaqueRegistrationFinishDataSerializer
    implements PrimitiveSerializer<OpaqueRegistrationFinishData> {
  @override
  final Iterable<Type> types = const [
    OpaqueRegistrationFinishData,
    _$OpaqueRegistrationFinishData,
  ];

  @override
  final String wireName = r'OpaqueRegistrationFinishData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    OpaqueRegistrationFinishData object, {
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
      specifiedType: const FullType(OpaqueRegistrationFinishDataResultEnum),
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
    OpaqueRegistrationFinishData object, {
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
    required OpaqueRegistrationFinishDataBuilder result,
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
                      OpaqueRegistrationFinishDataResultEnum,
                    ),
                  )
                  as OpaqueRegistrationFinishDataResultEnum;
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
  OpaqueRegistrationFinishData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = OpaqueRegistrationFinishDataBuilder();
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

class OpaqueRegistrationFinishDataResultEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'authenticated')
  static const OpaqueRegistrationFinishDataResultEnum authenticated =
      _$opaqueRegistrationFinishDataResultEnum_authenticated;

  static Serializer<OpaqueRegistrationFinishDataResultEnum> get serializer =>
      _$opaqueRegistrationFinishDataResultEnumSerializer;

  const OpaqueRegistrationFinishDataResultEnum._(String name) : super(name);

  static BuiltSet<OpaqueRegistrationFinishDataResultEnum> get values =>
      _$opaqueRegistrationFinishDataResultEnumValues;
  static OpaqueRegistrationFinishDataResultEnum valueOf(String name) =>
      _$opaqueRegistrationFinishDataResultEnumValueOf(name);
}
