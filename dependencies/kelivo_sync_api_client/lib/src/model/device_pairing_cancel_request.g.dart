// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_pairing_cancel_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$DevicePairingCancelRequest extends DevicePairingCancelRequest {
  @override
  final int protocolVersion;
  @override
  final String pairingId;

  factory _$DevicePairingCancelRequest([
    void Function(DevicePairingCancelRequestBuilder)? updates,
  ]) => (DevicePairingCancelRequestBuilder()..update(updates))._build();

  _$DevicePairingCancelRequest._({
    required this.protocolVersion,
    required this.pairingId,
  }) : super._();
  @override
  DevicePairingCancelRequest rebuild(
    void Function(DevicePairingCancelRequestBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  DevicePairingCancelRequestBuilder toBuilder() =>
      DevicePairingCancelRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DevicePairingCancelRequest &&
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
    return (newBuiltValueToStringHelper(r'DevicePairingCancelRequest')
          ..add('protocolVersion', protocolVersion)
          ..add('pairingId', pairingId))
        .toString();
  }
}

class DevicePairingCancelRequestBuilder
    implements
        Builder<DevicePairingCancelRequest, DevicePairingCancelRequestBuilder> {
  _$DevicePairingCancelRequest? _$v;

  int? _protocolVersion;
  int? get protocolVersion => _$this._protocolVersion;
  set protocolVersion(int? protocolVersion) =>
      _$this._protocolVersion = protocolVersion;

  String? _pairingId;
  String? get pairingId => _$this._pairingId;
  set pairingId(String? pairingId) => _$this._pairingId = pairingId;

  DevicePairingCancelRequestBuilder() {
    DevicePairingCancelRequest._defaults(this);
  }

  DevicePairingCancelRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _protocolVersion = $v.protocolVersion;
      _pairingId = $v.pairingId;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DevicePairingCancelRequest other) {
    _$v = other as _$DevicePairingCancelRequest;
  }

  @override
  void update(void Function(DevicePairingCancelRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DevicePairingCancelRequest build() => _build();

  _$DevicePairingCancelRequest _build() {
    final _$result =
        _$v ??
        _$DevicePairingCancelRequest._(
          protocolVersion: BuiltValueNullFieldError.checkNotNull(
            protocolVersion,
            r'DevicePairingCancelRequest',
            'protocolVersion',
          ),
          pairingId: BuiltValueNullFieldError.checkNotNull(
            pairingId,
            r'DevicePairingCancelRequest',
            'pairingId',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
