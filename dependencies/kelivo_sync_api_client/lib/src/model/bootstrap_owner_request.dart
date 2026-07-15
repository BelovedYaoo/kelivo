//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'bootstrap_owner_request.g.dart';

/// BootstrapOwnerRequest
///
/// Properties:
/// * [bootstrapSecret]
/// * [loginName]
/// * [displayName]
/// * [password]
@BuiltValue()
abstract class BootstrapOwnerRequest
    implements Built<BootstrapOwnerRequest, BootstrapOwnerRequestBuilder> {
  @BuiltValueField(wireName: r'bootstrapSecret')
  String get bootstrapSecret;

  @BuiltValueField(wireName: r'loginName')
  String get loginName;

  @BuiltValueField(wireName: r'displayName')
  String get displayName;

  @BuiltValueField(wireName: r'password')
  String get password;

  BootstrapOwnerRequest._();

  factory BootstrapOwnerRequest([
    void updates(BootstrapOwnerRequestBuilder b),
  ]) = _$BootstrapOwnerRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(BootstrapOwnerRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<BootstrapOwnerRequest> get serializer =>
      _$BootstrapOwnerRequestSerializer();
}

class _$BootstrapOwnerRequestSerializer
    implements PrimitiveSerializer<BootstrapOwnerRequest> {
  @override
  final Iterable<Type> types = const [
    BootstrapOwnerRequest,
    _$BootstrapOwnerRequest,
  ];

  @override
  final String wireName = r'BootstrapOwnerRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    BootstrapOwnerRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'bootstrapSecret';
    yield serializers.serialize(
      object.bootstrapSecret,
      specifiedType: const FullType(String),
    );
    yield r'loginName';
    yield serializers.serialize(
      object.loginName,
      specifiedType: const FullType(String),
    );
    yield r'displayName';
    yield serializers.serialize(
      object.displayName,
      specifiedType: const FullType(String),
    );
    yield r'password';
    yield serializers.serialize(
      object.password,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    BootstrapOwnerRequest object, {
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
    required BootstrapOwnerRequestBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'bootstrapSecret':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.bootstrapSecret = valueDes;
          break;
        case r'loginName':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.loginName = valueDes;
          break;
        case r'displayName':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.displayName = valueDes;
          break;
        case r'password':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.password = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  BootstrapOwnerRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = BootstrapOwnerRequestBuilder();
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
