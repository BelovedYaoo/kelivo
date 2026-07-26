//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'opaque_registration_start_data.g.dart';

/// OpaqueRegistrationStartData
///
/// Properties:
/// * [protocolVersion]
/// * [attemptId]
/// * [userId]
/// * [accountBinding]
/// * [deviceChallenge]
/// * [registrationResponse]
/// * [expiresAt]
@BuiltValue()
abstract class OpaqueRegistrationStartData
    implements
        Built<OpaqueRegistrationStartData, OpaqueRegistrationStartDataBuilder> {
  @BuiltValueField(wireName: r'protocolVersion')
  int get protocolVersion;

  @BuiltValueField(wireName: r'attemptId')
  String get attemptId;

  @BuiltValueField(wireName: r'userId')
  String get userId;

  @BuiltValueField(wireName: r'accountBinding')
  String get accountBinding;

  @BuiltValueField(wireName: r'deviceChallenge')
  String get deviceChallenge;

  @BuiltValueField(wireName: r'registrationResponse')
  String get registrationResponse;

  @BuiltValueField(wireName: r'expiresAt')
  DateTime get expiresAt;

  OpaqueRegistrationStartData._();

  factory OpaqueRegistrationStartData([
    void updates(OpaqueRegistrationStartDataBuilder b),
  ]) = _$OpaqueRegistrationStartData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(OpaqueRegistrationStartDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<OpaqueRegistrationStartData> get serializer =>
      _$OpaqueRegistrationStartDataSerializer();
}

class _$OpaqueRegistrationStartDataSerializer
    implements PrimitiveSerializer<OpaqueRegistrationStartData> {
  @override
  final Iterable<Type> types = const [
    OpaqueRegistrationStartData,
    _$OpaqueRegistrationStartData,
  ];

  @override
  final String wireName = r'OpaqueRegistrationStartData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    OpaqueRegistrationStartData object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'protocolVersion';
    yield serializers.serialize(
      object.protocolVersion,
      specifiedType: const FullType(int),
    );
    yield r'attemptId';
    yield serializers.serialize(
      object.attemptId,
      specifiedType: const FullType(String),
    );
    yield r'userId';
    yield serializers.serialize(
      object.userId,
      specifiedType: const FullType(String),
    );
    yield r'accountBinding';
    yield serializers.serialize(
      object.accountBinding,
      specifiedType: const FullType(String),
    );
    yield r'deviceChallenge';
    yield serializers.serialize(
      object.deviceChallenge,
      specifiedType: const FullType(String),
    );
    yield r'registrationResponse';
    yield serializers.serialize(
      object.registrationResponse,
      specifiedType: const FullType(String),
    );
    yield r'expiresAt';
    yield serializers.serialize(
      object.expiresAt,
      specifiedType: const FullType(DateTime),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    OpaqueRegistrationStartData object, {
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
    required OpaqueRegistrationStartDataBuilder result,
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
        case r'attemptId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.attemptId = valueDes;
          break;
        case r'userId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.userId = valueDes;
          break;
        case r'accountBinding':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.accountBinding = valueDes;
          break;
        case r'deviceChallenge':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.deviceChallenge = valueDes;
          break;
        case r'registrationResponse':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.registrationResponse = valueDes;
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
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  OpaqueRegistrationStartData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = OpaqueRegistrationStartDataBuilder();
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
