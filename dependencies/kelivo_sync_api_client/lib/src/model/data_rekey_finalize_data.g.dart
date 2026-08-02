// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_rekey_finalize_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const DataRekeyFinalizeDataResultEnum
_$dataRekeyFinalizeDataResultEnum_verificationPending =
    const DataRekeyFinalizeDataResultEnum._('verificationPending');

DataRekeyFinalizeDataResultEnum _$dataRekeyFinalizeDataResultEnumValueOf(
  String name,
) {
  switch (name) {
    case 'verificationPending':
      return _$dataRekeyFinalizeDataResultEnum_verificationPending;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<DataRekeyFinalizeDataResultEnum>
_$dataRekeyFinalizeDataResultEnumValues =
    BuiltSet<DataRekeyFinalizeDataResultEnum>(
      const <DataRekeyFinalizeDataResultEnum>[
        _$dataRekeyFinalizeDataResultEnum_verificationPending,
      ],
    );

const DataRekeyFinalizeDataPhaseEnum
_$dataRekeyFinalizeDataPhaseEnum_sourceRecords =
    const DataRekeyFinalizeDataPhaseEnum._('sourceRecords');
const DataRekeyFinalizeDataPhaseEnum
_$dataRekeyFinalizeDataPhaseEnum_sourceAttachments =
    const DataRekeyFinalizeDataPhaseEnum._('sourceAttachments');
const DataRekeyFinalizeDataPhaseEnum
_$dataRekeyFinalizeDataPhaseEnum_stagedRecords =
    const DataRekeyFinalizeDataPhaseEnum._('stagedRecords');
const DataRekeyFinalizeDataPhaseEnum
_$dataRekeyFinalizeDataPhaseEnum_stagedAttachments =
    const DataRekeyFinalizeDataPhaseEnum._('stagedAttachments');
const DataRekeyFinalizeDataPhaseEnum _$dataRekeyFinalizeDataPhaseEnum_verified =
    const DataRekeyFinalizeDataPhaseEnum._('verified');

DataRekeyFinalizeDataPhaseEnum _$dataRekeyFinalizeDataPhaseEnumValueOf(
  String name,
) {
  switch (name) {
    case 'sourceRecords':
      return _$dataRekeyFinalizeDataPhaseEnum_sourceRecords;
    case 'sourceAttachments':
      return _$dataRekeyFinalizeDataPhaseEnum_sourceAttachments;
    case 'stagedRecords':
      return _$dataRekeyFinalizeDataPhaseEnum_stagedRecords;
    case 'stagedAttachments':
      return _$dataRekeyFinalizeDataPhaseEnum_stagedAttachments;
    case 'verified':
      return _$dataRekeyFinalizeDataPhaseEnum_verified;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<DataRekeyFinalizeDataPhaseEnum>
_$dataRekeyFinalizeDataPhaseEnumValues =
    BuiltSet<DataRekeyFinalizeDataPhaseEnum>(
      const <DataRekeyFinalizeDataPhaseEnum>[
        _$dataRekeyFinalizeDataPhaseEnum_sourceRecords,
        _$dataRekeyFinalizeDataPhaseEnum_sourceAttachments,
        _$dataRekeyFinalizeDataPhaseEnum_stagedRecords,
        _$dataRekeyFinalizeDataPhaseEnum_stagedAttachments,
        _$dataRekeyFinalizeDataPhaseEnum_verified,
      ],
    );

Serializer<DataRekeyFinalizeDataResultEnum>
_$dataRekeyFinalizeDataResultEnumSerializer =
    _$DataRekeyFinalizeDataResultEnumSerializer();
Serializer<DataRekeyFinalizeDataPhaseEnum>
_$dataRekeyFinalizeDataPhaseEnumSerializer =
    _$DataRekeyFinalizeDataPhaseEnumSerializer();

class _$DataRekeyFinalizeDataResultEnumSerializer
    implements PrimitiveSerializer<DataRekeyFinalizeDataResultEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'verificationPending': 'verification-pending',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'verification-pending': 'verificationPending',
  };

  @override
  final Iterable<Type> types = const <Type>[DataRekeyFinalizeDataResultEnum];
  @override
  final String wireName = 'DataRekeyFinalizeDataResultEnum';

  @override
  Object serialize(
    Serializers serializers,
    DataRekeyFinalizeDataResultEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  DataRekeyFinalizeDataResultEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => DataRekeyFinalizeDataResultEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$DataRekeyFinalizeDataPhaseEnumSerializer
    implements PrimitiveSerializer<DataRekeyFinalizeDataPhaseEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'sourceRecords': 'source-records',
    'sourceAttachments': 'source-attachments',
    'stagedRecords': 'staged-records',
    'stagedAttachments': 'staged-attachments',
    'verified': 'verified',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'source-records': 'sourceRecords',
    'source-attachments': 'sourceAttachments',
    'staged-records': 'stagedRecords',
    'staged-attachments': 'stagedAttachments',
    'verified': 'verified',
  };

  @override
  final Iterable<Type> types = const <Type>[DataRekeyFinalizeDataPhaseEnum];
  @override
  final String wireName = 'DataRekeyFinalizeDataPhaseEnum';

  @override
  Object serialize(
    Serializers serializers,
    DataRekeyFinalizeDataPhaseEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  DataRekeyFinalizeDataPhaseEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => DataRekeyFinalizeDataPhaseEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$DataRekeyFinalizeData extends DataRekeyFinalizeData {
  @override
  final OneOf oneOf;

  factory _$DataRekeyFinalizeData([
    void Function(DataRekeyFinalizeDataBuilder)? updates,
  ]) => (DataRekeyFinalizeDataBuilder()..update(updates))._build();

  _$DataRekeyFinalizeData._({required this.oneOf}) : super._();
  @override
  DataRekeyFinalizeData rebuild(
    void Function(DataRekeyFinalizeDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  DataRekeyFinalizeDataBuilder toBuilder() =>
      DataRekeyFinalizeDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DataRekeyFinalizeData && oneOf == other.oneOf;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, oneOf.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(
      r'DataRekeyFinalizeData',
    )..add('oneOf', oneOf)).toString();
  }
}

class DataRekeyFinalizeDataBuilder
    implements Builder<DataRekeyFinalizeData, DataRekeyFinalizeDataBuilder> {
  _$DataRekeyFinalizeData? _$v;

  OneOf? _oneOf;
  OneOf? get oneOf => _$this._oneOf;
  set oneOf(OneOf? oneOf) => _$this._oneOf = oneOf;

  DataRekeyFinalizeDataBuilder() {
    DataRekeyFinalizeData._defaults(this);
  }

  DataRekeyFinalizeDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _oneOf = $v.oneOf;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DataRekeyFinalizeData other) {
    _$v = other as _$DataRekeyFinalizeData;
  }

  @override
  void update(void Function(DataRekeyFinalizeDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DataRekeyFinalizeData build() => _build();

  _$DataRekeyFinalizeData _build() {
    final _$result =
        _$v ??
        _$DataRekeyFinalizeData._(
          oneOf: BuiltValueNullFieldError.checkNotNull(
            oneOf,
            r'DataRekeyFinalizeData',
            'oneOf',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
