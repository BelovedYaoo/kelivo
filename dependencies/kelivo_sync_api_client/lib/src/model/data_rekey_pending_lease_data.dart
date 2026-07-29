//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'data_rekey_pending_lease_data.g.dart';

/// DataRekeyPendingLeaseData
///
/// Properties:
/// * [leaseVersion]
/// * [ownedByCurrentDevice]
/// * [expiresAt]
@BuiltValue()
abstract class DataRekeyPendingLeaseData
    implements
        Built<DataRekeyPendingLeaseData, DataRekeyPendingLeaseDataBuilder> {
  @BuiltValueField(wireName: r'leaseVersion')
  int get leaseVersion;

  @BuiltValueField(wireName: r'ownedByCurrentDevice')
  bool get ownedByCurrentDevice;

  @BuiltValueField(wireName: r'expiresAt')
  DateTime get expiresAt;

  DataRekeyPendingLeaseData._();

  factory DataRekeyPendingLeaseData([
    void updates(DataRekeyPendingLeaseDataBuilder b),
  ]) = _$DataRekeyPendingLeaseData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DataRekeyPendingLeaseDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DataRekeyPendingLeaseData> get serializer =>
      _$DataRekeyPendingLeaseDataSerializer();
}

class _$DataRekeyPendingLeaseDataSerializer
    implements PrimitiveSerializer<DataRekeyPendingLeaseData> {
  @override
  final Iterable<Type> types = const [
    DataRekeyPendingLeaseData,
    _$DataRekeyPendingLeaseData,
  ];

  @override
  final String wireName = r'DataRekeyPendingLeaseData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DataRekeyPendingLeaseData object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'leaseVersion';
    yield serializers.serialize(
      object.leaseVersion,
      specifiedType: const FullType(int),
    );
    yield r'ownedByCurrentDevice';
    yield serializers.serialize(
      object.ownedByCurrentDevice,
      specifiedType: const FullType(bool),
    );
    yield r'expiresAt';
    yield serializers.serialize(
      object.expiresAt,
      specifiedType: const FullType(DateTime),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    DataRekeyPendingLeaseData object, {
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
    required DataRekeyPendingLeaseDataBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'leaseVersion':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.leaseVersion = valueDes;
          break;
        case r'ownedByCurrentDevice':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(bool),
                  )
                  as bool;
          result.ownedByCurrentDevice = valueDes;
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
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  DataRekeyPendingLeaseData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DataRekeyPendingLeaseDataBuilder();
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
