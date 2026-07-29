//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'trusted_device_summary.g.dart';

/// TrustedDeviceSummary
///
/// Properties:
/// * [id]
/// * [name]
/// * [platform]
/// * [clientVersion]
/// * [authGeneration]
/// * [status]
/// * [createdAt]
/// * [lastSeenAt]
/// * [revokedAt]
/// * [isCurrent]
@BuiltValue()
abstract class TrustedDeviceSummary
    implements Built<TrustedDeviceSummary, TrustedDeviceSummaryBuilder> {
  @BuiltValueField(wireName: r'id')
  String get id;

  @BuiltValueField(wireName: r'name')
  String get name;

  @BuiltValueField(wireName: r'platform')
  TrustedDeviceSummaryPlatformEnum get platform;
  // enum platformEnum {  android,  ios,  macos,  windows,  linux,  };

  @BuiltValueField(wireName: r'clientVersion')
  String get clientVersion;

  @BuiltValueField(wireName: r'authGeneration')
  int get authGeneration;

  @BuiltValueField(wireName: r'status')
  TrustedDeviceSummaryStatusEnum get status;
  // enum statusEnum {  active,  revoked,  };

  @BuiltValueField(wireName: r'createdAt')
  DateTime get createdAt;

  @BuiltValueField(wireName: r'lastSeenAt')
  DateTime? get lastSeenAt;

  @BuiltValueField(wireName: r'revokedAt')
  DateTime? get revokedAt;

  @BuiltValueField(wireName: r'isCurrent')
  bool get isCurrent;

  TrustedDeviceSummary._();

  factory TrustedDeviceSummary([void updates(TrustedDeviceSummaryBuilder b)]) =
      _$TrustedDeviceSummary;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(TrustedDeviceSummaryBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<TrustedDeviceSummary> get serializer =>
      _$TrustedDeviceSummarySerializer();
}

class _$TrustedDeviceSummarySerializer
    implements PrimitiveSerializer<TrustedDeviceSummary> {
  @override
  final Iterable<Type> types = const [
    TrustedDeviceSummary,
    _$TrustedDeviceSummary,
  ];

  @override
  final String wireName = r'TrustedDeviceSummary';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    TrustedDeviceSummary object, {
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
      specifiedType: const FullType(TrustedDeviceSummaryPlatformEnum),
    );
    yield r'clientVersion';
    yield serializers.serialize(
      object.clientVersion,
      specifiedType: const FullType(String),
    );
    yield r'authGeneration';
    yield serializers.serialize(
      object.authGeneration,
      specifiedType: const FullType(int),
    );
    yield r'status';
    yield serializers.serialize(
      object.status,
      specifiedType: const FullType(TrustedDeviceSummaryStatusEnum),
    );
    yield r'createdAt';
    yield serializers.serialize(
      object.createdAt,
      specifiedType: const FullType(DateTime),
    );
    yield r'lastSeenAt';
    yield object.lastSeenAt == null
        ? null
        : serializers.serialize(
            object.lastSeenAt,
            specifiedType: const FullType.nullable(DateTime),
          );
    yield r'revokedAt';
    yield object.revokedAt == null
        ? null
        : serializers.serialize(
            object.revokedAt,
            specifiedType: const FullType.nullable(DateTime),
          );
    yield r'isCurrent';
    yield serializers.serialize(
      object.isCurrent,
      specifiedType: const FullType(bool),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    TrustedDeviceSummary object, {
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
    required TrustedDeviceSummaryBuilder result,
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
                      TrustedDeviceSummaryPlatformEnum,
                    ),
                  )
                  as TrustedDeviceSummaryPlatformEnum;
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
        case r'authGeneration':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.authGeneration = valueDes;
          break;
        case r'status':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      TrustedDeviceSummaryStatusEnum,
                    ),
                  )
                  as TrustedDeviceSummaryStatusEnum;
          result.status = valueDes;
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
        case r'lastSeenAt':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType.nullable(DateTime),
                  )
                  as DateTime?;
          if (valueDes == null) continue;
          result.lastSeenAt = valueDes;
          break;
        case r'revokedAt':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType.nullable(DateTime),
                  )
                  as DateTime?;
          if (valueDes == null) continue;
          result.revokedAt = valueDes;
          break;
        case r'isCurrent':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(bool),
                  )
                  as bool;
          result.isCurrent = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  TrustedDeviceSummary deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = TrustedDeviceSummaryBuilder();
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

class TrustedDeviceSummaryPlatformEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'android')
  static const TrustedDeviceSummaryPlatformEnum android =
      _$trustedDeviceSummaryPlatformEnum_android;
  @BuiltValueEnumConst(wireName: r'ios')
  static const TrustedDeviceSummaryPlatformEnum ios =
      _$trustedDeviceSummaryPlatformEnum_ios;
  @BuiltValueEnumConst(wireName: r'macos')
  static const TrustedDeviceSummaryPlatformEnum macos =
      _$trustedDeviceSummaryPlatformEnum_macos;
  @BuiltValueEnumConst(wireName: r'windows')
  static const TrustedDeviceSummaryPlatformEnum windows =
      _$trustedDeviceSummaryPlatformEnum_windows;
  @BuiltValueEnumConst(wireName: r'linux')
  static const TrustedDeviceSummaryPlatformEnum linux =
      _$trustedDeviceSummaryPlatformEnum_linux;

  static Serializer<TrustedDeviceSummaryPlatformEnum> get serializer =>
      _$trustedDeviceSummaryPlatformEnumSerializer;

  const TrustedDeviceSummaryPlatformEnum._(String name) : super(name);

  static BuiltSet<TrustedDeviceSummaryPlatformEnum> get values =>
      _$trustedDeviceSummaryPlatformEnumValues;
  static TrustedDeviceSummaryPlatformEnum valueOf(String name) =>
      _$trustedDeviceSummaryPlatformEnumValueOf(name);
}

class TrustedDeviceSummaryStatusEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'active')
  static const TrustedDeviceSummaryStatusEnum active =
      _$trustedDeviceSummaryStatusEnum_active;
  @BuiltValueEnumConst(wireName: r'revoked')
  static const TrustedDeviceSummaryStatusEnum revoked =
      _$trustedDeviceSummaryStatusEnum_revoked;

  static Serializer<TrustedDeviceSummaryStatusEnum> get serializer =>
      _$trustedDeviceSummaryStatusEnumSerializer;

  const TrustedDeviceSummaryStatusEnum._(String name) : super(name);

  static BuiltSet<TrustedDeviceSummaryStatusEnum> get values =>
      _$trustedDeviceSummaryStatusEnumValues;
  static TrustedDeviceSummaryStatusEnum valueOf(String name) =>
      _$trustedDeviceSummaryStatusEnumValueOf(name);
}
