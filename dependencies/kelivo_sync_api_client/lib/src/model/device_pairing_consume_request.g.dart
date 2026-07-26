// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_pairing_consume_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$DevicePairingConsumeRequest extends DevicePairingConsumeRequest {
  @override
  final int protocolVersion;
  @override
  final String pairingId;

  factory _$DevicePairingConsumeRequest([
    void Function(DevicePairingConsumeRequestBuilder)? updates,
  ]) => (DevicePairingConsumeRequestBuilder()..update(updates))._build();

  _$DevicePairingConsumeRequest._({
    required this.protocolVersion,
    required this.pairingId,
  }) : super._();
  @override
  DevicePairingConsumeRequest rebuild(
    void Function(DevicePairingConsumeRequestBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  DevicePairingConsumeRequestBuilder toBuilder() =>
      DevicePairingConsumeRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DevicePairingConsumeRequest &&
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
    return (newBuiltValueToStringHelper(r'DevicePairingConsumeRequest')
          ..add('protocolVersion', protocolVersion)
          ..add('pairingId', pairingId))
        .toString();
  }
}

class DevicePairingConsumeRequestBuilder
    implements
        Builder<
          DevicePairingConsumeRequest,
          DevicePairingConsumeRequestBuilder
        > {
  _$DevicePairingConsumeRequest? _$v;

  int? _protocolVersion;
  int? get protocolVersion => _$this._protocolVersion;
  set protocolVersion(int? protocolVersion) =>
      _$this._protocolVersion = protocolVersion;

  String? _pairingId;
  String? get pairingId => _$this._pairingId;
  set pairingId(String? pairingId) => _$this._pairingId = pairingId;

  DevicePairingConsumeRequestBuilder() {
    DevicePairingConsumeRequest._defaults(this);
  }

  DevicePairingConsumeRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _protocolVersion = $v.protocolVersion;
      _pairingId = $v.pairingId;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DevicePairingConsumeRequest other) {
    _$v = other as _$DevicePairingConsumeRequest;
  }

  @override
  void update(void Function(DevicePairingConsumeRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DevicePairingConsumeRequest build() => _build();

  _$DevicePairingConsumeRequest _build() {
    final _$result =
        _$v ??
        _$DevicePairingConsumeRequest._(
          protocolVersion: BuiltValueNullFieldError.checkNotNull(
            protocolVersion,
            r'DevicePairingConsumeRequest',
            'protocolVersion',
          ),
          pairingId: BuiltValueNullFieldError.checkNotNull(
            pairingId,
            r'DevicePairingConsumeRequest',
            'pairingId',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
