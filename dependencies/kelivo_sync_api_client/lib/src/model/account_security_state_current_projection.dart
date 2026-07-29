//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'account_security_state_current_projection.g.dart';

/// AccountSecurityStateCurrentProjection
///
/// Properties:
/// * [generation]
/// * [keyEpoch]
/// * [dataRekeyPhase]
/// * [membershipManifestDigest]
/// * [recoveryPublicKeyVersion]
/// * [recoveryPublicKey]
/// * [recoveryCapsuleVersion]
/// * [updatedAt]
@BuiltValue()
abstract class AccountSecurityStateCurrentProjection
    implements
        Built<
          AccountSecurityStateCurrentProjection,
          AccountSecurityStateCurrentProjectionBuilder
        > {
  @BuiltValueField(wireName: r'generation')
  int get generation;

  @BuiltValueField(wireName: r'keyEpoch')
  int get keyEpoch;

  @BuiltValueField(wireName: r'dataRekeyPhase')
  AccountSecurityStateCurrentProjectionDataRekeyPhaseEnum get dataRekeyPhase;
  // enum dataRekeyPhaseEnum {  ready,  rekey-pending,  };

  @BuiltValueField(wireName: r'membershipManifestDigest')
  String get membershipManifestDigest;

  @BuiltValueField(wireName: r'recoveryPublicKeyVersion')
  int get recoveryPublicKeyVersion;

  @BuiltValueField(wireName: r'recoveryPublicKey')
  String get recoveryPublicKey;

  @BuiltValueField(wireName: r'recoveryCapsuleVersion')
  int get recoveryCapsuleVersion;

  @BuiltValueField(wireName: r'updatedAt')
  DateTime get updatedAt;

  AccountSecurityStateCurrentProjection._();

  factory AccountSecurityStateCurrentProjection([
    void updates(AccountSecurityStateCurrentProjectionBuilder b),
  ]) = _$AccountSecurityStateCurrentProjection;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(AccountSecurityStateCurrentProjectionBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AccountSecurityStateCurrentProjection> get serializer =>
      _$AccountSecurityStateCurrentProjectionSerializer();
}

class _$AccountSecurityStateCurrentProjectionSerializer
    implements PrimitiveSerializer<AccountSecurityStateCurrentProjection> {
  @override
  final Iterable<Type> types = const [
    AccountSecurityStateCurrentProjection,
    _$AccountSecurityStateCurrentProjection,
  ];

  @override
  final String wireName = r'AccountSecurityStateCurrentProjection';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AccountSecurityStateCurrentProjection object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'generation';
    yield serializers.serialize(
      object.generation,
      specifiedType: const FullType(int),
    );
    yield r'keyEpoch';
    yield serializers.serialize(
      object.keyEpoch,
      specifiedType: const FullType(int),
    );
    yield r'dataRekeyPhase';
    yield serializers.serialize(
      object.dataRekeyPhase,
      specifiedType: const FullType(
        AccountSecurityStateCurrentProjectionDataRekeyPhaseEnum,
      ),
    );
    yield r'membershipManifestDigest';
    yield serializers.serialize(
      object.membershipManifestDigest,
      specifiedType: const FullType(String),
    );
    yield r'recoveryPublicKeyVersion';
    yield serializers.serialize(
      object.recoveryPublicKeyVersion,
      specifiedType: const FullType(int),
    );
    yield r'recoveryPublicKey';
    yield serializers.serialize(
      object.recoveryPublicKey,
      specifiedType: const FullType(String),
    );
    yield r'recoveryCapsuleVersion';
    yield serializers.serialize(
      object.recoveryCapsuleVersion,
      specifiedType: const FullType(int),
    );
    yield r'updatedAt';
    yield serializers.serialize(
      object.updatedAt,
      specifiedType: const FullType(DateTime),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    AccountSecurityStateCurrentProjection object, {
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
    required AccountSecurityStateCurrentProjectionBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'generation':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.generation = valueDes;
          break;
        case r'keyEpoch':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.keyEpoch = valueDes;
          break;
        case r'dataRekeyPhase':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      AccountSecurityStateCurrentProjectionDataRekeyPhaseEnum,
                    ),
                  )
                  as AccountSecurityStateCurrentProjectionDataRekeyPhaseEnum;
          result.dataRekeyPhase = valueDes;
          break;
        case r'membershipManifestDigest':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.membershipManifestDigest = valueDes;
          break;
        case r'recoveryPublicKeyVersion':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.recoveryPublicKeyVersion = valueDes;
          break;
        case r'recoveryPublicKey':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.recoveryPublicKey = valueDes;
          break;
        case r'recoveryCapsuleVersion':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.recoveryCapsuleVersion = valueDes;
          break;
        case r'updatedAt':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(DateTime),
                  )
                  as DateTime;
          result.updatedAt = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  AccountSecurityStateCurrentProjection deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = AccountSecurityStateCurrentProjectionBuilder();
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

class AccountSecurityStateCurrentProjectionDataRekeyPhaseEnum
    extends EnumClass {
  @BuiltValueEnumConst(wireName: r'ready')
  static const AccountSecurityStateCurrentProjectionDataRekeyPhaseEnum ready =
      _$accountSecurityStateCurrentProjectionDataRekeyPhaseEnum_ready;
  @BuiltValueEnumConst(wireName: r'rekey-pending')
  static const AccountSecurityStateCurrentProjectionDataRekeyPhaseEnum
  rekeyPending =
      _$accountSecurityStateCurrentProjectionDataRekeyPhaseEnum_rekeyPending;

  static Serializer<AccountSecurityStateCurrentProjectionDataRekeyPhaseEnum>
  get serializer =>
      _$accountSecurityStateCurrentProjectionDataRekeyPhaseEnumSerializer;

  const AccountSecurityStateCurrentProjectionDataRekeyPhaseEnum._(String name)
    : super(name);

  static BuiltSet<AccountSecurityStateCurrentProjectionDataRekeyPhaseEnum>
  get values => _$accountSecurityStateCurrentProjectionDataRekeyPhaseEnumValues;
  static AccountSecurityStateCurrentProjectionDataRekeyPhaseEnum valueOf(
    String name,
  ) => _$accountSecurityStateCurrentProjectionDataRekeyPhaseEnumValueOf(name);
}
