//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:kelivo_sync_api_client/src/model/self_revocation_status_data_one_of1_receipt.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'self_revocation_status_data_one_of1.g.dart';

/// SelfRevocationStatusDataOneOf1
///
/// Properties:
/// * [status]
/// * [deviceId]
/// * [mutationId]
/// * [operationId]
/// * [expectedGeneration]
/// * [expectedKeyEpoch]
/// * [expectedMembershipManifestDigest]
/// * [intentDigest]
/// * [intentSignature]
/// * [requestedAt]
/// * [expiresAt]
/// * [receiptExpiresAt]
/// * [receipt]
@BuiltValue()
abstract class SelfRevocationStatusDataOneOf1
    implements
        Built<
          SelfRevocationStatusDataOneOf1,
          SelfRevocationStatusDataOneOf1Builder
        > {
  @BuiltValueField(wireName: r'status')
  SelfRevocationStatusDataOneOf1StatusEnum get status;
  // enum statusEnum {  confirmed,  };

  @BuiltValueField(wireName: r'deviceId')
  String get deviceId;

  @BuiltValueField(wireName: r'mutationId')
  String get mutationId;

  @BuiltValueField(wireName: r'operationId')
  String get operationId;

  @BuiltValueField(wireName: r'expectedGeneration')
  int get expectedGeneration;

  @BuiltValueField(wireName: r'expectedKeyEpoch')
  int get expectedKeyEpoch;

  @BuiltValueField(wireName: r'expectedMembershipManifestDigest')
  String get expectedMembershipManifestDigest;

  @BuiltValueField(wireName: r'intentDigest')
  String get intentDigest;

  @BuiltValueField(wireName: r'intentSignature')
  String get intentSignature;

  @BuiltValueField(wireName: r'requestedAt')
  DateTime get requestedAt;

  @BuiltValueField(wireName: r'expiresAt')
  DateTime get expiresAt;

  @BuiltValueField(wireName: r'receiptExpiresAt')
  DateTime get receiptExpiresAt;

  @BuiltValueField(wireName: r'receipt')
  SelfRevocationStatusDataOneOf1Receipt get receipt;

  SelfRevocationStatusDataOneOf1._();

  factory SelfRevocationStatusDataOneOf1([
    void updates(SelfRevocationStatusDataOneOf1Builder b),
  ]) = _$SelfRevocationStatusDataOneOf1;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SelfRevocationStatusDataOneOf1Builder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<SelfRevocationStatusDataOneOf1> get serializer =>
      _$SelfRevocationStatusDataOneOf1Serializer();
}

class _$SelfRevocationStatusDataOneOf1Serializer
    implements PrimitiveSerializer<SelfRevocationStatusDataOneOf1> {
  @override
  final Iterable<Type> types = const [
    SelfRevocationStatusDataOneOf1,
    _$SelfRevocationStatusDataOneOf1,
  ];

  @override
  final String wireName = r'SelfRevocationStatusDataOneOf1';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    SelfRevocationStatusDataOneOf1 object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'status';
    yield serializers.serialize(
      object.status,
      specifiedType: const FullType(SelfRevocationStatusDataOneOf1StatusEnum),
    );
    yield r'deviceId';
    yield serializers.serialize(
      object.deviceId,
      specifiedType: const FullType(String),
    );
    yield r'mutationId';
    yield serializers.serialize(
      object.mutationId,
      specifiedType: const FullType(String),
    );
    yield r'operationId';
    yield serializers.serialize(
      object.operationId,
      specifiedType: const FullType(String),
    );
    yield r'expectedGeneration';
    yield serializers.serialize(
      object.expectedGeneration,
      specifiedType: const FullType(int),
    );
    yield r'expectedKeyEpoch';
    yield serializers.serialize(
      object.expectedKeyEpoch,
      specifiedType: const FullType(int),
    );
    yield r'expectedMembershipManifestDigest';
    yield serializers.serialize(
      object.expectedMembershipManifestDigest,
      specifiedType: const FullType(String),
    );
    yield r'intentDigest';
    yield serializers.serialize(
      object.intentDigest,
      specifiedType: const FullType(String),
    );
    yield r'intentSignature';
    yield serializers.serialize(
      object.intentSignature,
      specifiedType: const FullType(String),
    );
    yield r'requestedAt';
    yield serializers.serialize(
      object.requestedAt,
      specifiedType: const FullType(DateTime),
    );
    yield r'expiresAt';
    yield serializers.serialize(
      object.expiresAt,
      specifiedType: const FullType(DateTime),
    );
    yield r'receiptExpiresAt';
    yield serializers.serialize(
      object.receiptExpiresAt,
      specifiedType: const FullType(DateTime),
    );
    yield r'receipt';
    yield serializers.serialize(
      object.receipt,
      specifiedType: const FullType(SelfRevocationStatusDataOneOf1Receipt),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    SelfRevocationStatusDataOneOf1 object, {
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
    required SelfRevocationStatusDataOneOf1Builder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'status':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      SelfRevocationStatusDataOneOf1StatusEnum,
                    ),
                  )
                  as SelfRevocationStatusDataOneOf1StatusEnum;
          result.status = valueDes;
          break;
        case r'deviceId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.deviceId = valueDes;
          break;
        case r'mutationId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.mutationId = valueDes;
          break;
        case r'operationId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.operationId = valueDes;
          break;
        case r'expectedGeneration':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.expectedGeneration = valueDes;
          break;
        case r'expectedKeyEpoch':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.expectedKeyEpoch = valueDes;
          break;
        case r'expectedMembershipManifestDigest':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.expectedMembershipManifestDigest = valueDes;
          break;
        case r'intentDigest':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.intentDigest = valueDes;
          break;
        case r'intentSignature':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.intentSignature = valueDes;
          break;
        case r'requestedAt':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(DateTime),
                  )
                  as DateTime;
          result.requestedAt = valueDes;
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
        case r'receiptExpiresAt':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(DateTime),
                  )
                  as DateTime;
          result.receiptExpiresAt = valueDes;
          break;
        case r'receipt':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      SelfRevocationStatusDataOneOf1Receipt,
                    ),
                  )
                  as SelfRevocationStatusDataOneOf1Receipt;
          result.receipt.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  SelfRevocationStatusDataOneOf1 deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SelfRevocationStatusDataOneOf1Builder();
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

class SelfRevocationStatusDataOneOf1StatusEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'confirmed')
  static const SelfRevocationStatusDataOneOf1StatusEnum confirmed =
      _$selfRevocationStatusDataOneOf1StatusEnum_confirmed;

  static Serializer<SelfRevocationStatusDataOneOf1StatusEnum> get serializer =>
      _$selfRevocationStatusDataOneOf1StatusEnumSerializer;

  const SelfRevocationStatusDataOneOf1StatusEnum._(String name) : super(name);

  static BuiltSet<SelfRevocationStatusDataOneOf1StatusEnum> get values =>
      _$selfRevocationStatusDataOneOf1StatusEnumValues;
  static SelfRevocationStatusDataOneOf1StatusEnum valueOf(String name) =>
      _$selfRevocationStatusDataOneOf1StatusEnumValueOf(name);
}
