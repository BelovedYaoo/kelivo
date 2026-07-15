//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'system_health_data.g.dart';

/// SystemHealthData
///
/// Properties:
/// * [service]
/// * [status]
/// * [timestamp]
@BuiltValue()
abstract class SystemHealthData
    implements Built<SystemHealthData, SystemHealthDataBuilder> {
  @BuiltValueField(wireName: r'service')
  SystemHealthDataServiceEnum get service;
  // enum serviceEnum {  kelivo-api,  };

  @BuiltValueField(wireName: r'status')
  SystemHealthDataStatusEnum get status;
  // enum statusEnum {  ok,  };

  @BuiltValueField(wireName: r'timestamp')
  DateTime get timestamp;

  SystemHealthData._();

  factory SystemHealthData([void updates(SystemHealthDataBuilder b)]) =
      _$SystemHealthData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SystemHealthDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<SystemHealthData> get serializer =>
      _$SystemHealthDataSerializer();
}

class _$SystemHealthDataSerializer
    implements PrimitiveSerializer<SystemHealthData> {
  @override
  final Iterable<Type> types = const [SystemHealthData, _$SystemHealthData];

  @override
  final String wireName = r'SystemHealthData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    SystemHealthData object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'service';
    yield serializers.serialize(
      object.service,
      specifiedType: const FullType(SystemHealthDataServiceEnum),
    );
    yield r'status';
    yield serializers.serialize(
      object.status,
      specifiedType: const FullType(SystemHealthDataStatusEnum),
    );
    yield r'timestamp';
    yield serializers.serialize(
      object.timestamp,
      specifiedType: const FullType(DateTime),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    SystemHealthData object, {
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
    required SystemHealthDataBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'service':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(SystemHealthDataServiceEnum),
                  )
                  as SystemHealthDataServiceEnum;
          result.service = valueDes;
          break;
        case r'status':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(SystemHealthDataStatusEnum),
                  )
                  as SystemHealthDataStatusEnum;
          result.status = valueDes;
          break;
        case r'timestamp':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(DateTime),
                  )
                  as DateTime;
          result.timestamp = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  SystemHealthData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SystemHealthDataBuilder();
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

class SystemHealthDataServiceEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'kelivo-api')
  static const SystemHealthDataServiceEnum kelivoApi =
      _$systemHealthDataServiceEnum_kelivoApi;

  static Serializer<SystemHealthDataServiceEnum> get serializer =>
      _$systemHealthDataServiceEnumSerializer;

  const SystemHealthDataServiceEnum._(String name) : super(name);

  static BuiltSet<SystemHealthDataServiceEnum> get values =>
      _$systemHealthDataServiceEnumValues;
  static SystemHealthDataServiceEnum valueOf(String name) =>
      _$systemHealthDataServiceEnumValueOf(name);
}

class SystemHealthDataStatusEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'ok')
  static const SystemHealthDataStatusEnum ok = _$systemHealthDataStatusEnum_ok;

  static Serializer<SystemHealthDataStatusEnum> get serializer =>
      _$systemHealthDataStatusEnumSerializer;

  const SystemHealthDataStatusEnum._(String name) : super(name);

  static BuiltSet<SystemHealthDataStatusEnum> get values =>
      _$systemHealthDataStatusEnumValues;
  static SystemHealthDataStatusEnum valueOf(String name) =>
      _$systemHealthDataStatusEnumValueOf(name);
}
