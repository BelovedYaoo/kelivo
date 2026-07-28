// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_record.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$SyncRecord extends SyncRecord {
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
  final DateTime updatedAt;
  @override
  final String? updatedByDeviceId;
  @override
  final int lastChangeSeq;

  factory _$SyncRecord([void Function(SyncRecordBuilder)? updates]) =>
      (SyncRecordBuilder()..update(updates))._build();

  _$SyncRecord._({
    required this.recordId,
    required this.revision,
    required this.envelopeVersion,
    required this.keyEpoch,
    required this.ciphertext,
    required this.ciphertextBytes,
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
        recordId == other.recordId &&
        revision == other.revision &&
        envelopeVersion == other.envelopeVersion &&
        keyEpoch == other.keyEpoch &&
        ciphertext == other.ciphertext &&
        ciphertextBytes == other.ciphertextBytes &&
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
    _$hash = $jc(_$hash, updatedAt.hashCode);
    _$hash = $jc(_$hash, updatedByDeviceId.hashCode);
    _$hash = $jc(_$hash, lastChangeSeq.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'SyncRecord')
          ..add('recordId', recordId)
          ..add('revision', revision)
          ..add('envelopeVersion', envelopeVersion)
          ..add('keyEpoch', keyEpoch)
          ..add('ciphertext', ciphertext)
          ..add('ciphertextBytes', ciphertextBytes)
          ..add('updatedAt', updatedAt)
          ..add('updatedByDeviceId', updatedByDeviceId)
          ..add('lastChangeSeq', lastChangeSeq))
        .toString();
  }
}

class SyncRecordBuilder implements Builder<SyncRecord, SyncRecordBuilder> {
  _$SyncRecord? _$v;

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
      _recordId = $v.recordId;
      _revision = $v.revision;
      _envelopeVersion = $v.envelopeVersion;
      _keyEpoch = $v.keyEpoch;
      _ciphertext = $v.ciphertext;
      _ciphertextBytes = $v.ciphertextBytes;
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
    final _$result =
        _$v ??
        _$SyncRecord._(
          recordId: BuiltValueNullFieldError.checkNotNull(
            recordId,
            r'SyncRecord',
            'recordId',
          ),
          revision: BuiltValueNullFieldError.checkNotNull(
            revision,
            r'SyncRecord',
            'revision',
          ),
          envelopeVersion: BuiltValueNullFieldError.checkNotNull(
            envelopeVersion,
            r'SyncRecord',
            'envelopeVersion',
          ),
          keyEpoch: BuiltValueNullFieldError.checkNotNull(
            keyEpoch,
            r'SyncRecord',
            'keyEpoch',
          ),
          ciphertext: BuiltValueNullFieldError.checkNotNull(
            ciphertext,
            r'SyncRecord',
            'ciphertext',
          ),
          ciphertextBytes: BuiltValueNullFieldError.checkNotNull(
            ciphertextBytes,
            r'SyncRecord',
            'ciphertextBytes',
          ),
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
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
