// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_pull_reset_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const SyncPullResetDataDataRekeyPhaseEnum
_$syncPullResetDataDataRekeyPhaseEnum_ready =
    const SyncPullResetDataDataRekeyPhaseEnum._('ready');
const SyncPullResetDataDataRekeyPhaseEnum
_$syncPullResetDataDataRekeyPhaseEnum_rekeyPending =
    const SyncPullResetDataDataRekeyPhaseEnum._('rekeyPending');

SyncPullResetDataDataRekeyPhaseEnum
_$syncPullResetDataDataRekeyPhaseEnumValueOf(String name) {
  switch (name) {
    case 'ready':
      return _$syncPullResetDataDataRekeyPhaseEnum_ready;
    case 'rekeyPending':
      return _$syncPullResetDataDataRekeyPhaseEnum_rekeyPending;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<SyncPullResetDataDataRekeyPhaseEnum>
_$syncPullResetDataDataRekeyPhaseEnumValues =
    BuiltSet<SyncPullResetDataDataRekeyPhaseEnum>(
      const <SyncPullResetDataDataRekeyPhaseEnum>[
        _$syncPullResetDataDataRekeyPhaseEnum_ready,
        _$syncPullResetDataDataRekeyPhaseEnum_rekeyPending,
      ],
    );

SyncPullResetDataNextCursorEnum _$syncPullResetDataNextCursorEnumValueOf(
  String name,
) {
  switch (name) {
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<SyncPullResetDataNextCursorEnum>
_$syncPullResetDataNextCursorEnumValues =
    BuiltSet<SyncPullResetDataNextCursorEnum>(
      const <SyncPullResetDataNextCursorEnum>[],
    );

Serializer<SyncPullResetDataDataRekeyPhaseEnum>
_$syncPullResetDataDataRekeyPhaseEnumSerializer =
    _$SyncPullResetDataDataRekeyPhaseEnumSerializer();
Serializer<SyncPullResetDataNextCursorEnum>
_$syncPullResetDataNextCursorEnumSerializer =
    _$SyncPullResetDataNextCursorEnumSerializer();

class _$SyncPullResetDataDataRekeyPhaseEnumSerializer
    implements PrimitiveSerializer<SyncPullResetDataDataRekeyPhaseEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'ready': 'ready',
    'rekeyPending': 'rekey-pending',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'ready': 'ready',
    'rekey-pending': 'rekeyPending',
  };

  @override
  final Iterable<Type> types = const <Type>[
    SyncPullResetDataDataRekeyPhaseEnum,
  ];
  @override
  final String wireName = 'SyncPullResetDataDataRekeyPhaseEnum';

  @override
  Object serialize(
    Serializers serializers,
    SyncPullResetDataDataRekeyPhaseEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  SyncPullResetDataDataRekeyPhaseEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => SyncPullResetDataDataRekeyPhaseEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$SyncPullResetDataNextCursorEnumSerializer
    implements PrimitiveSerializer<SyncPullResetDataNextCursorEnum> {
  @override
  final Iterable<Type> types = const <Type>[SyncPullResetDataNextCursorEnum];
  @override
  final String wireName = 'SyncPullResetDataNextCursorEnum';

  @override
  Object serialize(
    Serializers serializers,
    SyncPullResetDataNextCursorEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => object.name;

  @override
  SyncPullResetDataNextCursorEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => SyncPullResetDataNextCursorEnum.valueOf(serialized as String);
}

class _$SyncPullResetData extends SyncPullResetData {
  @override
  final SyncPullResetDataDataRekeyPhaseEnum dataRekeyPhase;
  @override
  final BuiltList<SyncChange> changes;
  @override
  final SyncPullResetDataNextCursorEnum? nextCursor;
  @override
  final bool hasMore;
  @override
  final bool resetRequired;

  factory _$SyncPullResetData([
    void Function(SyncPullResetDataBuilder)? updates,
  ]) => (SyncPullResetDataBuilder()..update(updates))._build();

  _$SyncPullResetData._({
    required this.dataRekeyPhase,
    required this.changes,
    this.nextCursor,
    required this.hasMore,
    required this.resetRequired,
  }) : super._();
  @override
  SyncPullResetData rebuild(void Function(SyncPullResetDataBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  SyncPullResetDataBuilder toBuilder() =>
      SyncPullResetDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SyncPullResetData &&
        dataRekeyPhase == other.dataRekeyPhase &&
        changes == other.changes &&
        nextCursor == other.nextCursor &&
        hasMore == other.hasMore &&
        resetRequired == other.resetRequired;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, dataRekeyPhase.hashCode);
    _$hash = $jc(_$hash, changes.hashCode);
    _$hash = $jc(_$hash, nextCursor.hashCode);
    _$hash = $jc(_$hash, hasMore.hashCode);
    _$hash = $jc(_$hash, resetRequired.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'SyncPullResetData')
          ..add('dataRekeyPhase', dataRekeyPhase)
          ..add('changes', changes)
          ..add('nextCursor', nextCursor)
          ..add('hasMore', hasMore)
          ..add('resetRequired', resetRequired))
        .toString();
  }
}

class SyncPullResetDataBuilder
    implements Builder<SyncPullResetData, SyncPullResetDataBuilder> {
  _$SyncPullResetData? _$v;

  SyncPullResetDataDataRekeyPhaseEnum? _dataRekeyPhase;
  SyncPullResetDataDataRekeyPhaseEnum? get dataRekeyPhase =>
      _$this._dataRekeyPhase;
  set dataRekeyPhase(SyncPullResetDataDataRekeyPhaseEnum? dataRekeyPhase) =>
      _$this._dataRekeyPhase = dataRekeyPhase;

  ListBuilder<SyncChange>? _changes;
  ListBuilder<SyncChange> get changes =>
      _$this._changes ??= ListBuilder<SyncChange>();
  set changes(ListBuilder<SyncChange>? changes) => _$this._changes = changes;

  SyncPullResetDataNextCursorEnum? _nextCursor;
  SyncPullResetDataNextCursorEnum? get nextCursor => _$this._nextCursor;
  set nextCursor(SyncPullResetDataNextCursorEnum? nextCursor) =>
      _$this._nextCursor = nextCursor;

  bool? _hasMore;
  bool? get hasMore => _$this._hasMore;
  set hasMore(bool? hasMore) => _$this._hasMore = hasMore;

  bool? _resetRequired;
  bool? get resetRequired => _$this._resetRequired;
  set resetRequired(bool? resetRequired) =>
      _$this._resetRequired = resetRequired;

  SyncPullResetDataBuilder() {
    SyncPullResetData._defaults(this);
  }

  SyncPullResetDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _dataRekeyPhase = $v.dataRekeyPhase;
      _changes = $v.changes.toBuilder();
      _nextCursor = $v.nextCursor;
      _hasMore = $v.hasMore;
      _resetRequired = $v.resetRequired;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SyncPullResetData other) {
    _$v = other as _$SyncPullResetData;
  }

  @override
  void update(void Function(SyncPullResetDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SyncPullResetData build() => _build();

  _$SyncPullResetData _build() {
    _$SyncPullResetData _$result;
    try {
      _$result =
          _$v ??
          _$SyncPullResetData._(
            dataRekeyPhase: BuiltValueNullFieldError.checkNotNull(
              dataRekeyPhase,
              r'SyncPullResetData',
              'dataRekeyPhase',
            ),
            changes: changes.build(),
            nextCursor: nextCursor,
            hasMore: BuiltValueNullFieldError.checkNotNull(
              hasMore,
              r'SyncPullResetData',
              'hasMore',
            ),
            resetRequired: BuiltValueNullFieldError.checkNotNull(
              resetRequired,
              r'SyncPullResetData',
              'resetRequired',
            ),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'changes';
        changes.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'SyncPullResetData',
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
