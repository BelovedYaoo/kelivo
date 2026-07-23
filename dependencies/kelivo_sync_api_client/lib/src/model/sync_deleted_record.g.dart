// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_deleted_record.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$SyncDeletedRecord extends SyncDeletedRecord {
  @override
  final String recordId;
  @override
  final int revision;
  @override
  final JsonObject? envelopeVersion;
  @override
  final JsonObject? keyEpoch;
  @override
  final JsonObject? ciphertext;
  @override
  final int ciphertextBytes;
  @override
  final DateTime deletedAt;
  @override
  final DateTime updatedAt;
  @override
  final String? updatedByDeviceId;
  @override
  final int lastChangeSeq;

  factory _$SyncDeletedRecord([
    void Function(SyncDeletedRecordBuilder)? updates,
  ]) => (SyncDeletedRecordBuilder()..update(updates))._build();

  _$SyncDeletedRecord._({
    required this.recordId,
    required this.revision,
    this.envelopeVersion,
    this.keyEpoch,
    this.ciphertext,
    required this.ciphertextBytes,
    required this.deletedAt,
    required this.updatedAt,
    this.updatedByDeviceId,
    required this.lastChangeSeq,
  }) : super._();
  @override
  SyncDeletedRecord rebuild(void Function(SyncDeletedRecordBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  SyncDeletedRecordBuilder toBuilder() =>
      SyncDeletedRecordBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SyncDeletedRecord &&
        recordId == other.recordId &&
        revision == other.revision &&
        envelopeVersion == other.envelopeVersion &&
        keyEpoch == other.keyEpoch &&
        ciphertext == other.ciphertext &&
        ciphertextBytes == other.ciphertextBytes &&
        deletedAt == other.deletedAt &&
        updatedAt == other.updatedAt &&
        updatedByDeviceId == other.updatedByDeviceId &&
        lastChangeSeq == other.lastChangeSeq;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, recordId.hashCode);
    _$hash = $jc(_$hash, revision.hashCode);
    _$hash = $jc(_$hash, envelopeVersion.hashCode);
    _$hash = $jc(_$hash, keyEpoch.hashCode);
    _$hash = $jc(_$hash, ciphertext.hashCode);
    _$hash = $jc(_$hash, ciphertextBytes.hashCode);
    _$hash = $jc(_$hash, deletedAt.hashCode);
    _$hash = $jc(_$hash, updatedAt.hashCode);
    _$hash = $jc(_$hash, updatedByDeviceId.hashCode);
    _$hash = $jc(_$hash, lastChangeSeq.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'SyncDeletedRecord')
          ..add('recordId', recordId)
          ..add('revision', revision)
          ..add('envelopeVersion', envelopeVersion)
          ..add('keyEpoch', keyEpoch)
          ..add('ciphertext', ciphertext)
          ..add('ciphertextBytes', ciphertextBytes)
          ..add('deletedAt', deletedAt)
          ..add('updatedAt', updatedAt)
          ..add('updatedByDeviceId', updatedByDeviceId)
          ..add('lastChangeSeq', lastChangeSeq))
        .toString();
  }
}

class SyncDeletedRecordBuilder
    implements Builder<SyncDeletedRecord, SyncDeletedRecordBuilder> {
  _$SyncDeletedRecord? _$v;

  String? _recordId;
  String? get recordId => _$this._recordId;
  set recordId(String? recordId) => _$this._recordId = recordId;

  int? _revision;
  int? get revision => _$this._revision;
  set revision(int? revision) => _$this._revision = revision;

  JsonObject? _envelopeVersion;
  JsonObject? get envelopeVersion => _$this._envelopeVersion;
  set envelopeVersion(JsonObject? envelopeVersion) =>
      _$this._envelopeVersion = envelopeVersion;

  JsonObject? _keyEpoch;
  JsonObject? get keyEpoch => _$this._keyEpoch;
  set keyEpoch(JsonObject? keyEpoch) => _$this._keyEpoch = keyEpoch;

  JsonObject? _ciphertext;
  JsonObject? get ciphertext => _$this._ciphertext;
  set ciphertext(JsonObject? ciphertext) => _$this._ciphertext = ciphertext;

  int? _ciphertextBytes;
  int? get ciphertextBytes => _$this._ciphertextBytes;
  set ciphertextBytes(int? ciphertextBytes) =>
      _$this._ciphertextBytes = ciphertextBytes;

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

  SyncDeletedRecordBuilder() {
    SyncDeletedRecord._defaults(this);
  }

  SyncDeletedRecordBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _recordId = $v.recordId;
      _revision = $v.revision;
      _envelopeVersion = $v.envelopeVersion;
      _keyEpoch = $v.keyEpoch;
      _ciphertext = $v.ciphertext;
      _ciphertextBytes = $v.ciphertextBytes;
      _deletedAt = $v.deletedAt;
      _updatedAt = $v.updatedAt;
      _updatedByDeviceId = $v.updatedByDeviceId;
      _lastChangeSeq = $v.lastChangeSeq;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SyncDeletedRecord other) {
    _$v = other as _$SyncDeletedRecord;
  }

  @override
  void update(void Function(SyncDeletedRecordBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SyncDeletedRecord build() => _build();

  _$SyncDeletedRecord _build() {
    final _$result =
        _$v ??
        _$SyncDeletedRecord._(
          recordId: BuiltValueNullFieldError.checkNotNull(
            recordId,
            r'SyncDeletedRecord',
            'recordId',
          ),
          revision: BuiltValueNullFieldError.checkNotNull(
            revision,
            r'SyncDeletedRecord',
            'revision',
          ),
          envelopeVersion: envelopeVersion,
          keyEpoch: keyEpoch,
          ciphertext: ciphertext,
          ciphertextBytes: BuiltValueNullFieldError.checkNotNull(
            ciphertextBytes,
            r'SyncDeletedRecord',
            'ciphertextBytes',
          ),
          deletedAt: BuiltValueNullFieldError.checkNotNull(
            deletedAt,
            r'SyncDeletedRecord',
            'deletedAt',
          ),
          updatedAt: BuiltValueNullFieldError.checkNotNull(
            updatedAt,
            r'SyncDeletedRecord',
            'updatedAt',
          ),
          updatedByDeviceId: updatedByDeviceId,
          lastChangeSeq: BuiltValueNullFieldError.checkNotNull(
            lastChangeSeq,
            r'SyncDeletedRecord',
            'lastChangeSeq',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
