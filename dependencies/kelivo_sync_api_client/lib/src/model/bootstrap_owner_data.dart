//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/user_summary.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'bootstrap_owner_data.g.dart';

/// BootstrapOwnerData
///
/// Properties:
/// * [user]
@BuiltValue()
abstract class BootstrapOwnerData
    implements Built<BootstrapOwnerData, BootstrapOwnerDataBuilder> {
  @BuiltValueField(wireName: r'user')
  UserSummary get user;

  BootstrapOwnerData._();

  factory BootstrapOwnerData([void updates(BootstrapOwnerDataBuilder b)]) =
      _$BootstrapOwnerData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(BootstrapOwnerDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<BootstrapOwnerData> get serializer =>
      _$BootstrapOwnerDataSerializer();
}

class _$BootstrapOwnerDataSerializer
    implements PrimitiveSerializer<BootstrapOwnerData> {
  @override
  final Iterable<Type> types = const [BootstrapOwnerData, _$BootstrapOwnerData];

  @override
  final String wireName = r'BootstrapOwnerData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    BootstrapOwnerData object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'user';
    yield serializers.serialize(
      object.user,
      specifiedType: const FullType(UserSummary),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    BootstrapOwnerData object, {
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
    required BootstrapOwnerDataBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'user':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(UserSummary),
                  )
                  as UserSummary;
          result.user.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  BootstrapOwnerData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = BootstrapOwnerDataBuilder();
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
