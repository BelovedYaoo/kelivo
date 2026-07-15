//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'auth_device_summary.g.dart';

/// AuthDeviceSummary
///
/// Properties:
/// * [id]
/// * [name]
/// * [platform]
/// * [clientVersion]
/// * [createdAt]
@BuiltValue()
abstract class AuthDeviceSummary
    implements Built<AuthDeviceSummary, AuthDeviceSummaryBuilder> {
  @BuiltValueField(wireName: r'id')
  String get id;

  @BuiltValueField(wireName: r'name')
  String get name;

  @BuiltValueField(wireName: r'platform')
  AuthDeviceSummaryPlatformEnum get platform;
  // enum platformEnum {  android,  ios,  macos,  windows,  linux,  };

  @BuiltValueField(wireName: r'clientVersion')
  String get clientVersion;

  @BuiltValueField(wireName: r'createdAt')
  DateTime get createdAt;

  AuthDeviceSummary._();

  factory AuthDeviceSummary([void updates(AuthDeviceSummaryBuilder b)]) =
      _$AuthDeviceSummary;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(AuthDeviceSummaryBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AuthDeviceSummary> get serializer =>
      _$AuthDeviceSummarySerializer();
}

class _$AuthDeviceSummarySerializer
    implements PrimitiveSerializer<AuthDeviceSummary> {
  @override
  final Iterable<Type> types = const [AuthDeviceSummary, _$AuthDeviceSummary];

  @override
  final String wireName = r'AuthDeviceSummary';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AuthDeviceSummary object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'id';
    yield serializers.serialize(
      object.id,
      specifiedType: const FullType(String),
    );
    yield r'name';
    yield serializers.serialize(
      object.name,
      specifiedType: const FullType(String),
    );
    yield r'platform';
    yield serializers.serialize(
      object.platform,
      specifiedType: const FullType(AuthDeviceSummaryPlatformEnum),
    );
    yield r'clientVersion';
    yield serializers.serialize(
      object.clientVersion,
      specifiedType: const FullType(String),
    );
    yield r'createdAt';
    yield serializers.serialize(
      object.createdAt,
      specifiedType: const FullType(DateTime),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    AuthDeviceSummary object, {
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
    required AuthDeviceSummaryBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'id':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.id = valueDes;
          break;
        case r'name':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.name = valueDes;
          break;
        case r'platform':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      AuthDeviceSummaryPlatformEnum,
                    ),
                  )
                  as AuthDeviceSummaryPlatformEnum;
          result.platform = valueDes;
          break;
        case r'clientVersion':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.clientVersion = valueDes;
          break;
        case r'createdAt':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(DateTime),
                  )
                  as DateTime;
          result.createdAt = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  AuthDeviceSummary deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = AuthDeviceSummaryBuilder();
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

class AuthDeviceSummaryPlatformEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'android')
  static const AuthDeviceSummaryPlatformEnum android =
      _$authDeviceSummaryPlatformEnum_android;
  @BuiltValueEnumConst(wireName: r'ios')
  static const AuthDeviceSummaryPlatformEnum ios =
      _$authDeviceSummaryPlatformEnum_ios;
  @BuiltValueEnumConst(wireName: r'macos')
  static const AuthDeviceSummaryPlatformEnum macos =
      _$authDeviceSummaryPlatformEnum_macos;
  @BuiltValueEnumConst(wireName: r'windows')
  static const AuthDeviceSummaryPlatformEnum windows =
      _$authDeviceSummaryPlatformEnum_windows;
  @BuiltValueEnumConst(wireName: r'linux')
  static const AuthDeviceSummaryPlatformEnum linux =
      _$authDeviceSummaryPlatformEnum_linux;

  static Serializer<AuthDeviceSummaryPlatformEnum> get serializer =>
      _$authDeviceSummaryPlatformEnumSerializer;

  const AuthDeviceSummaryPlatformEnum._(String name) : super(name);

  static BuiltSet<AuthDeviceSummaryPlatformEnum> get values =>
      _$authDeviceSummaryPlatformEnumValues;
  static AuthDeviceSummaryPlatformEnum valueOf(String name) =>
      _$authDeviceSummaryPlatformEnumValueOf(name);
}
