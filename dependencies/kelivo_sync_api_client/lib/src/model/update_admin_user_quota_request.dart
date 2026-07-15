//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'update_admin_user_quota_request.g.dart';

/// UpdateAdminUserQuotaRequest
///
/// Properties:
/// * [userId]
/// * [attachmentQuotaBytes] - 附件配额字节数，0 表示禁止占用附件存储
@BuiltValue()
abstract class UpdateAdminUserQuotaRequest
    implements
        Built<UpdateAdminUserQuotaRequest, UpdateAdminUserQuotaRequestBuilder> {
  @BuiltValueField(wireName: r'userId')
  String get userId;

  /// 附件配额字节数，0 表示禁止占用附件存储
  @BuiltValueField(wireName: r'attachmentQuotaBytes')
  int get attachmentQuotaBytes;

  UpdateAdminUserQuotaRequest._();

  factory UpdateAdminUserQuotaRequest([
    void updates(UpdateAdminUserQuotaRequestBuilder b),
  ]) = _$UpdateAdminUserQuotaRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(UpdateAdminUserQuotaRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<UpdateAdminUserQuotaRequest> get serializer =>
      _$UpdateAdminUserQuotaRequestSerializer();
}

class _$UpdateAdminUserQuotaRequestSerializer
    implements PrimitiveSerializer<UpdateAdminUserQuotaRequest> {
  @override
  final Iterable<Type> types = const [
    UpdateAdminUserQuotaRequest,
    _$UpdateAdminUserQuotaRequest,
  ];

  @override
  final String wireName = r'UpdateAdminUserQuotaRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    UpdateAdminUserQuotaRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'userId';
    yield serializers.serialize(
      object.userId,
      specifiedType: const FullType(String),
    );
    yield r'attachmentQuotaBytes';
    yield serializers.serialize(
      object.attachmentQuotaBytes,
      specifiedType: const FullType(int),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    UpdateAdminUserQuotaRequest object, {
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
    required UpdateAdminUserQuotaRequestBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'userId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.userId = valueDes;
          break;
        case r'attachmentQuotaBytes':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.attachmentQuotaBytes = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  UpdateAdminUserQuotaRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = UpdateAdminUserQuotaRequestBuilder();
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
