//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'self_revocation_status_data_one_of2.g.dart';

/// SelfRevocationStatusDataOneOf2
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
/// * [cancelledAt]
@BuiltValue()
abstract class SelfRevocationStatusDataOneOf2
    implements
        Built<
          SelfRevocationStatusDataOneOf2,
          SelfRevocationStatusDataOneOf2Builder
        > {
  @BuiltValueField(wireName: r'status')
  SelfRevocationStatusDataOneOf2StatusEnum get status;
  // enum statusEnum {  cancelled,  };

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

  @BuiltValueField(wireName: r'cancelledAt')
  DateTime get cancelledAt;

  SelfRevocationStatusDataOneOf2._();

  factory SelfRevocationStatusDataOneOf2([
    void updates(SelfRevocationStatusDataOneOf2Builder b),
  ]) = _$SelfRevocationStatusDataOneOf2;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SelfRevocationStatusDataOneOf2Builder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<SelfRevocationStatusDataOneOf2> get serializer =>
      _$SelfRevocationStatusDataOneOf2Serializer();
}

class _$SelfRevocationStatusDataOneOf2Serializer
    implements PrimitiveSerializer<SelfRevocationStatusDataOneOf2> {
  @override
  final Iterable<Type> types = const [
    SelfRevocationStatusDataOneOf2,
    _$SelfRevocationStatusDataOneOf2,
  ];

  @override
  final String wireName = r'SelfRevocationStatusDataOneOf2';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    SelfRevocationStatusDataOneOf2 object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'status';
    yield serializers.serialize(
      object.status,
      specifiedType: const FullType(SelfRevocationStatusDataOneOf2StatusEnum),
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
    yield r'cancelledAt';
    yield serializers.serialize(
      object.cancelledAt,
      specifiedType: const FullType(DateTime),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    SelfRevocationStatusDataOneOf2 object, {
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
    required SelfRevocationStatusDataOneOf2Builder result,
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
                      SelfRevocationStatusDataOneOf2StatusEnum,
                    ),
                  )
                  as SelfRevocationStatusDataOneOf2StatusEnum;
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
        case r'cancelledAt':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(DateTime),
                  )
                  as DateTime;
          result.cancelledAt = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  SelfRevocationStatusDataOneOf2 deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SelfRevocationStatusDataOneOf2Builder();
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

class SelfRevocationStatusDataOneOf2StatusEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'cancelled')
  static const SelfRevocationStatusDataOneOf2StatusEnum cancelled =
      _$selfRevocationStatusDataOneOf2StatusEnum_cancelled;

  static Serializer<SelfRevocationStatusDataOneOf2StatusEnum> get serializer =>
      _$selfRevocationStatusDataOneOf2StatusEnumSerializer;

  const SelfRevocationStatusDataOneOf2StatusEnum._(String name) : super(name);

  static BuiltSet<SelfRevocationStatusDataOneOf2StatusEnum> get values =>
      _$selfRevocationStatusDataOneOf2StatusEnumValues;
  static SelfRevocationStatusDataOneOf2StatusEnum valueOf(String name) =>
      _$selfRevocationStatusDataOneOf2StatusEnumValueOf(name);
}
