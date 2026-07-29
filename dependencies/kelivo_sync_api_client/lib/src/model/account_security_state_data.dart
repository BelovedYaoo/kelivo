//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/account_security_state_envelope.dart';
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'account_security_state_data.g.dart';

/// AccountSecurityStateData
///
/// Properties:
/// * [generation]
/// * [keyEpoch]
/// * [dataRekeyPhase]
/// * [membershipManifest]
/// * [membershipManifestDigest]
/// * [recoveryPublicKeyVersion]
/// * [recoveryPublicKey]
/// * [recoveryCapsuleVersion]
/// * [recoveryCapsule]
/// * [lastOperationId]
/// * [updatedAt]
/// * [envelopes]
@BuiltValue()
abstract class AccountSecurityStateData
    implements
        Built<AccountSecurityStateData, AccountSecurityStateDataBuilder> {
  @BuiltValueField(wireName: r'generation')
  int get generation;

  @BuiltValueField(wireName: r'keyEpoch')
  int get keyEpoch;

  @BuiltValueField(wireName: r'dataRekeyPhase')
  AccountSecurityStateDataDataRekeyPhaseEnum get dataRekeyPhase;
  // enum dataRekeyPhaseEnum {  ready,  rekey-pending,  };

  @BuiltValueField(wireName: r'membershipManifest')
  String get membershipManifest;

  @BuiltValueField(wireName: r'membershipManifestDigest')
  String get membershipManifestDigest;

  @BuiltValueField(wireName: r'recoveryPublicKeyVersion')
  int get recoveryPublicKeyVersion;

  @BuiltValueField(wireName: r'recoveryPublicKey')
  String get recoveryPublicKey;

  @BuiltValueField(wireName: r'recoveryCapsuleVersion')
  int get recoveryCapsuleVersion;

  @BuiltValueField(wireName: r'recoveryCapsule')
  String get recoveryCapsule;

  @BuiltValueField(wireName: r'lastOperationId')
  String get lastOperationId;

  @BuiltValueField(wireName: r'updatedAt')
  DateTime get updatedAt;

  @BuiltValueField(wireName: r'envelopes')
  BuiltList<AccountSecurityStateEnvelope> get envelopes;

  AccountSecurityStateData._();

  factory AccountSecurityStateData([
    void updates(AccountSecurityStateDataBuilder b),
  ]) = _$AccountSecurityStateData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(AccountSecurityStateDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AccountSecurityStateData> get serializer =>
      _$AccountSecurityStateDataSerializer();
}

class _$AccountSecurityStateDataSerializer
    implements PrimitiveSerializer<AccountSecurityStateData> {
  @override
  final Iterable<Type> types = const [
    AccountSecurityStateData,
    _$AccountSecurityStateData,
  ];

  @override
  final String wireName = r'AccountSecurityStateData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AccountSecurityStateData object, {
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
      specifiedType: const FullType(AccountSecurityStateDataDataRekeyPhaseEnum),
    );
    yield r'membershipManifest';
    yield serializers.serialize(
      object.membershipManifest,
      specifiedType: const FullType(String),
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
    yield r'recoveryCapsule';
    yield serializers.serialize(
      object.recoveryCapsule,
      specifiedType: const FullType(String),
    );
    yield r'lastOperationId';
    yield serializers.serialize(
      object.lastOperationId,
      specifiedType: const FullType(String),
    );
    yield r'updatedAt';
    yield serializers.serialize(
      object.updatedAt,
      specifiedType: const FullType(DateTime),
    );
    yield r'envelopes';
    yield serializers.serialize(
      object.envelopes,
      specifiedType: const FullType(BuiltList, [
        FullType(AccountSecurityStateEnvelope),
      ]),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    AccountSecurityStateData object, {
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
    required AccountSecurityStateDataBuilder result,
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
                      AccountSecurityStateDataDataRekeyPhaseEnum,
                    ),
                  )
                  as AccountSecurityStateDataDataRekeyPhaseEnum;
          result.dataRekeyPhase = valueDes;
          break;
        case r'membershipManifest':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.membershipManifest = valueDes;
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
        case r'recoveryCapsule':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.recoveryCapsule = valueDes;
          break;
        case r'lastOperationId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.lastOperationId = valueDes;
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
        case r'envelopes':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(BuiltList, [
                      FullType(AccountSecurityStateEnvelope),
                    ]),
                  )
                  as BuiltList<AccountSecurityStateEnvelope>;
          result.envelopes.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  AccountSecurityStateData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = AccountSecurityStateDataBuilder();
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

class AccountSecurityStateDataDataRekeyPhaseEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'ready')
  static const AccountSecurityStateDataDataRekeyPhaseEnum ready =
      _$accountSecurityStateDataDataRekeyPhaseEnum_ready;
  @BuiltValueEnumConst(wireName: r'rekey-pending')
  static const AccountSecurityStateDataDataRekeyPhaseEnum rekeyPending =
      _$accountSecurityStateDataDataRekeyPhaseEnum_rekeyPending;

  static Serializer<AccountSecurityStateDataDataRekeyPhaseEnum>
  get serializer => _$accountSecurityStateDataDataRekeyPhaseEnumSerializer;

  const AccountSecurityStateDataDataRekeyPhaseEnum._(String name) : super(name);

  static BuiltSet<AccountSecurityStateDataDataRekeyPhaseEnum> get values =>
      _$accountSecurityStateDataDataRekeyPhaseEnumValues;
  static AccountSecurityStateDataDataRekeyPhaseEnum valueOf(String name) =>
      _$accountSecurityStateDataDataRekeyPhaseEnumValueOf(name);
}
