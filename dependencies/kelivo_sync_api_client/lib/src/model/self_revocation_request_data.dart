//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'self_revocation_request_data.g.dart';

/// SelfRevocationRequestData
///
/// Properties:
/// * [result]
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
@BuiltValue()
abstract class SelfRevocationRequestData
    implements
        Built<SelfRevocationRequestData, SelfRevocationRequestDataBuilder> {
  @BuiltValueField(wireName: r'result')
  SelfRevocationRequestDataResultEnum get result;
  // enum resultEnum {  requested,  };

  @BuiltValueField(wireName: r'status')
  SelfRevocationRequestDataStatusEnum get status;
  // enum statusEnum {  pending,  };

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

  SelfRevocationRequestData._();

  factory SelfRevocationRequestData([
    void updates(SelfRevocationRequestDataBuilder b),
  ]) = _$SelfRevocationRequestData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SelfRevocationRequestDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<SelfRevocationRequestData> get serializer =>
      _$SelfRevocationRequestDataSerializer();
}

class _$SelfRevocationRequestDataSerializer
    implements PrimitiveSerializer<SelfRevocationRequestData> {
  @override
  final Iterable<Type> types = const [
    SelfRevocationRequestData,
    _$SelfRevocationRequestData,
  ];

  @override
  final String wireName = r'SelfRevocationRequestData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    SelfRevocationRequestData object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'result';
    yield serializers.serialize(
      object.result,
      specifiedType: const FullType(SelfRevocationRequestDataResultEnum),
    );
    yield r'status';
    yield serializers.serialize(
      object.status,
      specifiedType: const FullType(SelfRevocationRequestDataStatusEnum),
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
  }

  @override
  Object serialize(
    Serializers serializers,
    SelfRevocationRequestData object, {
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
    required SelfRevocationRequestDataBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'result':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      SelfRevocationRequestDataResultEnum,
                    ),
                  )
                  as SelfRevocationRequestDataResultEnum;
          result.result = valueDes;
          break;
        case r'status':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      SelfRevocationRequestDataStatusEnum,
                    ),
                  )
                  as SelfRevocationRequestDataStatusEnum;
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
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  SelfRevocationRequestData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SelfRevocationRequestDataBuilder();
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

class SelfRevocationRequestDataResultEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'requested')
  static const SelfRevocationRequestDataResultEnum requested =
      _$selfRevocationRequestDataResultEnum_requested;

  static Serializer<SelfRevocationRequestDataResultEnum> get serializer =>
      _$selfRevocationRequestDataResultEnumSerializer;

  const SelfRevocationRequestDataResultEnum._(String name) : super(name);

  static BuiltSet<SelfRevocationRequestDataResultEnum> get values =>
      _$selfRevocationRequestDataResultEnumValues;
  static SelfRevocationRequestDataResultEnum valueOf(String name) =>
      _$selfRevocationRequestDataResultEnumValueOf(name);
}

class SelfRevocationRequestDataStatusEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'pending')
  static const SelfRevocationRequestDataStatusEnum pending =
      _$selfRevocationRequestDataStatusEnum_pending;

  static Serializer<SelfRevocationRequestDataStatusEnum> get serializer =>
      _$selfRevocationRequestDataStatusEnumSerializer;

  const SelfRevocationRequestDataStatusEnum._(String name) : super(name);

  static BuiltSet<SelfRevocationRequestDataStatusEnum> get values =>
      _$selfRevocationRequestDataStatusEnumValues;
  static SelfRevocationRequestDataStatusEnum valueOf(String name) =>
      _$selfRevocationRequestDataStatusEnumValueOf(name);
}
