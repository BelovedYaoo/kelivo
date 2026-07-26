// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_pairing_approve_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const DevicePairingApproveDataResultEnum
_$devicePairingApproveDataResultEnum_approved =
    const DevicePairingApproveDataResultEnum._('approved');

DevicePairingApproveDataResultEnum _$devicePairingApproveDataResultEnumValueOf(
  String name,
) {
  switch (name) {
    case 'approved':
      return _$devicePairingApproveDataResultEnum_approved;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<DevicePairingApproveDataResultEnum>
_$devicePairingApproveDataResultEnumValues =
    BuiltSet<DevicePairingApproveDataResultEnum>(
      const <DevicePairingApproveDataResultEnum>[
        _$devicePairingApproveDataResultEnum_approved,
      ],
    );

Serializer<DevicePairingApproveDataResultEnum>
_$devicePairingApproveDataResultEnumSerializer =
    _$DevicePairingApproveDataResultEnumSerializer();

class _$DevicePairingApproveDataResultEnumSerializer
    implements PrimitiveSerializer<DevicePairingApproveDataResultEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'approved': 'approved',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'approved': 'approved',
  };

  @override
  final Iterable<Type> types = const <Type>[DevicePairingApproveDataResultEnum];
  @override
  final String wireName = 'DevicePairingApproveDataResultEnum';

  @override
  Object serialize(
    Serializers serializers,
    DevicePairingApproveDataResultEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  DevicePairingApproveDataResultEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => DevicePairingApproveDataResultEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$DevicePairingApproveData extends DevicePairingApproveData {
  @override
  final int protocolVersion;
  @override
  final String pairingId;
  @override
  final DevicePairingApproveDataResultEnum result;
  @override
  final DateTime approvedAt;

  factory _$DevicePairingApproveData([
    void Function(DevicePairingApproveDataBuilder)? updates,
  ]) => (DevicePairingApproveDataBuilder()..update(updates))._build();

  _$DevicePairingApproveData._({
    required this.protocolVersion,
    required this.pairingId,
    required this.result,
    required this.approvedAt,
  }) : super._();
  @override
  DevicePairingApproveData rebuild(
    void Function(DevicePairingApproveDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  DevicePairingApproveDataBuilder toBuilder() =>
      DevicePairingApproveDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DevicePairingApproveData &&
        protocolVersion == other.protocolVersion &&
        pairingId == other.pairingId &&
        result == other.result &&
        approvedAt == other.approvedAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, protocolVersion.hashCode);
    _$hash = $jc(_$hash, pairingId.hashCode);
    _$hash = $jc(_$hash, result.hashCode);
    _$hash = $jc(_$hash, approvedAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'DevicePairingApproveData')
          ..add('protocolVersion', protocolVersion)
          ..add('pairingId', pairingId)
          ..add('result', result)
          ..add('approvedAt', approvedAt))
        .toString();
  }
}

class DevicePairingApproveDataBuilder
    implements
        Builder<DevicePairingApproveData, DevicePairingApproveDataBuilder> {
  _$DevicePairingApproveData? _$v;

  int? _protocolVersion;
  int? get protocolVersion => _$this._protocolVersion;
  set protocolVersion(int? protocolVersion) =>
      _$this._protocolVersion = protocolVersion;

  String? _pairingId;
  String? get pairingId => _$this._pairingId;
  set pairingId(String? pairingId) => _$this._pairingId = pairingId;

  DevicePairingApproveDataResultEnum? _result;
  DevicePairingApproveDataResultEnum? get result => _$this._result;
  set result(DevicePairingApproveDataResultEnum? result) =>
      _$this._result = result;

  DateTime? _approvedAt;
  DateTime? get approvedAt => _$this._approvedAt;
  set approvedAt(DateTime? approvedAt) => _$this._approvedAt = approvedAt;

  DevicePairingApproveDataBuilder() {
    DevicePairingApproveData._defaults(this);
  }

  DevicePairingApproveDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _protocolVersion = $v.protocolVersion;
      _pairingId = $v.pairingId;
      _result = $v.result;
      _approvedAt = $v.approvedAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DevicePairingApproveData other) {
    _$v = other as _$DevicePairingApproveData;
  }

  @override
  void update(void Function(DevicePairingApproveDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DevicePairingApproveData build() => _build();

  _$DevicePairingApproveData _build() {
    final _$result =
        _$v ??
        _$DevicePairingApproveData._(
          protocolVersion: BuiltValueNullFieldError.checkNotNull(
            protocolVersion,
            r'DevicePairingApproveData',
            'protocolVersion',
          ),
          pairingId: BuiltValueNullFieldError.checkNotNull(
            pairingId,
            r'DevicePairingApproveData',
            'pairingId',
          ),
          result: BuiltValueNullFieldError.checkNotNull(
            result,
            r'DevicePairingApproveData',
            'result',
          ),
          approvedAt: BuiltValueNullFieldError.checkNotNull(
            approvedAt,
            r'DevicePairingApproveData',
            'approvedAt',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
