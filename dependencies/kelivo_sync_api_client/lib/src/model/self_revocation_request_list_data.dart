//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/pending_self_revocation_request.dart';
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'self_revocation_request_list_data.g.dart';

/// SelfRevocationRequestListData
///
/// Properties:
/// * [requests]
@BuiltValue()
abstract class SelfRevocationRequestListData
    implements
        Built<
          SelfRevocationRequestListData,
          SelfRevocationRequestListDataBuilder
        > {
  @BuiltValueField(wireName: r'requests')
  BuiltList<PendingSelfRevocationRequest> get requests;

  SelfRevocationRequestListData._();

  factory SelfRevocationRequestListData([
    void updates(SelfRevocationRequestListDataBuilder b),
  ]) = _$SelfRevocationRequestListData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SelfRevocationRequestListDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<SelfRevocationRequestListData> get serializer =>
      _$SelfRevocationRequestListDataSerializer();
}

class _$SelfRevocationRequestListDataSerializer
    implements PrimitiveSerializer<SelfRevocationRequestListData> {
  @override
  final Iterable<Type> types = const [
    SelfRevocationRequestListData,
    _$SelfRevocationRequestListData,
  ];

  @override
  final String wireName = r'SelfRevocationRequestListData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    SelfRevocationRequestListData object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'requests';
    yield serializers.serialize(
      object.requests,
      specifiedType: const FullType(BuiltList, [
        FullType(PendingSelfRevocationRequest),
      ]),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    SelfRevocationRequestListData object, {
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
    required SelfRevocationRequestListDataBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'requests':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(BuiltList, [
                      FullType(PendingSelfRevocationRequest),
                    ]),
                  )
                  as BuiltList<PendingSelfRevocationRequest>;
          result.requests.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  SelfRevocationRequestListData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SelfRevocationRequestListDataBuilder();
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
