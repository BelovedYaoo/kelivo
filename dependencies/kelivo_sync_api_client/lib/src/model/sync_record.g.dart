// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_record.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$SyncRecord extends SyncRecord {
  @override
  final SyncEntityType entityType;
  @override
  final String entityId;
  @override
  final String? parentId;
  @override
  final int revision;
  @override
  final int schemaVersion;
  @override
  final int? sortSeq;
  @override
  final BuiltMap<String, JsonObject?> payload;
  @override
  final DateTime? deletedAt;
  @override
  final DateTime updatedAt;
  @override
  final String? updatedByDeviceId;
  @override
  final int lastChangeSeq;

  factory _$SyncRecord([void Function(SyncRecordBuilder)? updates]) =>
      (SyncRecordBuilder()..update(updates))._build();

  _$SyncRecord._({
    required this.entityType,
    required this.entityId,
    this.parentId,
    required this.revision,
    required this.schemaVersion,
    this.sortSeq,
    required this.payload,
    this.deletedAt,
    required this.updatedAt,
    this.updatedByDeviceId,
    required this.lastChangeSeq,
  }) : super._();
  @override
  SyncRecord rebuild(void Function(SyncRecordBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  SyncRecordBuilder toBuilder() => SyncRecordBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SyncRecord &&
        entityType == other.entityType &&
        entityId == other.entityId &&
        parentId == other.parentId &&
        revision == other.revision &&
        schemaVersion == other.schemaVersion &&
        sortSeq == other.sortSeq &&
        payload == other.payload &&
        deletedAt == other.deletedAt &&
        updatedAt == other.updatedAt &&
        updatedByDeviceId == other.updatedByDeviceId &&
        lastChangeSeq == other.lastChangeSeq;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, entityType.hashCode);
    _$hash = $jc(_$hash, entityId.hashCode);
    _$hash = $jc(_$hash, parentId.hashCode);
    _$hash = $jc(_$hash, revision.hashCode);
    _$hash = $jc(_$hash, schemaVersion.hashCode);
    _$hash = $jc(_$hash, sortSeq.hashCode);
    _$hash = $jc(_$hash, payload.hashCode);
    _$hash = $jc(_$hash, deletedAt.hashCode);
    _$hash = $jc(_$hash, updatedAt.hashCode);
    _$hash = $jc(_$hash, updatedByDeviceId.hashCode);
    _$hash = $jc(_$hash, lastChangeSeq.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'SyncRecord')
          ..add('entityType', entityType)
          ..add('entityId', entityId)
          ..add('parentId', parentId)
          ..add('revision', revision)
          ..add('schemaVersion', schemaVersion)
          ..add('sortSeq', sortSeq)
          ..add('payload', payload)
          ..add('deletedAt', deletedAt)
          ..add('updatedAt', updatedAt)
          ..add('updatedByDeviceId', updatedByDeviceId)
          ..add('lastChangeSeq', lastChangeSeq))
        .toString();
  }
}

class SyncRecordBuilder implements Builder<SyncRecord, SyncRecordBuilder> {
  _$SyncRecord? _$v;

  SyncEntityType? _entityType;
  SyncEntityType? get entityType => _$this._entityType;
  set entityType(SyncEntityType? entityType) => _$this._entityType = entityType;

  String? _entityId;
  String? get entityId => _$this._entityId;
  set entityId(String? entityId) => _$this._entityId = entityId;

  String? _parentId;
  String? get parentId => _$this._parentId;
  set parentId(String? parentId) => _$this._parentId = parentId;

  int? _revision;
  int? get revision => _$this._revision;
  set revision(int? revision) => _$this._revision = revision;

  int? _schemaVersion;
  int? get schemaVersion => _$this._schemaVersion;
  set schemaVersion(int? schemaVersion) =>
      _$this._schemaVersion = schemaVersion;

  int? _sortSeq;
  int? get sortSeq => _$this._sortSeq;
  set sortSeq(int? sortSeq) => _$this._sortSeq = sortSeq;

  MapBuilder<String, JsonObject?>? _payload;
  MapBuilder<String, JsonObject?> get payload =>
      _$this._payload ??= MapBuilder<String, JsonObject?>();
  set payload(MapBuilder<String, JsonObject?>? payload) =>
      _$this._payload = payload;

  DateTime? _deletedAt;
  DateTime? get deletedAt => _$this._deletedAt;
  set deletedAt(DateTime? deletedAt) => _$this._deletedAt = deletedAt;

  DateTime? _updatedAt;
  DateTime? get updatedAt => _$this._updatedAt;
  set updatedAt(DateTime? updatedAt) => _$this._updatedAt = updatedAt;

  String? _updatedByDeviceId;
  String? get updatedByDeviceId => _$this._updatedByDeviceId;
  set updatedByDeviceId(String? updatedByDeviceId) =>
      _$this._updatedByDeviceId = updatedByDeviceId;

  int? _lastChangeSeq;
  int? get lastChangeSeq => _$this._lastChangeSeq;
  set lastChangeSeq(int? lastChangeSeq) =>
      _$this._lastChangeSeq = lastChangeSeq;

  SyncRecordBuilder() {
    SyncRecord._defaults(this);
  }

  SyncRecordBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _entityType = $v.entityType;
      _entityId = $v.entityId;
      _parentId = $v.parentId;
      _revision = $v.revision;
      _schemaVersion = $v.schemaVersion;
      _sortSeq = $v.sortSeq;
      _payload = $v.payload.toBuilder();
      _deletedAt = $v.deletedAt;
      _updatedAt = $v.updatedAt;
      _updatedByDeviceId = $v.updatedByDeviceId;
      _lastChangeSeq = $v.lastChangeSeq;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SyncRecord other) {
    _$v = other as _$SyncRecord;
  }

  @override
  void update(void Function(SyncRecordBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SyncRecord build() => _build();

  _$SyncRecord _build() {
    _$SyncRecord _$result;
    try {
      _$result =
          _$v ??
          _$SyncRecord._(
            entityType: BuiltValueNullFieldError.checkNotNull(
              entityType,
              r'SyncRecord',
              'entityType',
            ),
            entityId: BuiltValueNullFieldError.checkNotNull(
              entityId,
              r'SyncRecord',
              'entityId',
            ),
            parentId: parentId,
            revision: BuiltValueNullFieldError.checkNotNull(
              revision,
              r'SyncRecord',
              'revision',
            ),
            schemaVersion: BuiltValueNullFieldError.checkNotNull(
              schemaVersion,
              r'SyncRecord',
              'schemaVersion',
            ),
            sortSeq: sortSeq,
            payload: payload.build(),
            deletedAt: deletedAt,
            updatedAt: BuiltValueNullFieldError.checkNotNull(
              updatedAt,
              r'SyncRecord',
              'updatedAt',
            ),
            updatedByDeviceId: updatedByDeviceId,
            lastChangeSeq: BuiltValueNullFieldError.checkNotNull(
              lastChangeSeq,
              r'SyncRecord',
              'lastChangeSeq',
            ),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'payload';
        payload.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'SyncRecord',
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
