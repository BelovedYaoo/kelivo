// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_pairing_query_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$DevicePairingQueryRequest extends DevicePairingQueryRequest {
  @override
  final int protocolVersion;
  @override
  final String pairingId;

  factory _$DevicePairingQueryRequest([
    void Function(DevicePairingQueryRequestBuilder)? updates,
  ]) => (DevicePairingQueryRequestBuilder()..update(updates))._build();

  _$DevicePairingQueryRequest._({
    required this.protocolVersion,
    required this.pairingId,
  }) : super._();
  @override
  DevicePairingQueryRequest rebuild(
    void Function(DevicePairingQueryRequestBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  DevicePairingQueryRequestBuilder toBuilder() =>
      DevicePairingQueryRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DevicePairingQueryRequest &&
        protocolVersion == other.protocolVersion &&
        pairingId == other.pairingId;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, protocolVersion.hashCode);
    _$hash = $jc(_$hash, pairingId.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'DevicePairingQueryRequest')
          ..add('protocolVersion', protocolVersion)
          ..add('pairingId', pairingId))
        .toString();
  }
}

class DevicePairingQueryRequestBuilder
    implements
        Builder<DevicePairingQueryRequest, DevicePairingQueryRequestBuilder> {
  _$DevicePairingQueryRequest? _$v;

  int? _protocolVersion;
  int? get protocolVersion => _$this._protocolVersion;
  set protocolVersion(int? protocolVersion) =>
      _$this._protocolVersion = protocolVersion;

  String? _pairingId;
  String? get pairingId => _$this._pairingId;
  set pairingId(String? pairingId) => _$this._pairingId = pairingId;

  DevicePairingQueryRequestBuilder() {
    DevicePairingQueryRequest._defaults(this);
  }

  DevicePairingQueryRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _protocolVersion = $v.protocolVersion;
      _pairingId = $v.pairingId;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DevicePairingQueryRequest other) {
    _$v = other as _$DevicePairingQueryRequest;
  }

  @override
  void update(void Function(DevicePairingQueryRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DevicePairingQueryRequest build() => _build();

  _$DevicePairingQueryRequest _build() {
    final _$result =
        _$v ??
        _$DevicePairingQueryRequest._(
          protocolVersion: BuiltValueNullFieldError.checkNotNull(
            protocolVersion,
            r'DevicePairingQueryRequest',
            'protocolVersion',
          ),
          pairingId: BuiltValueNullFieldError.checkNotNull(
            pairingId,
            r'DevicePairingQueryRequest',
            'pairingId',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
