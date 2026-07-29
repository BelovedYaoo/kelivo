// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_rekey_pending_lease_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$DataRekeyPendingLeaseData extends DataRekeyPendingLeaseData {
  @override
  final int leaseVersion;
  @override
  final bool ownedByCurrentDevice;
  @override
  final DateTime expiresAt;

  factory _$DataRekeyPendingLeaseData([
    void Function(DataRekeyPendingLeaseDataBuilder)? updates,
  ]) => (DataRekeyPendingLeaseDataBuilder()..update(updates))._build();

  _$DataRekeyPendingLeaseData._({
    required this.leaseVersion,
    required this.ownedByCurrentDevice,
    required this.expiresAt,
  }) : super._();
  @override
  DataRekeyPendingLeaseData rebuild(
    void Function(DataRekeyPendingLeaseDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  DataRekeyPendingLeaseDataBuilder toBuilder() =>
      DataRekeyPendingLeaseDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DataRekeyPendingLeaseData &&
        leaseVersion == other.leaseVersion &&
        ownedByCurrentDevice == other.ownedByCurrentDevice &&
        expiresAt == other.expiresAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, leaseVersion.hashCode);
    _$hash = $jc(_$hash, ownedByCurrentDevice.hashCode);
    _$hash = $jc(_$hash, expiresAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'DataRekeyPendingLeaseData')
          ..add('leaseVersion', leaseVersion)
          ..add('ownedByCurrentDevice', ownedByCurrentDevice)
          ..add('expiresAt', expiresAt))
        .toString();
  }
}

class DataRekeyPendingLeaseDataBuilder
    implements
        Builder<DataRekeyPendingLeaseData, DataRekeyPendingLeaseDataBuilder> {
  _$DataRekeyPendingLeaseData? _$v;

  int? _leaseVersion;
  int? get leaseVersion => _$this._leaseVersion;
  set leaseVersion(int? leaseVersion) => _$this._leaseVersion = leaseVersion;

  bool? _ownedByCurrentDevice;
  bool? get ownedByCurrentDevice => _$this._ownedByCurrentDevice;
  set ownedByCurrentDevice(bool? ownedByCurrentDevice) =>
      _$this._ownedByCurrentDevice = ownedByCurrentDevice;

  DateTime? _expiresAt;
  DateTime? get expiresAt => _$this._expiresAt;
  set expiresAt(DateTime? expiresAt) => _$this._expiresAt = expiresAt;

  DataRekeyPendingLeaseDataBuilder() {
    DataRekeyPendingLeaseData._defaults(this);
  }

  DataRekeyPendingLeaseDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _leaseVersion = $v.leaseVersion;
      _ownedByCurrentDevice = $v.ownedByCurrentDevice;
      _expiresAt = $v.expiresAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DataRekeyPendingLeaseData other) {
    _$v = other as _$DataRekeyPendingLeaseData;
  }

  @override
  void update(void Function(DataRekeyPendingLeaseDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DataRekeyPendingLeaseData build() => _build();

  _$DataRekeyPendingLeaseData _build() {
    final _$result =
        _$v ??
        _$DataRekeyPendingLeaseData._(
          leaseVersion: BuiltValueNullFieldError.checkNotNull(
            leaseVersion,
            r'DataRekeyPendingLeaseData',
            'leaseVersion',
          ),
          ownedByCurrentDevice: BuiltValueNullFieldError.checkNotNull(
            ownedByCurrentDevice,
            r'DataRekeyPendingLeaseData',
            'ownedByCurrentDevice',
          ),
          expiresAt: BuiltValueNullFieldError.checkNotNull(
            expiresAt,
            r'DataRekeyPendingLeaseData',
            'expiresAt',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
