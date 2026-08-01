// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_recovery_attempt_start_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const AccountRecoveryAttemptStartDataActionEnum
_$accountRecoveryAttemptStartDataActionEnum_authorized =
    const AccountRecoveryAttemptStartDataActionEnum._('authorized');

AccountRecoveryAttemptStartDataActionEnum
_$accountRecoveryAttemptStartDataActionEnumValueOf(String name) {
  switch (name) {
    case 'authorized':
      return _$accountRecoveryAttemptStartDataActionEnum_authorized;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<AccountRecoveryAttemptStartDataActionEnum>
_$accountRecoveryAttemptStartDataActionEnumValues =
    BuiltSet<AccountRecoveryAttemptStartDataActionEnum>(
      const <AccountRecoveryAttemptStartDataActionEnum>[
        _$accountRecoveryAttemptStartDataActionEnum_authorized,
      ],
    );

const AccountRecoveryAttemptStartDataResultEnum
_$accountRecoveryAttemptStartDataResultEnum_authorized =
    const AccountRecoveryAttemptStartDataResultEnum._('authorized');
const AccountRecoveryAttemptStartDataResultEnum
_$accountRecoveryAttemptStartDataResultEnum_replayed =
    const AccountRecoveryAttemptStartDataResultEnum._('replayed');

AccountRecoveryAttemptStartDataResultEnum
_$accountRecoveryAttemptStartDataResultEnumValueOf(String name) {
  switch (name) {
    case 'authorized':
      return _$accountRecoveryAttemptStartDataResultEnum_authorized;
    case 'replayed':
      return _$accountRecoveryAttemptStartDataResultEnum_replayed;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<AccountRecoveryAttemptStartDataResultEnum>
_$accountRecoveryAttemptStartDataResultEnumValues =
    BuiltSet<AccountRecoveryAttemptStartDataResultEnum>(
      const <AccountRecoveryAttemptStartDataResultEnum>[
        _$accountRecoveryAttemptStartDataResultEnum_authorized,
        _$accountRecoveryAttemptStartDataResultEnum_replayed,
      ],
    );

const AccountRecoveryAttemptStartDataStatusEnum
_$accountRecoveryAttemptStartDataStatusEnum_authorized =
    const AccountRecoveryAttemptStartDataStatusEnum._('authorized');

AccountRecoveryAttemptStartDataStatusEnum
_$accountRecoveryAttemptStartDataStatusEnumValueOf(String name) {
  switch (name) {
    case 'authorized':
      return _$accountRecoveryAttemptStartDataStatusEnum_authorized;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<AccountRecoveryAttemptStartDataStatusEnum>
_$accountRecoveryAttemptStartDataStatusEnumValues =
    BuiltSet<AccountRecoveryAttemptStartDataStatusEnum>(
      const <AccountRecoveryAttemptStartDataStatusEnum>[
        _$accountRecoveryAttemptStartDataStatusEnum_authorized,
      ],
    );

const AccountRecoveryAttemptStartDataNextActionEnum
_$accountRecoveryAttemptStartDataNextActionEnum_recoverResume =
    const AccountRecoveryAttemptStartDataNextActionEnum._('recoverResume');
const AccountRecoveryAttemptStartDataNextActionEnum
_$accountRecoveryAttemptStartDataNextActionEnum_recoverReplace =
    const AccountRecoveryAttemptStartDataNextActionEnum._('recoverReplace');

AccountRecoveryAttemptStartDataNextActionEnum
_$accountRecoveryAttemptStartDataNextActionEnumValueOf(String name) {
  switch (name) {
    case 'recoverResume':
      return _$accountRecoveryAttemptStartDataNextActionEnum_recoverResume;
    case 'recoverReplace':
      return _$accountRecoveryAttemptStartDataNextActionEnum_recoverReplace;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<AccountRecoveryAttemptStartDataNextActionEnum>
_$accountRecoveryAttemptStartDataNextActionEnumValues =
    BuiltSet<AccountRecoveryAttemptStartDataNextActionEnum>(
      const <AccountRecoveryAttemptStartDataNextActionEnum>[
        _$accountRecoveryAttemptStartDataNextActionEnum_recoverResume,
        _$accountRecoveryAttemptStartDataNextActionEnum_recoverReplace,
      ],
    );

Serializer<AccountRecoveryAttemptStartDataActionEnum>
_$accountRecoveryAttemptStartDataActionEnumSerializer =
    _$AccountRecoveryAttemptStartDataActionEnumSerializer();
Serializer<AccountRecoveryAttemptStartDataResultEnum>
_$accountRecoveryAttemptStartDataResultEnumSerializer =
    _$AccountRecoveryAttemptStartDataResultEnumSerializer();
Serializer<AccountRecoveryAttemptStartDataStatusEnum>
_$accountRecoveryAttemptStartDataStatusEnumSerializer =
    _$AccountRecoveryAttemptStartDataStatusEnumSerializer();
Serializer<AccountRecoveryAttemptStartDataNextActionEnum>
_$accountRecoveryAttemptStartDataNextActionEnumSerializer =
    _$AccountRecoveryAttemptStartDataNextActionEnumSerializer();

class _$AccountRecoveryAttemptStartDataActionEnumSerializer
    implements PrimitiveSerializer<AccountRecoveryAttemptStartDataActionEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'authorized': 'authorized',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'authorized': 'authorized',
  };

  @override
  final Iterable<Type> types = const <Type>[
    AccountRecoveryAttemptStartDataActionEnum,
  ];
  @override
  final String wireName = 'AccountRecoveryAttemptStartDataActionEnum';

  @override
  Object serialize(
    Serializers serializers,
    AccountRecoveryAttemptStartDataActionEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  AccountRecoveryAttemptStartDataActionEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => AccountRecoveryAttemptStartDataActionEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$AccountRecoveryAttemptStartDataResultEnumSerializer
    implements PrimitiveSerializer<AccountRecoveryAttemptStartDataResultEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'authorized': 'authorized',
    'replayed': 'replayed',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'authorized': 'authorized',
    'replayed': 'replayed',
  };

  @override
  final Iterable<Type> types = const <Type>[
    AccountRecoveryAttemptStartDataResultEnum,
  ];
  @override
  final String wireName = 'AccountRecoveryAttemptStartDataResultEnum';

  @override
  Object serialize(
    Serializers serializers,
    AccountRecoveryAttemptStartDataResultEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  AccountRecoveryAttemptStartDataResultEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => AccountRecoveryAttemptStartDataResultEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$AccountRecoveryAttemptStartDataStatusEnumSerializer
    implements PrimitiveSerializer<AccountRecoveryAttemptStartDataStatusEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'authorized': 'authorized',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'authorized': 'authorized',
  };

  @override
  final Iterable<Type> types = const <Type>[
    AccountRecoveryAttemptStartDataStatusEnum,
  ];
  @override
  final String wireName = 'AccountRecoveryAttemptStartDataStatusEnum';

  @override
  Object serialize(
    Serializers serializers,
    AccountRecoveryAttemptStartDataStatusEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  AccountRecoveryAttemptStartDataStatusEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => AccountRecoveryAttemptStartDataStatusEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$AccountRecoveryAttemptStartDataNextActionEnumSerializer
    implements
        PrimitiveSerializer<AccountRecoveryAttemptStartDataNextActionEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'recoverResume': 'recover-resume',
    'recoverReplace': 'recover-replace',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'recover-resume': 'recoverResume',
    'recover-replace': 'recoverReplace',
  };

  @override
  final Iterable<Type> types = const <Type>[
    AccountRecoveryAttemptStartDataNextActionEnum,
  ];
  @override
  final String wireName = 'AccountRecoveryAttemptStartDataNextActionEnum';

  @override
  Object serialize(
    Serializers serializers,
    AccountRecoveryAttemptStartDataNextActionEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  AccountRecoveryAttemptStartDataNextActionEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => AccountRecoveryAttemptStartDataNextActionEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$AccountRecoveryAttemptStartData
    extends AccountRecoveryAttemptStartData {
  @override
  final OneOf oneOf;

  factory _$AccountRecoveryAttemptStartData([
    void Function(AccountRecoveryAttemptStartDataBuilder)? updates,
  ]) => (AccountRecoveryAttemptStartDataBuilder()..update(updates))._build();

  _$AccountRecoveryAttemptStartData._({required this.oneOf}) : super._();
  @override
  AccountRecoveryAttemptStartData rebuild(
    void Function(AccountRecoveryAttemptStartDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  AccountRecoveryAttemptStartDataBuilder toBuilder() =>
      AccountRecoveryAttemptStartDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AccountRecoveryAttemptStartData && oneOf == other.oneOf;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, oneOf.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(
      r'AccountRecoveryAttemptStartData',
    )..add('oneOf', oneOf)).toString();
  }
}

class AccountRecoveryAttemptStartDataBuilder
    implements
        Builder<
          AccountRecoveryAttemptStartData,
          AccountRecoveryAttemptStartDataBuilder
        > {
  _$AccountRecoveryAttemptStartData? _$v;

  OneOf? _oneOf;
  OneOf? get oneOf => _$this._oneOf;
  set oneOf(OneOf? oneOf) => _$this._oneOf = oneOf;

  AccountRecoveryAttemptStartDataBuilder() {
    AccountRecoveryAttemptStartData._defaults(this);
  }

  AccountRecoveryAttemptStartDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _oneOf = $v.oneOf;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AccountRecoveryAttemptStartData other) {
    _$v = other as _$AccountRecoveryAttemptStartData;
  }

  @override
  void update(void Function(AccountRecoveryAttemptStartDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  AccountRecoveryAttemptStartData build() => _build();

  _$AccountRecoveryAttemptStartData _build() {
    final _$result =
        _$v ??
        _$AccountRecoveryAttemptStartData._(
          oneOf: BuiltValueNullFieldError.checkNotNull(
            oneOf,
            r'AccountRecoveryAttemptStartData',
            'oneOf',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
