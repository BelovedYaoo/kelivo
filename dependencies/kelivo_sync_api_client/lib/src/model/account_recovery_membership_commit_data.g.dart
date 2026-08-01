// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_recovery_membership_commit_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const AccountRecoveryMembershipCommitDataResultEnum
_$accountRecoveryMembershipCommitDataResultEnum_committed =
    const AccountRecoveryMembershipCommitDataResultEnum._('committed');
const AccountRecoveryMembershipCommitDataResultEnum
_$accountRecoveryMembershipCommitDataResultEnum_replayed =
    const AccountRecoveryMembershipCommitDataResultEnum._('replayed');

AccountRecoveryMembershipCommitDataResultEnum
_$accountRecoveryMembershipCommitDataResultEnumValueOf(String name) {
  switch (name) {
    case 'committed':
      return _$accountRecoveryMembershipCommitDataResultEnum_committed;
    case 'replayed':
      return _$accountRecoveryMembershipCommitDataResultEnum_replayed;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<AccountRecoveryMembershipCommitDataResultEnum>
_$accountRecoveryMembershipCommitDataResultEnumValues =
    BuiltSet<AccountRecoveryMembershipCommitDataResultEnum>(
      const <AccountRecoveryMembershipCommitDataResultEnum>[
        _$accountRecoveryMembershipCommitDataResultEnum_committed,
        _$accountRecoveryMembershipCommitDataResultEnum_replayed,
      ],
    );

const AccountRecoveryMembershipCommitDataStatusEnum
_$accountRecoveryMembershipCommitDataStatusEnum_resumeCommitted =
    const AccountRecoveryMembershipCommitDataStatusEnum._('resumeCommitted');
const AccountRecoveryMembershipCommitDataStatusEnum
_$accountRecoveryMembershipCommitDataStatusEnum_replacementCommitted =
    const AccountRecoveryMembershipCommitDataStatusEnum._(
      'replacementCommitted',
    );

AccountRecoveryMembershipCommitDataStatusEnum
_$accountRecoveryMembershipCommitDataStatusEnumValueOf(String name) {
  switch (name) {
    case 'resumeCommitted':
      return _$accountRecoveryMembershipCommitDataStatusEnum_resumeCommitted;
    case 'replacementCommitted':
      return _$accountRecoveryMembershipCommitDataStatusEnum_replacementCommitted;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<AccountRecoveryMembershipCommitDataStatusEnum>
_$accountRecoveryMembershipCommitDataStatusEnumValues =
    BuiltSet<AccountRecoveryMembershipCommitDataStatusEnum>(
      const <AccountRecoveryMembershipCommitDataStatusEnum>[
        _$accountRecoveryMembershipCommitDataStatusEnum_resumeCommitted,
        _$accountRecoveryMembershipCommitDataStatusEnum_replacementCommitted,
      ],
    );

const AccountRecoveryMembershipCommitDataNextActionEnum
_$accountRecoveryMembershipCommitDataNextActionEnum_finishFirstDataRekey =
    const AccountRecoveryMembershipCommitDataNextActionEnum._(
      'finishFirstDataRekey',
    );
const AccountRecoveryMembershipCommitDataNextActionEnum
_$accountRecoveryMembershipCommitDataNextActionEnum_finishSecondDataRekey =
    const AccountRecoveryMembershipCommitDataNextActionEnum._(
      'finishSecondDataRekey',
    );

AccountRecoveryMembershipCommitDataNextActionEnum
_$accountRecoveryMembershipCommitDataNextActionEnumValueOf(String name) {
  switch (name) {
    case 'finishFirstDataRekey':
      return _$accountRecoveryMembershipCommitDataNextActionEnum_finishFirstDataRekey;
    case 'finishSecondDataRekey':
      return _$accountRecoveryMembershipCommitDataNextActionEnum_finishSecondDataRekey;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<AccountRecoveryMembershipCommitDataNextActionEnum>
_$accountRecoveryMembershipCommitDataNextActionEnumValues =
    BuiltSet<AccountRecoveryMembershipCommitDataNextActionEnum>(const <
      AccountRecoveryMembershipCommitDataNextActionEnum
    >[
      _$accountRecoveryMembershipCommitDataNextActionEnum_finishFirstDataRekey,
      _$accountRecoveryMembershipCommitDataNextActionEnum_finishSecondDataRekey,
    ]);

Serializer<AccountRecoveryMembershipCommitDataResultEnum>
_$accountRecoveryMembershipCommitDataResultEnumSerializer =
    _$AccountRecoveryMembershipCommitDataResultEnumSerializer();
Serializer<AccountRecoveryMembershipCommitDataStatusEnum>
_$accountRecoveryMembershipCommitDataStatusEnumSerializer =
    _$AccountRecoveryMembershipCommitDataStatusEnumSerializer();
Serializer<AccountRecoveryMembershipCommitDataNextActionEnum>
_$accountRecoveryMembershipCommitDataNextActionEnumSerializer =
    _$AccountRecoveryMembershipCommitDataNextActionEnumSerializer();

class _$AccountRecoveryMembershipCommitDataResultEnumSerializer
    implements
        PrimitiveSerializer<AccountRecoveryMembershipCommitDataResultEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'committed': 'committed',
    'replayed': 'replayed',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'committed': 'committed',
    'replayed': 'replayed',
  };

  @override
  final Iterable<Type> types = const <Type>[
    AccountRecoveryMembershipCommitDataResultEnum,
  ];
  @override
  final String wireName = 'AccountRecoveryMembershipCommitDataResultEnum';

  @override
  Object serialize(
    Serializers serializers,
    AccountRecoveryMembershipCommitDataResultEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  AccountRecoveryMembershipCommitDataResultEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => AccountRecoveryMembershipCommitDataResultEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$AccountRecoveryMembershipCommitDataStatusEnumSerializer
    implements
        PrimitiveSerializer<AccountRecoveryMembershipCommitDataStatusEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'resumeCommitted': 'resume-committed',
    'replacementCommitted': 'replacement-committed',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'resume-committed': 'resumeCommitted',
    'replacement-committed': 'replacementCommitted',
  };

  @override
  final Iterable<Type> types = const <Type>[
    AccountRecoveryMembershipCommitDataStatusEnum,
  ];
  @override
  final String wireName = 'AccountRecoveryMembershipCommitDataStatusEnum';

  @override
  Object serialize(
    Serializers serializers,
    AccountRecoveryMembershipCommitDataStatusEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  AccountRecoveryMembershipCommitDataStatusEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => AccountRecoveryMembershipCommitDataStatusEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$AccountRecoveryMembershipCommitDataNextActionEnumSerializer
    implements
        PrimitiveSerializer<AccountRecoveryMembershipCommitDataNextActionEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'finishFirstDataRekey': 'finish-first-data-rekey',
    'finishSecondDataRekey': 'finish-second-data-rekey',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'finish-first-data-rekey': 'finishFirstDataRekey',
    'finish-second-data-rekey': 'finishSecondDataRekey',
  };

  @override
  final Iterable<Type> types = const <Type>[
    AccountRecoveryMembershipCommitDataNextActionEnum,
  ];
  @override
  final String wireName = 'AccountRecoveryMembershipCommitDataNextActionEnum';

  @override
  Object serialize(
    Serializers serializers,
    AccountRecoveryMembershipCommitDataNextActionEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  AccountRecoveryMembershipCommitDataNextActionEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => AccountRecoveryMembershipCommitDataNextActionEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$AccountRecoveryMembershipCommitData
    extends AccountRecoveryMembershipCommitData {
  @override
  final AccountRecoveryMembershipCommitDataResultEnum result;
  @override
  final String attemptId;
  @override
  final AccountRecoveryMembershipCommitDataStatusEnum status;
  @override
  final String membershipOperationId;
  @override
  final String rekeyOperationId;
  @override
  final int generation;
  @override
  final int keyEpoch;
  @override
  final AccountRecoveryMembershipCommitDataNextActionEnum nextAction;

  factory _$AccountRecoveryMembershipCommitData([
    void Function(AccountRecoveryMembershipCommitDataBuilder)? updates,
  ]) =>
      (AccountRecoveryMembershipCommitDataBuilder()..update(updates))._build();

  _$AccountRecoveryMembershipCommitData._({
    required this.result,
    required this.attemptId,
    required this.status,
    required this.membershipOperationId,
    required this.rekeyOperationId,
    required this.generation,
    required this.keyEpoch,
    required this.nextAction,
  }) : super._();
  @override
  AccountRecoveryMembershipCommitData rebuild(
    void Function(AccountRecoveryMembershipCommitDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  AccountRecoveryMembershipCommitDataBuilder toBuilder() =>
      AccountRecoveryMembershipCommitDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AccountRecoveryMembershipCommitData &&
        result == other.result &&
        attemptId == other.attemptId &&
        status == other.status &&
        membershipOperationId == other.membershipOperationId &&
        rekeyOperationId == other.rekeyOperationId &&
        generation == other.generation &&
        keyEpoch == other.keyEpoch &&
        nextAction == other.nextAction;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, result.hashCode);
    _$hash = $jc(_$hash, attemptId.hashCode);
    _$hash = $jc(_$hash, status.hashCode);
    _$hash = $jc(_$hash, membershipOperationId.hashCode);
    _$hash = $jc(_$hash, rekeyOperationId.hashCode);
    _$hash = $jc(_$hash, generation.hashCode);
    _$hash = $jc(_$hash, keyEpoch.hashCode);
    _$hash = $jc(_$hash, nextAction.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'AccountRecoveryMembershipCommitData')
          ..add('result', result)
          ..add('attemptId', attemptId)
          ..add('status', status)
          ..add('membershipOperationId', membershipOperationId)
          ..add('rekeyOperationId', rekeyOperationId)
          ..add('generation', generation)
          ..add('keyEpoch', keyEpoch)
          ..add('nextAction', nextAction))
        .toString();
  }
}

class AccountRecoveryMembershipCommitDataBuilder
    implements
        Builder<
          AccountRecoveryMembershipCommitData,
          AccountRecoveryMembershipCommitDataBuilder
        > {
  _$AccountRecoveryMembershipCommitData? _$v;

  AccountRecoveryMembershipCommitDataResultEnum? _result;
  AccountRecoveryMembershipCommitDataResultEnum? get result => _$this._result;
  set result(AccountRecoveryMembershipCommitDataResultEnum? result) =>
      _$this._result = result;

  String? _attemptId;
  String? get attemptId => _$this._attemptId;
  set attemptId(String? attemptId) => _$this._attemptId = attemptId;

  AccountRecoveryMembershipCommitDataStatusEnum? _status;
  AccountRecoveryMembershipCommitDataStatusEnum? get status => _$this._status;
  set status(AccountRecoveryMembershipCommitDataStatusEnum? status) =>
      _$this._status = status;

  String? _membershipOperationId;
  String? get membershipOperationId => _$this._membershipOperationId;
  set membershipOperationId(String? membershipOperationId) =>
      _$this._membershipOperationId = membershipOperationId;

  String? _rekeyOperationId;
  String? get rekeyOperationId => _$this._rekeyOperationId;
  set rekeyOperationId(String? rekeyOperationId) =>
      _$this._rekeyOperationId = rekeyOperationId;

  int? _generation;
  int? get generation => _$this._generation;
  set generation(int? generation) => _$this._generation = generation;

  int? _keyEpoch;
  int? get keyEpoch => _$this._keyEpoch;
  set keyEpoch(int? keyEpoch) => _$this._keyEpoch = keyEpoch;

  AccountRecoveryMembershipCommitDataNextActionEnum? _nextAction;
  AccountRecoveryMembershipCommitDataNextActionEnum? get nextAction =>
      _$this._nextAction;
  set nextAction(
    AccountRecoveryMembershipCommitDataNextActionEnum? nextAction,
  ) => _$this._nextAction = nextAction;

  AccountRecoveryMembershipCommitDataBuilder() {
    AccountRecoveryMembershipCommitData._defaults(this);
  }

  AccountRecoveryMembershipCommitDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _result = $v.result;
      _attemptId = $v.attemptId;
      _status = $v.status;
      _membershipOperationId = $v.membershipOperationId;
      _rekeyOperationId = $v.rekeyOperationId;
      _generation = $v.generation;
      _keyEpoch = $v.keyEpoch;
      _nextAction = $v.nextAction;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AccountRecoveryMembershipCommitData other) {
    _$v = other as _$AccountRecoveryMembershipCommitData;
  }

  @override
  void update(
    void Function(AccountRecoveryMembershipCommitDataBuilder)? updates,
  ) {
    if (updates != null) updates(this);
  }

  @override
  AccountRecoveryMembershipCommitData build() => _build();

  _$AccountRecoveryMembershipCommitData _build() {
    final _$result =
        _$v ??
        _$AccountRecoveryMembershipCommitData._(
          result: BuiltValueNullFieldError.checkNotNull(
            result,
            r'AccountRecoveryMembershipCommitData',
            'result',
          ),
          attemptId: BuiltValueNullFieldError.checkNotNull(
            attemptId,
            r'AccountRecoveryMembershipCommitData',
            'attemptId',
          ),
          status: BuiltValueNullFieldError.checkNotNull(
            status,
            r'AccountRecoveryMembershipCommitData',
            'status',
          ),
          membershipOperationId: BuiltValueNullFieldError.checkNotNull(
            membershipOperationId,
            r'AccountRecoveryMembershipCommitData',
            'membershipOperationId',
          ),
          rekeyOperationId: BuiltValueNullFieldError.checkNotNull(
            rekeyOperationId,
            r'AccountRecoveryMembershipCommitData',
            'rekeyOperationId',
          ),
          generation: BuiltValueNullFieldError.checkNotNull(
            generation,
            r'AccountRecoveryMembershipCommitData',
            'generation',
          ),
          keyEpoch: BuiltValueNullFieldError.checkNotNull(
            keyEpoch,
            r'AccountRecoveryMembershipCommitData',
            'keyEpoch',
          ),
          nextAction: BuiltValueNullFieldError.checkNotNull(
            nextAction,
            r'AccountRecoveryMembershipCommitData',
            'nextAction',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
