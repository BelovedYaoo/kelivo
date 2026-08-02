// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'self_revocation_status_data_one_of1_receipt.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$SelfRevocationStatusDataOneOf1Receipt
    extends SelfRevocationStatusDataOneOf1Receipt {
  @override
  final BuiltList<AccountSecurityStateHistoryItem> securityStates;
  @override
  final DataRekeyCompletionProofData completion;

  factory _$SelfRevocationStatusDataOneOf1Receipt([
    void Function(SelfRevocationStatusDataOneOf1ReceiptBuilder)? updates,
  ]) => (SelfRevocationStatusDataOneOf1ReceiptBuilder()..update(updates))
      ._build();

  _$SelfRevocationStatusDataOneOf1Receipt._({
    required this.securityStates,
    required this.completion,
  }) : super._();
  @override
  SelfRevocationStatusDataOneOf1Receipt rebuild(
    void Function(SelfRevocationStatusDataOneOf1ReceiptBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  SelfRevocationStatusDataOneOf1ReceiptBuilder toBuilder() =>
      SelfRevocationStatusDataOneOf1ReceiptBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SelfRevocationStatusDataOneOf1Receipt &&
        securityStates == other.securityStates &&
        completion == other.completion;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, securityStates.hashCode);
    _$hash = $jc(_$hash, completion.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(
            r'SelfRevocationStatusDataOneOf1Receipt',
          )
          ..add('securityStates', securityStates)
          ..add('completion', completion))
        .toString();
  }
}

class SelfRevocationStatusDataOneOf1ReceiptBuilder
    implements
        Builder<
          SelfRevocationStatusDataOneOf1Receipt,
          SelfRevocationStatusDataOneOf1ReceiptBuilder
        > {
  _$SelfRevocationStatusDataOneOf1Receipt? _$v;

  ListBuilder<AccountSecurityStateHistoryItem>? _securityStates;
  ListBuilder<AccountSecurityStateHistoryItem> get securityStates =>
      _$this._securityStates ??= ListBuilder<AccountSecurityStateHistoryItem>();
  set securityStates(
    ListBuilder<AccountSecurityStateHistoryItem>? securityStates,
  ) => _$this._securityStates = securityStates;

  DataRekeyCompletionProofDataBuilder? _completion;
  DataRekeyCompletionProofDataBuilder get completion =>
      _$this._completion ??= DataRekeyCompletionProofDataBuilder();
  set completion(DataRekeyCompletionProofDataBuilder? completion) =>
      _$this._completion = completion;

  SelfRevocationStatusDataOneOf1ReceiptBuilder() {
    SelfRevocationStatusDataOneOf1Receipt._defaults(this);
  }

  SelfRevocationStatusDataOneOf1ReceiptBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _securityStates = $v.securityStates.toBuilder();
      _completion = $v.completion.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SelfRevocationStatusDataOneOf1Receipt other) {
    _$v = other as _$SelfRevocationStatusDataOneOf1Receipt;
  }

  @override
  void update(
    void Function(SelfRevocationStatusDataOneOf1ReceiptBuilder)? updates,
  ) {
    if (updates != null) updates(this);
  }

  @override
  SelfRevocationStatusDataOneOf1Receipt build() => _build();

  _$SelfRevocationStatusDataOneOf1Receipt _build() {
    _$SelfRevocationStatusDataOneOf1Receipt _$result;
    try {
      _$result =
          _$v ??
          _$SelfRevocationStatusDataOneOf1Receipt._(
            securityStates: securityStates.build(),
            completion: completion.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'securityStates';
        securityStates.build();
        _$failedField = 'completion';
        completion.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'SelfRevocationStatusDataOneOf1Receipt',
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
