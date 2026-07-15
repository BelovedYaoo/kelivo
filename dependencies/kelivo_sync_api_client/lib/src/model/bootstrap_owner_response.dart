//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/bootstrap_owner_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'bootstrap_owner_response.g.dart';

/// BootstrapOwnerResponse
///
/// Properties:
/// * [data]
@BuiltValue()
abstract class BootstrapOwnerResponse
    implements Built<BootstrapOwnerResponse, BootstrapOwnerResponseBuilder> {
  @BuiltValueField(wireName: r'data')
  BootstrapOwnerData get data;

  BootstrapOwnerResponse._();

  factory BootstrapOwnerResponse([
    void updates(BootstrapOwnerResponseBuilder b),
  ]) = _$BootstrapOwnerResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(BootstrapOwnerResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<BootstrapOwnerResponse> get serializer =>
      _$BootstrapOwnerResponseSerializer();
}

class _$BootstrapOwnerResponseSerializer
    implements PrimitiveSerializer<BootstrapOwnerResponse> {
  @override
  final Iterable<Type> types = const [
    BootstrapOwnerResponse,
    _$BootstrapOwnerResponse,
  ];

  @override
  final String wireName = r'BootstrapOwnerResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    BootstrapOwnerResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(BootstrapOwnerData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    BootstrapOwnerResponse object, {
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
    required BootstrapOwnerResponseBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'data':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(BootstrapOwnerData),
                  )
                  as BootstrapOwnerData;
          result.data.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  BootstrapOwnerResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = BootstrapOwnerResponseBuilder();
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
