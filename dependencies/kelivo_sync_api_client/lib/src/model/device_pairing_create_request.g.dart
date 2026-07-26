// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_pairing_create_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$DevicePairingCreateRequest extends DevicePairingCreateRequest {
  @override
  final int protocolVersion;
  @override
  final String pairingId;
  @override
  final String pairingSecretHash;

  factory _$DevicePairingCreateRequest([
    void Function(DevicePairingCreateRequestBuilder)? updates,
  ]) => (DevicePairingCreateRequestBuilder()..update(updates))._build();

  _$DevicePairingCreateRequest._({
    required this.protocolVersion,
    required this.pairingId,
    required this.pairingSecretHash,
  }) : super._();
  @override
  DevicePairingCreateRequest rebuild(
    void Function(DevicePairingCreateRequestBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  DevicePairingCreateRequestBuilder toBuilder() =>
      DevicePairingCreateRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DevicePairingCreateRequest &&
        protocolVersion == other.protocolVersion &&
        pairingId == other.pairingId &&
        pairingSecretHash == other.pairingSecretHash;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, protocolVersion.hashCode);
    _$hash = $jc(_$hash, pairingId.hashCode);
    _$hash = $jc(_$hash, pairingSecretHash.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'DevicePairingCreateRequest')
          ..add('protocolVersion', protocolVersion)
          ..add('pairingId', pairingId)
          ..add('pairingSecretHash', pairingSecretHash))
        .toString();
  }
}

class DevicePairingCreateRequestBuilder
    implements
        Builder<DevicePairingCreateRequest, DevicePairingCreateRequestBuilder> {
  _$DevicePairingCreateRequest? _$v;

  int? _protocolVersion;
  int? get protocolVersion => _$this._protocolVersion;
  set protocolVersion(int? protocolVersion) =>
      _$this._protocolVersion = protocolVersion;

  String? _pairingId;
  String? get pairingId => _$this._pairingId;
  set pairingId(String? pairingId) => _$this._pairingId = pairingId;

  String? _pairingSecretHash;
  String? get pairingSecretHash => _$this._pairingSecretHash;
  set pairingSecretHash(String? pairingSecretHash) =>
      _$this._pairingSecretHash = pairingSecretHash;

  DevicePairingCreateRequestBuilder() {
    DevicePairingCreateRequest._defaults(this);
  }

  DevicePairingCreateRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _protocolVersion = $v.protocolVersion;
      _pairingId = $v.pairingId;
      _pairingSecretHash = $v.pairingSecretHash;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DevicePairingCreateRequest other) {
    _$v = other as _$DevicePairingCreateRequest;
  }

  @override
  void update(void Function(DevicePairingCreateRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DevicePairingCreateRequest build() => _build();

  _$DevicePairingCreateRequest _build() {
    final _$result =
        _$v ??
        _$DevicePairingCreateRequest._(
          protocolVersion: BuiltValueNullFieldError.checkNotNull(
            protocolVersion,
            r'DevicePairingCreateRequest',
            'protocolVersion',
          ),
          pairingId: BuiltValueNullFieldError.checkNotNull(
            pairingId,
            r'DevicePairingCreateRequest',
            'pairingId',
          ),
          pairingSecretHash: BuiltValueNullFieldError.checkNotNull(
            pairingSecretHash,
            r'DevicePairingCreateRequest',
            'pairingSecretHash',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
