//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'commit_device_rotation_data.g.dart';

/// CommitDeviceRotationData
///
/// Properties:
/// * [result]
/// * [operationId]
/// * [revokedDeviceId]
/// * [fromGeneration]
/// * [generation]
/// * [keyEpoch]
/// * [dataRekeyPhase]
/// * [membershipManifestDigest]
/// * [committedAt]
@BuiltValue()
abstract class CommitDeviceRotationData
    implements
        Built<CommitDeviceRotationData, CommitDeviceRotationDataBuilder> {
  @BuiltValueField(wireName: r'result')
  CommitDeviceRotationDataResultEnum get result;
  // enum resultEnum {  committed,  };

  @BuiltValueField(wireName: r'operationId')
  String get operationId;

  @BuiltValueField(wireName: r'revokedDeviceId')
  String get revokedDeviceId;

  @BuiltValueField(wireName: r'fromGeneration')
  int get fromGeneration;

  @BuiltValueField(wireName: r'generation')
  int get generation;

  @BuiltValueField(wireName: r'keyEpoch')
  int get keyEpoch;

  @BuiltValueField(wireName: r'dataRekeyPhase')
  CommitDeviceRotationDataDataRekeyPhaseEnum get dataRekeyPhase;
  // enum dataRekeyPhaseEnum {  rekey-pending,  };

  @BuiltValueField(wireName: r'membershipManifestDigest')
  String get membershipManifestDigest;

  @BuiltValueField(wireName: r'committedAt')
  DateTime get committedAt;

  CommitDeviceRotationData._();

  factory CommitDeviceRotationData([
    void updates(CommitDeviceRotationDataBuilder b),
  ]) = _$CommitDeviceRotationData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(CommitDeviceRotationDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<CommitDeviceRotationData> get serializer =>
      _$CommitDeviceRotationDataSerializer();
}

class _$CommitDeviceRotationDataSerializer
    implements PrimitiveSerializer<CommitDeviceRotationData> {
  @override
  final Iterable<Type> types = const [
    CommitDeviceRotationData,
    _$CommitDeviceRotationData,
  ];

  @override
  final String wireName = r'CommitDeviceRotationData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    CommitDeviceRotationData object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'result';
    yield serializers.serialize(
      object.result,
      specifiedType: const FullType(CommitDeviceRotationDataResultEnum),
    );
    yield r'operationId';
    yield serializers.serialize(
      object.operationId,
      specifiedType: const FullType(String),
    );
    yield r'revokedDeviceId';
    yield serializers.serialize(
      object.revokedDeviceId,
      specifiedType: const FullType(String),
    );
    yield r'fromGeneration';
    yield serializers.serialize(
      object.fromGeneration,
      specifiedType: const FullType(int),
    );
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
      specifiedType: const FullType(CommitDeviceRotationDataDataRekeyPhaseEnum),
    );
    yield r'membershipManifestDigest';
    yield serializers.serialize(
      object.membershipManifestDigest,
      specifiedType: const FullType(String),
    );
    yield r'committedAt';
    yield serializers.serialize(
      object.committedAt,
      specifiedType: const FullType(DateTime),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    CommitDeviceRotationData object, {
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
    required CommitDeviceRotationDataBuilder result,
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
                      CommitDeviceRotationDataResultEnum,
                    ),
                  )
                  as CommitDeviceRotationDataResultEnum;
          result.result = valueDes;
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
        case r'revokedDeviceId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.revokedDeviceId = valueDes;
          break;
        case r'fromGeneration':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.fromGeneration = valueDes;
          break;
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
                      CommitDeviceRotationDataDataRekeyPhaseEnum,
                    ),
                  )
                  as CommitDeviceRotationDataDataRekeyPhaseEnum;
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
        case r'committedAt':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(DateTime),
                  )
                  as DateTime;
          result.committedAt = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  CommitDeviceRotationData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = CommitDeviceRotationDataBuilder();
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

class CommitDeviceRotationDataResultEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'committed')
  static const CommitDeviceRotationDataResultEnum committed =
      _$commitDeviceRotationDataResultEnum_committed;

  static Serializer<CommitDeviceRotationDataResultEnum> get serializer =>
      _$commitDeviceRotationDataResultEnumSerializer;

  const CommitDeviceRotationDataResultEnum._(String name) : super(name);

  static BuiltSet<CommitDeviceRotationDataResultEnum> get values =>
      _$commitDeviceRotationDataResultEnumValues;
  static CommitDeviceRotationDataResultEnum valueOf(String name) =>
      _$commitDeviceRotationDataResultEnumValueOf(name);
}

class CommitDeviceRotationDataDataRekeyPhaseEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'rekey-pending')
  static const CommitDeviceRotationDataDataRekeyPhaseEnum rekeyPending =
      _$commitDeviceRotationDataDataRekeyPhaseEnum_rekeyPending;

  static Serializer<CommitDeviceRotationDataDataRekeyPhaseEnum>
  get serializer => _$commitDeviceRotationDataDataRekeyPhaseEnumSerializer;

  const CommitDeviceRotationDataDataRekeyPhaseEnum._(String name) : super(name);

  static BuiltSet<CommitDeviceRotationDataDataRekeyPhaseEnum> get values =>
      _$commitDeviceRotationDataDataRekeyPhaseEnumValues;
  static CommitDeviceRotationDataDataRekeyPhaseEnum valueOf(String name) =>
      _$commitDeviceRotationDataDataRekeyPhaseEnumValueOf(name);
}
