// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'initialize_device_security_state_envelope.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$InitializeDeviceSecurityStateEnvelope
    extends InitializeDeviceSecurityStateEnvelope {
  @override
  final String targetDeviceId;
  @override
  final int envelopeVersion;
  @override
  final int keyEpoch;
  @override
  final String accountKeyEnvelope;

  factory _$InitializeDeviceSecurityStateEnvelope([
    void Function(InitializeDeviceSecurityStateEnvelopeBuilder)? updates,
  ]) => (InitializeDeviceSecurityStateEnvelopeBuilder()..update(updates))
      ._build();

  _$InitializeDeviceSecurityStateEnvelope._({
    required this.targetDeviceId,
    required this.envelopeVersion,
    required this.keyEpoch,
    required this.accountKeyEnvelope,
  }) : super._();
  @override
  InitializeDeviceSecurityStateEnvelope rebuild(
    void Function(InitializeDeviceSecurityStateEnvelopeBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  InitializeDeviceSecurityStateEnvelopeBuilder toBuilder() =>
      InitializeDeviceSecurityStateEnvelopeBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is InitializeDeviceSecurityStateEnvelope &&
        targetDeviceId == other.targetDeviceId &&
        envelopeVersion == other.envelopeVersion &&
        keyEpoch == other.keyEpoch &&
        accountKeyEnvelope == other.accountKeyEnvelope;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, targetDeviceId.hashCode);
    _$hash = $jc(_$hash, envelopeVersion.hashCode);
    _$hash = $jc(_$hash, keyEpoch.hashCode);
    _$hash = $jc(_$hash, accountKeyEnvelope.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(
            r'InitializeDeviceSecurityStateEnvelope',
          )
          ..add('targetDeviceId', targetDeviceId)
          ..add('envelopeVersion', envelopeVersion)
          ..add('keyEpoch', keyEpoch)
          ..add('accountKeyEnvelope', accountKeyEnvelope))
        .toString();
  }
}

class InitializeDeviceSecurityStateEnvelopeBuilder
    implements
        Builder<
          InitializeDeviceSecurityStateEnvelope,
          InitializeDeviceSecurityStateEnvelopeBuilder
        > {
  _$InitializeDeviceSecurityStateEnvelope? _$v;

  String? _targetDeviceId;
  String? get targetDeviceId => _$this._targetDeviceId;
  set targetDeviceId(String? targetDeviceId) =>
      _$this._targetDeviceId = targetDeviceId;

  int? _envelopeVersion;
  int? get envelopeVersion => _$this._envelopeVersion;
  set envelopeVersion(int? envelopeVersion) =>
      _$this._envelopeVersion = envelopeVersion;

  int? _keyEpoch;
  int? get keyEpoch => _$this._keyEpoch;
  set keyEpoch(int? keyEpoch) => _$this._keyEpoch = keyEpoch;

  String? _accountKeyEnvelope;
  String? get accountKeyEnvelope => _$this._accountKeyEnvelope;
  set accountKeyEnvelope(String? accountKeyEnvelope) =>
      _$this._accountKeyEnvelope = accountKeyEnvelope;

  InitializeDeviceSecurityStateEnvelopeBuilder() {
    InitializeDeviceSecurityStateEnvelope._defaults(this);
  }

  InitializeDeviceSecurityStateEnvelopeBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _targetDeviceId = $v.targetDeviceId;
      _envelopeVersion = $v.envelopeVersion;
      _keyEpoch = $v.keyEpoch;
      _accountKeyEnvelope = $v.accountKeyEnvelope;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(InitializeDeviceSecurityStateEnvelope other) {
    _$v = other as _$InitializeDeviceSecurityStateEnvelope;
  }

  @override
  void update(
    void Function(InitializeDeviceSecurityStateEnvelopeBuilder)? updates,
  ) {
    if (updates != null) updates(this);
  }

  @override
  InitializeDeviceSecurityStateEnvelope build() => _build();

  _$InitializeDeviceSecurityStateEnvelope _build() {
    final _$result =
        _$v ??
        _$InitializeDeviceSecurityStateEnvelope._(
          targetDeviceId: BuiltValueNullFieldError.checkNotNull(
            targetDeviceId,
            r'InitializeDeviceSecurityStateEnvelope',
            'targetDeviceId',
          ),
          envelopeVersion: BuiltValueNullFieldError.checkNotNull(
            envelopeVersion,
            r'InitializeDeviceSecurityStateEnvelope',
            'envelopeVersion',
          ),
          keyEpoch: BuiltValueNullFieldError.checkNotNull(
            keyEpoch,
            r'InitializeDeviceSecurityStateEnvelope',
            'keyEpoch',
          ),
          accountKeyEnvelope: BuiltValueNullFieldError.checkNotNull(
            accountKeyEnvelope,
            r'InitializeDeviceSecurityStateEnvelope',
            'accountKeyEnvelope',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
