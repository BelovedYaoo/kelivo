//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'data_rekey_source_attachment_list_request.g.dart';

/// DataRekeySourceAttachmentListRequest
///
/// Properties:
/// * [operationId]
/// * [sourceDataGeneration]
/// * [targetKeyEpoch]
/// * [leaseToken]
/// * [leaseVersion]
/// * [afterAttachmentId]
/// * [limit]
@BuiltValue()
abstract class DataRekeySourceAttachmentListRequest
    implements
        Built<
          DataRekeySourceAttachmentListRequest,
          DataRekeySourceAttachmentListRequestBuilder
        > {
  @BuiltValueField(wireName: r'operationId')
  String get operationId;

  @BuiltValueField(wireName: r'sourceDataGeneration')
  int get sourceDataGeneration;

  @BuiltValueField(wireName: r'targetKeyEpoch')
  int get targetKeyEpoch;

  @BuiltValueField(wireName: r'leaseToken')
  String get leaseToken;

  @BuiltValueField(wireName: r'leaseVersion')
  int get leaseVersion;

  @BuiltValueField(wireName: r'afterAttachmentId')
  String? get afterAttachmentId;

  @BuiltValueField(wireName: r'limit')
  int? get limit;

  DataRekeySourceAttachmentListRequest._();

  factory DataRekeySourceAttachmentListRequest([
    void updates(DataRekeySourceAttachmentListRequestBuilder b),
  ]) = _$DataRekeySourceAttachmentListRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DataRekeySourceAttachmentListRequestBuilder b) =>
      b..limit = 10;

  @BuiltValueSerializer(custom: true)
  static Serializer<DataRekeySourceAttachmentListRequest> get serializer =>
      _$DataRekeySourceAttachmentListRequestSerializer();
}

class _$DataRekeySourceAttachmentListRequestSerializer
    implements PrimitiveSerializer<DataRekeySourceAttachmentListRequest> {
  @override
  final Iterable<Type> types = const [
    DataRekeySourceAttachmentListRequest,
    _$DataRekeySourceAttachmentListRequest,
  ];

  @override
  final String wireName = r'DataRekeySourceAttachmentListRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DataRekeySourceAttachmentListRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'operationId';
    yield serializers.serialize(
      object.operationId,
      specifiedType: const FullType(String),
    );
    yield r'sourceDataGeneration';
    yield serializers.serialize(
      object.sourceDataGeneration,
      specifiedType: const FullType(int),
    );
    yield r'targetKeyEpoch';
    yield serializers.serialize(
      object.targetKeyEpoch,
      specifiedType: const FullType(int),
    );
    yield r'leaseToken';
    yield serializers.serialize(
      object.leaseToken,
      specifiedType: const FullType(String),
    );
    yield r'leaseVersion';
    yield serializers.serialize(
      object.leaseVersion,
      specifiedType: const FullType(int),
    );
    if (object.afterAttachmentId != null) {
      yield r'afterAttachmentId';
      yield serializers.serialize(
        object.afterAttachmentId,
        specifiedType: const FullType.nullable(String),
      );
    }
    if (object.limit != null) {
      yield r'limit';
      yield serializers.serialize(
        object.limit,
        specifiedType: const FullType(int),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    DataRekeySourceAttachmentListRequest object, {
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
    required DataRekeySourceAttachmentListRequestBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'operationId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.operationId = valueDes;
          break;
        case r'sourceDataGeneration':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.sourceDataGeneration = valueDes;
          break;
        case r'targetKeyEpoch':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.targetKeyEpoch = valueDes;
          break;
        case r'leaseToken':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.leaseToken = valueDes;
          break;
        case r'leaseVersion':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.leaseVersion = valueDes;
          break;
        case r'afterAttachmentId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType.nullable(String),
                  )
                  as String?;
          if (valueDes == null) continue;
          result.afterAttachmentId = valueDes;
          break;
        case r'limit':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.limit = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  DataRekeySourceAttachmentListRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DataRekeySourceAttachmentListRequestBuilder();
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
