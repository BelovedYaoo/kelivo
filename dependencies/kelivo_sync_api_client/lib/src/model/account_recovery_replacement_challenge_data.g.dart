// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_recovery_replacement_challenge_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const AccountRecoveryReplacementChallengeDataResultEnum
_$accountRecoveryReplacementChallengeDataResultEnum_created =
    const AccountRecoveryReplacementChallengeDataResultEnum._('created');
const AccountRecoveryReplacementChallengeDataResultEnum
_$accountRecoveryReplacementChallengeDataResultEnum_replayed =
    const AccountRecoveryReplacementChallengeDataResultEnum._('replayed');

AccountRecoveryReplacementChallengeDataResultEnum
_$accountRecoveryReplacementChallengeDataResultEnumValueOf(String name) {
  switch (name) {
    case 'created':
      return _$accountRecoveryReplacementChallengeDataResultEnum_created;
    case 'replayed':
      return _$accountRecoveryReplacementChallengeDataResultEnum_replayed;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<AccountRecoveryReplacementChallengeDataResultEnum>
_$accountRecoveryReplacementChallengeDataResultEnumValues =
    BuiltSet<AccountRecoveryReplacementChallengeDataResultEnum>(
      const <AccountRecoveryReplacementChallengeDataResultEnum>[
        _$accountRecoveryReplacementChallengeDataResultEnum_created,
        _$accountRecoveryReplacementChallengeDataResultEnum_replayed,
      ],
    );

Serializer<AccountRecoveryReplacementChallengeDataResultEnum>
_$accountRecoveryReplacementChallengeDataResultEnumSerializer =
    _$AccountRecoveryReplacementChallengeDataResultEnumSerializer();

class _$AccountRecoveryReplacementChallengeDataResultEnumSerializer
    implements
        PrimitiveSerializer<AccountRecoveryReplacementChallengeDataResultEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'created': 'created',
    'replayed': 'replayed',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'created': 'created',
    'replayed': 'replayed',
  };

  @override
  final Iterable<Type> types = const <Type>[
    AccountRecoveryReplacementChallengeDataResultEnum,
  ];
  @override
  final String wireName = 'AccountRecoveryReplacementChallengeDataResultEnum';

  @override
  Object serialize(
    Serializers serializers,
    AccountRecoveryReplacementChallengeDataResultEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  AccountRecoveryReplacementChallengeDataResultEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => AccountRecoveryReplacementChallengeDataResultEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$AccountRecoveryReplacementChallengeData
    extends AccountRecoveryReplacementChallengeData {
  @override
  final AccountRecoveryReplacementChallengeDataResultEnum result;
  @override
  final int protocolVersion;
  @override
  final String challengeId;
  @override
  final String attemptId;
  @override
  final String requestDigest;
  @override
  final String challengeFrame;
  @override
  final String sealedNonce;
  @override
  final AccountRecoveryReplacementChallengeDataDeviceState deviceState;
  @override
  final AccountRecoveryReplacementChallengeDataSecurityState securityState;
  @override
  final AccountRecoveryReplacementChallengeDataDataState dataState;
  @override
  final DataRekeyCompletionProofData sourceCompletion;
  @override
  final DateTime expiresAt;

  factory _$AccountRecoveryReplacementChallengeData([
    void Function(AccountRecoveryReplacementChallengeDataBuilder)? updates,
  ]) => (AccountRecoveryReplacementChallengeDataBuilder()..update(updates))
      ._build();

  _$AccountRecoveryReplacementChallengeData._({
    required this.result,
    required this.protocolVersion,
    required this.challengeId,
    required this.attemptId,
    required this.requestDigest,
    required this.challengeFrame,
    required this.sealedNonce,
    required this.deviceState,
    required this.securityState,
    required this.dataState,
    required this.sourceCompletion,
    required this.expiresAt,
  }) : super._();
  @override
  AccountRecoveryReplacementChallengeData rebuild(
    void Function(AccountRecoveryReplacementChallengeDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  AccountRecoveryReplacementChallengeDataBuilder toBuilder() =>
      AccountRecoveryReplacementChallengeDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AccountRecoveryReplacementChallengeData &&
        result == other.result &&
        protocolVersion == other.protocolVersion &&
        challengeId == other.challengeId &&
        attemptId == other.attemptId &&
        requestDigest == other.requestDigest &&
        challengeFrame == other.challengeFrame &&
        sealedNonce == other.sealedNonce &&
        deviceState == other.deviceState &&
        securityState == other.securityState &&
        dataState == other.dataState &&
        sourceCompletion == other.sourceCompletion &&
        expiresAt == other.expiresAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, result.hashCode);
    _$hash = $jc(_$hash, protocolVersion.hashCode);
    _$hash = $jc(_$hash, challengeId.hashCode);
    _$hash = $jc(_$hash, attemptId.hashCode);
    _$hash = $jc(_$hash, requestDigest.hashCode);
    _$hash = $jc(_$hash, challengeFrame.hashCode);
    _$hash = $jc(_$hash, sealedNonce.hashCode);
    _$hash = $jc(_$hash, deviceState.hashCode);
    _$hash = $jc(_$hash, securityState.hashCode);
    _$hash = $jc(_$hash, dataState.hashCode);
    _$hash = $jc(_$hash, sourceCompletion.hashCode);
    _$hash = $jc(_$hash, expiresAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(
            r'AccountRecoveryReplacementChallengeData',
          )
          ..add('result', result)
          ..add('protocolVersion', protocolVersion)
          ..add('challengeId', challengeId)
          ..add('attemptId', attemptId)
          ..add('requestDigest', requestDigest)
          ..add('challengeFrame', challengeFrame)
          ..add('sealedNonce', sealedNonce)
          ..add('deviceState', deviceState)
          ..add('securityState', securityState)
          ..add('dataState', dataState)
          ..add('sourceCompletion', sourceCompletion)
          ..add('expiresAt', expiresAt))
        .toString();
  }
}

class AccountRecoveryReplacementChallengeDataBuilder
    implements
        Builder<
          AccountRecoveryReplacementChallengeData,
          AccountRecoveryReplacementChallengeDataBuilder
        > {
  _$AccountRecoveryReplacementChallengeData? _$v;

  AccountRecoveryReplacementChallengeDataResultEnum? _result;
  AccountRecoveryReplacementChallengeDataResultEnum? get result =>
      _$this._result;
  set result(AccountRecoveryReplacementChallengeDataResultEnum? result) =>
      _$this._result = result;

  int? _protocolVersion;
  int? get protocolVersion => _$this._protocolVersion;
  set protocolVersion(int? protocolVersion) =>
      _$this._protocolVersion = protocolVersion;

  String? _challengeId;
  String? get challengeId => _$this._challengeId;
  set challengeId(String? challengeId) => _$this._challengeId = challengeId;

  String? _attemptId;
  String? get attemptId => _$this._attemptId;
  set attemptId(String? attemptId) => _$this._attemptId = attemptId;

  String? _requestDigest;
  String? get requestDigest => _$this._requestDigest;
  set requestDigest(String? requestDigest) =>
      _$this._requestDigest = requestDigest;

  String? _challengeFrame;
  String? get challengeFrame => _$this._challengeFrame;
  set challengeFrame(String? challengeFrame) =>
      _$this._challengeFrame = challengeFrame;

  String? _sealedNonce;
  String? get sealedNonce => _$this._sealedNonce;
  set sealedNonce(String? sealedNonce) => _$this._sealedNonce = sealedNonce;

  AccountRecoveryReplacementChallengeDataDeviceStateBuilder? _deviceState;
  AccountRecoveryReplacementChallengeDataDeviceStateBuilder get deviceState =>
      _$this._deviceState ??=
          AccountRecoveryReplacementChallengeDataDeviceStateBuilder();
  set deviceState(
    AccountRecoveryReplacementChallengeDataDeviceStateBuilder? deviceState,
  ) => _$this._deviceState = deviceState;

  AccountRecoveryReplacementChallengeDataSecurityStateBuilder? _securityState;
  AccountRecoveryReplacementChallengeDataSecurityStateBuilder
  get securityState => _$this._securityState ??=
      AccountRecoveryReplacementChallengeDataSecurityStateBuilder();
  set securityState(
    AccountRecoveryReplacementChallengeDataSecurityStateBuilder? securityState,
  ) => _$this._securityState = securityState;

  AccountRecoveryReplacementChallengeDataDataStateBuilder? _dataState;
  AccountRecoveryReplacementChallengeDataDataStateBuilder get dataState =>
      _$this._dataState ??=
          AccountRecoveryReplacementChallengeDataDataStateBuilder();
  set dataState(
    AccountRecoveryReplacementChallengeDataDataStateBuilder? dataState,
  ) => _$this._dataState = dataState;

  DataRekeyCompletionProofDataBuilder? _sourceCompletion;
  DataRekeyCompletionProofDataBuilder get sourceCompletion =>
      _$this._sourceCompletion ??= DataRekeyCompletionProofDataBuilder();
  set sourceCompletion(DataRekeyCompletionProofDataBuilder? sourceCompletion) =>
      _$this._sourceCompletion = sourceCompletion;

  DateTime? _expiresAt;
  DateTime? get expiresAt => _$this._expiresAt;
  set expiresAt(DateTime? expiresAt) => _$this._expiresAt = expiresAt;

  AccountRecoveryReplacementChallengeDataBuilder() {
    AccountRecoveryReplacementChallengeData._defaults(this);
  }

  AccountRecoveryReplacementChallengeDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _result = $v.result;
      _protocolVersion = $v.protocolVersion;
      _challengeId = $v.challengeId;
      _attemptId = $v.attemptId;
      _requestDigest = $v.requestDigest;
      _challengeFrame = $v.challengeFrame;
      _sealedNonce = $v.sealedNonce;
      _deviceState = $v.deviceState.toBuilder();
      _securityState = $v.securityState.toBuilder();
      _dataState = $v.dataState.toBuilder();
      _sourceCompletion = $v.sourceCompletion.toBuilder();
      _expiresAt = $v.expiresAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AccountRecoveryReplacementChallengeData other) {
    _$v = other as _$AccountRecoveryReplacementChallengeData;
  }

  @override
  void update(
    void Function(AccountRecoveryReplacementChallengeDataBuilder)? updates,
  ) {
    if (updates != null) updates(this);
  }

  @override
  AccountRecoveryReplacementChallengeData build() => _build();

  _$AccountRecoveryReplacementChallengeData _build() {
    _$AccountRecoveryReplacementChallengeData _$result;
    try {
      _$result =
          _$v ??
          _$AccountRecoveryReplacementChallengeData._(
            result: BuiltValueNullFieldError.checkNotNull(
              result,
              r'AccountRecoveryReplacementChallengeData',
              'result',
            ),
            protocolVersion: BuiltValueNullFieldError.checkNotNull(
              protocolVersion,
              r'AccountRecoveryReplacementChallengeData',
              'protocolVersion',
            ),
            challengeId: BuiltValueNullFieldError.checkNotNull(
              challengeId,
              r'AccountRecoveryReplacementChallengeData',
              'challengeId',
            ),
            attemptId: BuiltValueNullFieldError.checkNotNull(
              attemptId,
              r'AccountRecoveryReplacementChallengeData',
              'attemptId',
            ),
            requestDigest: BuiltValueNullFieldError.checkNotNull(
              requestDigest,
              r'AccountRecoveryReplacementChallengeData',
              'requestDigest',
            ),
            challengeFrame: BuiltValueNullFieldError.checkNotNull(
              challengeFrame,
              r'AccountRecoveryReplacementChallengeData',
              'challengeFrame',
            ),
            sealedNonce: BuiltValueNullFieldError.checkNotNull(
              sealedNonce,
              r'AccountRecoveryReplacementChallengeData',
              'sealedNonce',
            ),
            deviceState: deviceState.build(),
            securityState: securityState.build(),
            dataState: dataState.build(),
            sourceCompletion: sourceCompletion.build(),
            expiresAt: BuiltValueNullFieldError.checkNotNull(
              expiresAt,
              r'AccountRecoveryReplacementChallengeData',
              'expiresAt',
            ),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'deviceState';
        deviceState.build();
        _$failedField = 'securityState';
        securityState.build();
        _$failedField = 'dataState';
        dataState.build();
        _$failedField = 'sourceCompletion';
        sourceCompletion.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'AccountRecoveryReplacementChallengeData',
          _$failedField,
          e.toString(),
        );
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
