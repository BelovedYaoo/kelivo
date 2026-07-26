//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'opaque_login_start_data.g.dart';

/// OpaqueLoginStartData
///
/// Properties:
/// * [protocolVersion]
/// * [attemptId]
/// * [accountBinding]
/// * [deviceChallenge]
/// * [credentialResponse]
/// * [expiresAt]
@BuiltValue()
abstract class OpaqueLoginStartData
    implements Built<OpaqueLoginStartData, OpaqueLoginStartDataBuilder> {
  @BuiltValueField(wireName: r'protocolVersion')
  int get protocolVersion;

  @BuiltValueField(wireName: r'attemptId')
  String get attemptId;

  @BuiltValueField(wireName: r'accountBinding')
  String get accountBinding;

  @BuiltValueField(wireName: r'deviceChallenge')
  String get deviceChallenge;

  @BuiltValueField(wireName: r'credentialResponse')
  String get credentialResponse;

  @BuiltValueField(wireName: r'expiresAt')
  DateTime get expiresAt;

  OpaqueLoginStartData._();

  factory OpaqueLoginStartData([void updates(OpaqueLoginStartDataBuilder b)]) =
      _$OpaqueLoginStartData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(OpaqueLoginStartDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<OpaqueLoginStartData> get serializer =>
      _$OpaqueLoginStartDataSerializer();
}

class _$OpaqueLoginStartDataSerializer
    implements PrimitiveSerializer<OpaqueLoginStartData> {
  @override
  final Iterable<Type> types = const [
    OpaqueLoginStartData,
    _$OpaqueLoginStartData,
  ];

  @override
  final String wireName = r'OpaqueLoginStartData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    OpaqueLoginStartData object, {
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
    yield r'credentialResponse';
    yield serializers.serialize(
      object.credentialResponse,
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
    OpaqueLoginStartData object, {
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
    required OpaqueLoginStartDataBuilder result,
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
        case r'credentialResponse':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.credentialResponse = valueDes;
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
  OpaqueLoginStartData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = OpaqueLoginStartDataBuilder();
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
