//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/sync_conflict_details_fields_inner_current.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'sync_conflict_details_fields_inner.g.dart';

/// SyncConflictDetailsFieldsInner
///
/// Properties:
/// * [path]
/// * [current]
/// * [desired]
@BuiltValue()
abstract class SyncConflictDetailsFieldsInner
    implements
        Built<
          SyncConflictDetailsFieldsInner,
          SyncConflictDetailsFieldsInnerBuilder
        > {
  @BuiltValueField(wireName: r'path')
  String get path;

  @BuiltValueField(wireName: r'current')
  SyncConflictDetailsFieldsInnerCurrent get current;

  @BuiltValueField(wireName: r'desired')
  SyncConflictDetailsFieldsInnerCurrent get desired;

  SyncConflictDetailsFieldsInner._();

  factory SyncConflictDetailsFieldsInner([
    void updates(SyncConflictDetailsFieldsInnerBuilder b),
  ]) = _$SyncConflictDetailsFieldsInner;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SyncConflictDetailsFieldsInnerBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<SyncConflictDetailsFieldsInner> get serializer =>
      _$SyncConflictDetailsFieldsInnerSerializer();
}

class _$SyncConflictDetailsFieldsInnerSerializer
    implements PrimitiveSerializer<SyncConflictDetailsFieldsInner> {
  @override
  final Iterable<Type> types = const [
    SyncConflictDetailsFieldsInner,
    _$SyncConflictDetailsFieldsInner,
  ];

  @override
  final String wireName = r'SyncConflictDetailsFieldsInner';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    SyncConflictDetailsFieldsInner object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'path';
    yield serializers.serialize(
      object.path,
      specifiedType: const FullType(String),
    );
    yield r'current';
    yield serializers.serialize(
      object.current,
      specifiedType: const FullType(SyncConflictDetailsFieldsInnerCurrent),
    );
    yield r'desired';
    yield serializers.serialize(
      object.desired,
      specifiedType: const FullType(SyncConflictDetailsFieldsInnerCurrent),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    SyncConflictDetailsFieldsInner object, {
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
    required SyncConflictDetailsFieldsInnerBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'path':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.path = valueDes;
          break;
        case r'current':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      SyncConflictDetailsFieldsInnerCurrent,
                    ),
                  )
                  as SyncConflictDetailsFieldsInnerCurrent;
          result.current.replace(valueDes);
          break;
        case r'desired':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      SyncConflictDetailsFieldsInnerCurrent,
                    ),
                  )
                  as SyncConflictDetailsFieldsInnerCurrent;
          result.desired.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  SyncConflictDetailsFieldsInner deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SyncConflictDetailsFieldsInnerBuilder();
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
