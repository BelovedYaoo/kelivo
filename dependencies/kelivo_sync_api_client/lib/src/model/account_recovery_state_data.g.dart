// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_recovery_state_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const AccountRecoveryStateDataStatusEnum
_$accountRecoveryStateDataStatusEnum_authorized =
    const AccountRecoveryStateDataStatusEnum._('authorized');
const AccountRecoveryStateDataStatusEnum
_$accountRecoveryStateDataStatusEnum_resumeCommitted =
    const AccountRecoveryStateDataStatusEnum._('resumeCommitted');
const AccountRecoveryStateDataStatusEnum
_$accountRecoveryStateDataStatusEnum_replacementCommitted =
    const AccountRecoveryStateDataStatusEnum._('replacementCommitted');

AccountRecoveryStateDataStatusEnum _$accountRecoveryStateDataStatusEnumValueOf(
  String name,
) {
  switch (name) {
    case 'authorized':
      return _$accountRecoveryStateDataStatusEnum_authorized;
    case 'resumeCommitted':
      return _$accountRecoveryStateDataStatusEnum_resumeCommitted;
    case 'replacementCommitted':
      return _$accountRecoveryStateDataStatusEnum_replacementCommitted;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<AccountRecoveryStateDataStatusEnum>
_$accountRecoveryStateDataStatusEnumValues =
    BuiltSet<AccountRecoveryStateDataStatusEnum>(
      const <AccountRecoveryStateDataStatusEnum>[
        _$accountRecoveryStateDataStatusEnum_authorized,
        _$accountRecoveryStateDataStatusEnum_resumeCommitted,
        _$accountRecoveryStateDataStatusEnum_replacementCommitted,
      ],
    );

const AccountRecoveryStateDataNextActionEnum
_$accountRecoveryStateDataNextActionEnum_recoverResume =
    const AccountRecoveryStateDataNextActionEnum._('recoverResume');
const AccountRecoveryStateDataNextActionEnum
_$accountRecoveryStateDataNextActionEnum_finishFirstDataRekey =
    const AccountRecoveryStateDataNextActionEnum._('finishFirstDataRekey');
const AccountRecoveryStateDataNextActionEnum
_$accountRecoveryStateDataNextActionEnum_createReplacementChallenge =
    const AccountRecoveryStateDataNextActionEnum._(
      'createReplacementChallenge',
    );
const AccountRecoveryStateDataNextActionEnum
_$accountRecoveryStateDataNextActionEnum_recoverReplace =
    const AccountRecoveryStateDataNextActionEnum._('recoverReplace');
const AccountRecoveryStateDataNextActionEnum
_$accountRecoveryStateDataNextActionEnum_finishSecondDataRekey =
    const AccountRecoveryStateDataNextActionEnum._('finishSecondDataRekey');

AccountRecoveryStateDataNextActionEnum
_$accountRecoveryStateDataNextActionEnumValueOf(String name) {
  switch (name) {
    case 'recoverResume':
      return _$accountRecoveryStateDataNextActionEnum_recoverResume;
    case 'finishFirstDataRekey':
      return _$accountRecoveryStateDataNextActionEnum_finishFirstDataRekey;
    case 'createReplacementChallenge':
      return _$accountRecoveryStateDataNextActionEnum_createReplacementChallenge;
    case 'recoverReplace':
      return _$accountRecoveryStateDataNextActionEnum_recoverReplace;
    case 'finishSecondDataRekey':
      return _$accountRecoveryStateDataNextActionEnum_finishSecondDataRekey;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<AccountRecoveryStateDataNextActionEnum>
_$accountRecoveryStateDataNextActionEnumValues =
    BuiltSet<AccountRecoveryStateDataNextActionEnum>(
      const <AccountRecoveryStateDataNextActionEnum>[
        _$accountRecoveryStateDataNextActionEnum_recoverResume,
        _$accountRecoveryStateDataNextActionEnum_finishFirstDataRekey,
        _$accountRecoveryStateDataNextActionEnum_createReplacementChallenge,
        _$accountRecoveryStateDataNextActionEnum_recoverReplace,
        _$accountRecoveryStateDataNextActionEnum_finishSecondDataRekey,
      ],
    );

Serializer<AccountRecoveryStateDataStatusEnum>
_$accountRecoveryStateDataStatusEnumSerializer =
    _$AccountRecoveryStateDataStatusEnumSerializer();
Serializer<AccountRecoveryStateDataNextActionEnum>
_$accountRecoveryStateDataNextActionEnumSerializer =
    _$AccountRecoveryStateDataNextActionEnumSerializer();

class _$AccountRecoveryStateDataStatusEnumSerializer
    implements PrimitiveSerializer<AccountRecoveryStateDataStatusEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'authorized': 'authorized',
    'resumeCommitted': 'resume-committed',
    'replacementCommitted': 'replacement-committed',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'authorized': 'authorized',
    'resume-committed': 'resumeCommitted',
    'replacement-committed': 'replacementCommitted',
  };

  @override
  final Iterable<Type> types = const <Type>[AccountRecoveryStateDataStatusEnum];
  @override
  final String wireName = 'AccountRecoveryStateDataStatusEnum';

  @override
  Object serialize(
    Serializers serializers,
    AccountRecoveryStateDataStatusEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  AccountRecoveryStateDataStatusEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => AccountRecoveryStateDataStatusEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$AccountRecoveryStateDataNextActionEnumSerializer
    implements PrimitiveSerializer<AccountRecoveryStateDataNextActionEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'recoverResume': 'recover-resume',
    'finishFirstDataRekey': 'finish-first-data-rekey',
    'createReplacementChallenge': 'create-replacement-challenge',
    'recoverReplace': 'recover-replace',
    'finishSecondDataRekey': 'finish-second-data-rekey',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'recover-resume': 'recoverResume',
    'finish-first-data-rekey': 'finishFirstDataRekey',
    'create-replacement-challenge': 'createReplacementChallenge',
    'recover-replace': 'recoverReplace',
    'finish-second-data-rekey': 'finishSecondDataRekey',
  };

  @override
  final Iterable<Type> types = const <Type>[
    AccountRecoveryStateDataNextActionEnum,
  ];
  @override
  final String wireName = 'AccountRecoveryStateDataNextActionEnum';

  @override
  Object serialize(
    Serializers serializers,
    AccountRecoveryStateDataNextActionEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  AccountRecoveryStateDataNextActionEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => AccountRecoveryStateDataNextActionEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$AccountRecoveryStateData extends AccountRecoveryStateData {
  @override
  final int protocolVersion;
  @override
  final String attemptId;
  @override
  final AccountRecoveryStateDataStatusEnum status;
  @override
  final AccountRecoveryStateDataNextActionEnum nextAction;
  @override
  final DateTime authorizedAt;
  @override
  final DateTime recoveryTokenExpiresAt;
  @override
  final AccountSecurityStateData securityState;
  @override
  final AccountRecoveryDataState dataState;

  factory _$AccountRecoveryStateData([
    void Function(AccountRecoveryStateDataBuilder)? updates,
  ]) => (AccountRecoveryStateDataBuilder()..update(updates))._build();

  _$AccountRecoveryStateData._({
    required this.protocolVersion,
    required this.attemptId,
    required this.status,
    required this.nextAction,
    required this.authorizedAt,
    required this.recoveryTokenExpiresAt,
    required this.securityState,
    required this.dataState,
  }) : super._();
  @override
  AccountRecoveryStateData rebuild(
    void Function(AccountRecoveryStateDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  AccountRecoveryStateDataBuilder toBuilder() =>
      AccountRecoveryStateDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AccountRecoveryStateData &&
        protocolVersion == other.protocolVersion &&
        attemptId == other.attemptId &&
        status == other.status &&
        nextAction == other.nextAction &&
        authorizedAt == other.authorizedAt &&
        recoveryTokenExpiresAt == other.recoveryTokenExpiresAt &&
        securityState == other.securityState &&
        dataState == other.dataState;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, protocolVersion.hashCode);
    _$hash = $jc(_$hash, attemptId.hashCode);
    _$hash = $jc(_$hash, status.hashCode);
    _$hash = $jc(_$hash, nextAction.hashCode);
    _$hash = $jc(_$hash, authorizedAt.hashCode);
    _$hash = $jc(_$hash, recoveryTokenExpiresAt.hashCode);
    _$hash = $jc(_$hash, securityState.hashCode);
    _$hash = $jc(_$hash, dataState.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'AccountRecoveryStateData')
          ..add('protocolVersion', protocolVersion)
          ..add('attemptId', attemptId)
          ..add('status', status)
          ..add('nextAction', nextAction)
          ..add('authorizedAt', authorizedAt)
          ..add('recoveryTokenExpiresAt', recoveryTokenExpiresAt)
          ..add('securityState', securityState)
          ..add('dataState', dataState))
        .toString();
  }
}

class AccountRecoveryStateDataBuilder
    implements
        Builder<AccountRecoveryStateData, AccountRecoveryStateDataBuilder> {
  _$AccountRecoveryStateData? _$v;

  int? _protocolVersion;
  int? get protocolVersion => _$this._protocolVersion;
  set protocolVersion(int? protocolVersion) =>
      _$this._protocolVersion = protocolVersion;

  String? _attemptId;
  String? get attemptId => _$this._attemptId;
  set attemptId(String? attemptId) => _$this._attemptId = attemptId;

  AccountRecoveryStateDataStatusEnum? _status;
  AccountRecoveryStateDataStatusEnum? get status => _$this._status;
  set status(AccountRecoveryStateDataStatusEnum? status) =>
      _$this._status = status;

  AccountRecoveryStateDataNextActionEnum? _nextAction;
  AccountRecoveryStateDataNextActionEnum? get nextAction => _$this._nextAction;
  set nextAction(AccountRecoveryStateDataNextActionEnum? nextAction) =>
      _$this._nextAction = nextAction;

  DateTime? _authorizedAt;
  DateTime? get authorizedAt => _$this._authorizedAt;
  set authorizedAt(DateTime? authorizedAt) =>
      _$this._authorizedAt = authorizedAt;

  DateTime? _recoveryTokenExpiresAt;
  DateTime? get recoveryTokenExpiresAt => _$this._recoveryTokenExpiresAt;
  set recoveryTokenExpiresAt(DateTime? recoveryTokenExpiresAt) =>
      _$this._recoveryTokenExpiresAt = recoveryTokenExpiresAt;

  AccountSecurityStateDataBuilder? _securityState;
  AccountSecurityStateDataBuilder get securityState =>
      _$this._securityState ??= AccountSecurityStateDataBuilder();
  set securityState(AccountSecurityStateDataBuilder? securityState) =>
      _$this._securityState = securityState;

  AccountRecoveryDataStateBuilder? _dataState;
  AccountRecoveryDataStateBuilder get dataState =>
      _$this._dataState ??= AccountRecoveryDataStateBuilder();
  set dataState(AccountRecoveryDataStateBuilder? dataState) =>
      _$this._dataState = dataState;

  AccountRecoveryStateDataBuilder() {
    AccountRecoveryStateData._defaults(this);
  }

  AccountRecoveryStateDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _protocolVersion = $v.protocolVersion;
      _attemptId = $v.attemptId;
      _status = $v.status;
      _nextAction = $v.nextAction;
      _authorizedAt = $v.authorizedAt;
      _recoveryTokenExpiresAt = $v.recoveryTokenExpiresAt;
      _securityState = $v.securityState.toBuilder();
      _dataState = $v.dataState.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AccountRecoveryStateData other) {
    _$v = other as _$AccountRecoveryStateData;
  }

  @override
  void update(void Function(AccountRecoveryStateDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  AccountRecoveryStateData build() => _build();

  _$AccountRecoveryStateData _build() {
    _$AccountRecoveryStateData _$result;
    try {
      _$result =
          _$v ??
          _$AccountRecoveryStateData._(
            protocolVersion: BuiltValueNullFieldError.checkNotNull(
              protocolVersion,
              r'AccountRecoveryStateData',
              'protocolVersion',
            ),
            attemptId: BuiltValueNullFieldError.checkNotNull(
              attemptId,
              r'AccountRecoveryStateData',
              'attemptId',
            ),
            status: BuiltValueNullFieldError.checkNotNull(
              status,
              r'AccountRecoveryStateData',
              'status',
            ),
            nextAction: BuiltValueNullFieldError.checkNotNull(
              nextAction,
              r'AccountRecoveryStateData',
              'nextAction',
            ),
            authorizedAt: BuiltValueNullFieldError.checkNotNull(
              authorizedAt,
              r'AccountRecoveryStateData',
              'authorizedAt',
            ),
            recoveryTokenExpiresAt: BuiltValueNullFieldError.checkNotNull(
              recoveryTokenExpiresAt,
              r'AccountRecoveryStateData',
              'recoveryTokenExpiresAt',
            ),
            securityState: securityState.build(),
            dataState: dataState.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'securityState';
        securityState.build();
        _$failedField = 'dataState';
        dataState.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'AccountRecoveryStateData',
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
