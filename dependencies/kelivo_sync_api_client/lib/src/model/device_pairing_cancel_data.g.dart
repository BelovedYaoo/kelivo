// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_pairing_cancel_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const DevicePairingCancelDataResultEnum
_$devicePairingCancelDataResultEnum_cancelled =
    const DevicePairingCancelDataResultEnum._('cancelled');

DevicePairingCancelDataResultEnum _$devicePairingCancelDataResultEnumValueOf(
  String name,
) {
  switch (name) {
    case 'cancelled':
      return _$devicePairingCancelDataResultEnum_cancelled;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<DevicePairingCancelDataResultEnum>
_$devicePairingCancelDataResultEnumValues =
    BuiltSet<DevicePairingCancelDataResultEnum>(
      const <DevicePairingCancelDataResultEnum>[
        _$devicePairingCancelDataResultEnum_cancelled,
      ],
    );

Serializer<DevicePairingCancelDataResultEnum>
_$devicePairingCancelDataResultEnumSerializer =
    _$DevicePairingCancelDataResultEnumSerializer();

class _$DevicePairingCancelDataResultEnumSerializer
    implements PrimitiveSerializer<DevicePairingCancelDataResultEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'cancelled': 'cancelled',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'cancelled': 'cancelled',
  };

  @override
  final Iterable<Type> types = const <Type>[DevicePairingCancelDataResultEnum];
  @override
  final String wireName = 'DevicePairingCancelDataResultEnum';

  @override
  Object serialize(
    Serializers serializers,
    DevicePairingCancelDataResultEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  DevicePairingCancelDataResultEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => DevicePairingCancelDataResultEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$DevicePairingCancelData extends DevicePairingCancelData {
  @override
  final int protocolVersion;
  @override
  final String pairingId;
  @override
  final DevicePairingCancelDataResultEnum result;
  @override
  final DateTime cancelledAt;

  factory _$DevicePairingCancelData([
    void Function(DevicePairingCancelDataBuilder)? updates,
  ]) => (DevicePairingCancelDataBuilder()..update(updates))._build();

  _$DevicePairingCancelData._({
    required this.protocolVersion,
    required this.pairingId,
    required this.result,
    required this.cancelledAt,
  }) : super._();
  @override
  DevicePairingCancelData rebuild(
    void Function(DevicePairingCancelDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  DevicePairingCancelDataBuilder toBuilder() =>
      DevicePairingCancelDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DevicePairingCancelData &&
        protocolVersion == other.protocolVersion &&
        pairingId == other.pairingId &&
        result == other.result &&
        cancelledAt == other.cancelledAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, protocolVersion.hashCode);
    _$hash = $jc(_$hash, pairingId.hashCode);
    _$hash = $jc(_$hash, result.hashCode);
    _$hash = $jc(_$hash, cancelledAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'DevicePairingCancelData')
          ..add('protocolVersion', protocolVersion)
          ..add('pairingId', pairingId)
          ..add('result', result)
          ..add('cancelledAt', cancelledAt))
        .toString();
  }
}

class DevicePairingCancelDataBuilder
    implements
        Builder<DevicePairingCancelData, DevicePairingCancelDataBuilder> {
  _$DevicePairingCancelData? _$v;

  int? _protocolVersion;
  int? get protocolVersion => _$this._protocolVersion;
  set protocolVersion(int? protocolVersion) =>
      _$this._protocolVersion = protocolVersion;

  String? _pairingId;
  String? get pairingId => _$this._pairingId;
  set pairingId(String? pairingId) => _$this._pairingId = pairingId;

  DevicePairingCancelDataResultEnum? _result;
  DevicePairingCancelDataResultEnum? get result => _$this._result;
  set result(DevicePairingCancelDataResultEnum? result) =>
      _$this._result = result;

  DateTime? _cancelledAt;
  DateTime? get cancelledAt => _$this._cancelledAt;
  set cancelledAt(DateTime? cancelledAt) => _$this._cancelledAt = cancelledAt;

  DevicePairingCancelDataBuilder() {
    DevicePairingCancelData._defaults(this);
  }

  DevicePairingCancelDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _protocolVersion = $v.protocolVersion;
      _pairingId = $v.pairingId;
      _result = $v.result;
      _cancelledAt = $v.cancelledAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DevicePairingCancelData other) {
    _$v = other as _$DevicePairingCancelData;
  }

  @override
  void update(void Function(DevicePairingCancelDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DevicePairingCancelData build() => _build();

  _$DevicePairingCancelData _build() {
    final _$result =
        _$v ??
        _$DevicePairingCancelData._(
          protocolVersion: BuiltValueNullFieldError.checkNotNull(
            protocolVersion,
            r'DevicePairingCancelData',
            'protocolVersion',
          ),
          pairingId: BuiltValueNullFieldError.checkNotNull(
            pairingId,
            r'DevicePairingCancelData',
            'pairingId',
          ),
          result: BuiltValueNullFieldError.checkNotNull(
            result,
            r'DevicePairingCancelData',
            'result',
          ),
          cancelledAt: BuiltValueNullFieldError.checkNotNull(
            cancelledAt,
            r'DevicePairingCancelData',
            'cancelledAt',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
