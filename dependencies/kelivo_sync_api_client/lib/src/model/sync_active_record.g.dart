// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_active_record.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$SyncActiveRecord extends SyncActiveRecord {
  @override
  final String recordId;
  @override
  final int revision;
  @override
  final int envelopeVersion;
  @override
  final int keyEpoch;
  @override
  final String ciphertext;
  @override
  final int ciphertextBytes;
  @override
  final JsonObject? deletedAt;
  @override
  final DateTime updatedAt;
  @override
  final String? updatedByDeviceId;
  @override
  final int lastChangeSeq;

  factory _$SyncActiveRecord([
    void Function(SyncActiveRecordBuilder)? updates,
  ]) => (SyncActiveRecordBuilder()..update(updates))._build();

  _$SyncActiveRecord._({
    required this.recordId,
    required this.revision,
    required this.envelopeVersion,
    required this.keyEpoch,
    required this.ciphertext,
    required this.ciphertextBytes,
    this.deletedAt,
    required this.updatedAt,
    this.updatedByDeviceId,
    required this.lastChangeSeq,
  }) : super._();
  @override
  SyncActiveRecord rebuild(void Function(SyncActiveRecordBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  SyncActiveRecordBuilder toBuilder() =>
      SyncActiveRecordBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SyncActiveRecord &&
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
    return (newBuiltValueToStringHelper(r'SyncActiveRecord')
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

class SyncActiveRecordBuilder
    implements Builder<SyncActiveRecord, SyncActiveRecordBuilder> {
  _$SyncActiveRecord? _$v;

  String? _recordId;
  String? get recordId => _$this._recordId;
  set recordId(String? recordId) => _$this._recordId = recordId;

  int? _revision;
  int? get revision => _$this._revision;
  set revision(int? revision) => _$this._revision = revision;

  int? _envelopeVersion;
  int? get envelopeVersion => _$this._envelopeVersion;
  set envelopeVersion(int? envelopeVersion) =>
      _$this._envelopeVersion = envelopeVersion;

  int? _keyEpoch;
  int? get keyEpoch => _$this._keyEpoch;
  set keyEpoch(int? keyEpoch) => _$this._keyEpoch = keyEpoch;

  String? _ciphertext;
  String? get ciphertext => _$this._ciphertext;
  set ciphertext(String? ciphertext) => _$this._ciphertext = ciphertext;

  int? _ciphertextBytes;
  int? get ciphertextBytes => _$this._ciphertextBytes;
  set ciphertextBytes(int? ciphertextBytes) =>
      _$this._ciphertextBytes = ciphertextBytes;

  JsonObject? _deletedAt;
  JsonObject? get deletedAt => _$this._deletedAt;
  set deletedAt(JsonObject? deletedAt) => _$this._deletedAt = deletedAt;

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

  SyncActiveRecordBuilder() {
    SyncActiveRecord._defaults(this);
  }

  SyncActiveRecordBuilder get _$this {
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
  void replace(SyncActiveRecord other) {
    _$v = other as _$SyncActiveRecord;
  }

  @override
  void update(void Function(SyncActiveRecordBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SyncActiveRecord build() => _build();

  _$SyncActiveRecord _build() {
    final _$result =
        _$v ??
        _$SyncActiveRecord._(
          recordId: BuiltValueNullFieldError.checkNotNull(
            recordId,
            r'SyncActiveRecord',
            'recordId',
          ),
          revision: BuiltValueNullFieldError.checkNotNull(
            revision,
            r'SyncActiveRecord',
            'revision',
          ),
          envelopeVersion: BuiltValueNullFieldError.checkNotNull(
            envelopeVersion,
            r'SyncActiveRecord',
            'envelopeVersion',
          ),
          keyEpoch: BuiltValueNullFieldError.checkNotNull(
            keyEpoch,
            r'SyncActiveRecord',
            'keyEpoch',
          ),
          ciphertext: BuiltValueNullFieldError.checkNotNull(
            ciphertext,
            r'SyncActiveRecord',
            'ciphertext',
          ),
          ciphertextBytes: BuiltValueNullFieldError.checkNotNull(
            ciphertextBytes,
            r'SyncActiveRecord',
            'ciphertextBytes',
          ),
          deletedAt: deletedAt,
          updatedAt: BuiltValueNullFieldError.checkNotNull(
            updatedAt,
            r'SyncActiveRecord',
            'updatedAt',
          ),
          updatedByDeviceId: updatedByDeviceId,
          lastChangeSeq: BuiltValueNullFieldError.checkNotNull(
            lastChangeSeq,
            r'SyncActiveRecord',
            'lastChangeSeq',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
