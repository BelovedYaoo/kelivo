//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'cancel_self_revocation_request.g.dart';

/// CancelSelfRevocationRequest
///
/// Properties:
/// * [mutationId]
@BuiltValue()
abstract class CancelSelfRevocationRequest
    implements
        Built<CancelSelfRevocationRequest, CancelSelfRevocationRequestBuilder> {
  @BuiltValueField(wireName: r'mutationId')
  String get mutationId;

  CancelSelfRevocationRequest._();

  factory CancelSelfRevocationRequest([
    void updates(CancelSelfRevocationRequestBuilder b),
  ]) = _$CancelSelfRevocationRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(CancelSelfRevocationRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<CancelSelfRevocationRequest> get serializer =>
      _$CancelSelfRevocationRequestSerializer();
}

class _$CancelSelfRevocationRequestSerializer
    implements PrimitiveSerializer<CancelSelfRevocationRequest> {
  @override
  final Iterable<Type> types = const [
    CancelSelfRevocationRequest,
    _$CancelSelfRevocationRequest,
  ];

  @override
  final String wireName = r'CancelSelfRevocationRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    CancelSelfRevocationRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'mutationId';
    yield serializers.serialize(
      object.mutationId,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    CancelSelfRevocationRequest object, {
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
    required CancelSelfRevocationRequestBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'mutationId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.mutationId = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  CancelSelfRevocationRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = CancelSelfRevocationRequestBuilder();
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
