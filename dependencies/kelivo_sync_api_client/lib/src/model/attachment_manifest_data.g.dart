// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attachment_manifest_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const AttachmentManifestDataDataRekeyPhaseEnum
_$attachmentManifestDataDataRekeyPhaseEnum_ready =
    const AttachmentManifestDataDataRekeyPhaseEnum._('ready');
const AttachmentManifestDataDataRekeyPhaseEnum
_$attachmentManifestDataDataRekeyPhaseEnum_rekeyPending =
    const AttachmentManifestDataDataRekeyPhaseEnum._('rekeyPending');

AttachmentManifestDataDataRekeyPhaseEnum
_$attachmentManifestDataDataRekeyPhaseEnumValueOf(String name) {
  switch (name) {
    case 'ready':
      return _$attachmentManifestDataDataRekeyPhaseEnum_ready;
    case 'rekeyPending':
      return _$attachmentManifestDataDataRekeyPhaseEnum_rekeyPending;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<AttachmentManifestDataDataRekeyPhaseEnum>
_$attachmentManifestDataDataRekeyPhaseEnumValues =
    BuiltSet<AttachmentManifestDataDataRekeyPhaseEnum>(
      const <AttachmentManifestDataDataRekeyPhaseEnum>[
        _$attachmentManifestDataDataRekeyPhaseEnum_ready,
        _$attachmentManifestDataDataRekeyPhaseEnum_rekeyPending,
      ],
    );

Serializer<AttachmentManifestDataDataRekeyPhaseEnum>
_$attachmentManifestDataDataRekeyPhaseEnumSerializer =
    _$AttachmentManifestDataDataRekeyPhaseEnumSerializer();

class _$AttachmentManifestDataDataRekeyPhaseEnumSerializer
    implements PrimitiveSerializer<AttachmentManifestDataDataRekeyPhaseEnum> {
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
    AttachmentManifestDataDataRekeyPhaseEnum,
  ];
  @override
  final String wireName = 'AttachmentManifestDataDataRekeyPhaseEnum';

  @override
  Object serialize(
    Serializers serializers,
    AttachmentManifestDataDataRekeyPhaseEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  AttachmentManifestDataDataRekeyPhaseEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => AttachmentManifestDataDataRekeyPhaseEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$AttachmentManifestData extends AttachmentManifestData {
  @override
  final AttachmentManifestDataDataRekeyPhaseEnum dataRekeyPhase;
  @override
  final String attachmentId;
  @override
  final String uploadId;
  @override
  final int chunkKeyEpoch;
  @override
  final int manifestKeyEpoch;
  @override
  final int manifestRevision;
  @override
  final int chunkCount;
  @override
  final int totalCiphertextBytes;
  @override
  final String manifestCiphertext;
  @override
  final int manifestCiphertextBytes;
  @override
  final BuiltList<AttachmentManifestChunk> chunks;
  @override
  final DateTime committedAt;

  factory _$AttachmentManifestData([
    void Function(AttachmentManifestDataBuilder)? updates,
  ]) => (AttachmentManifestDataBuilder()..update(updates))._build();

  _$AttachmentManifestData._({
    required this.dataRekeyPhase,
    required this.attachmentId,
    required this.uploadId,
    required this.chunkKeyEpoch,
    required this.manifestKeyEpoch,
    required this.manifestRevision,
    required this.chunkCount,
    required this.totalCiphertextBytes,
    required this.manifestCiphertext,
    required this.manifestCiphertextBytes,
    required this.chunks,
    required this.committedAt,
  }) : super._();
  @override
  AttachmentManifestData rebuild(
    void Function(AttachmentManifestDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  AttachmentManifestDataBuilder toBuilder() =>
      AttachmentManifestDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AttachmentManifestData &&
        dataRekeyPhase == other.dataRekeyPhase &&
        attachmentId == other.attachmentId &&
        uploadId == other.uploadId &&
        chunkKeyEpoch == other.chunkKeyEpoch &&
        manifestKeyEpoch == other.manifestKeyEpoch &&
        manifestRevision == other.manifestRevision &&
        chunkCount == other.chunkCount &&
        totalCiphertextBytes == other.totalCiphertextBytes &&
        manifestCiphertext == other.manifestCiphertext &&
        manifestCiphertextBytes == other.manifestCiphertextBytes &&
        chunks == other.chunks &&
        committedAt == other.committedAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, dataRekeyPhase.hashCode);
    _$hash = $jc(_$hash, attachmentId.hashCode);
    _$hash = $jc(_$hash, uploadId.hashCode);
    _$hash = $jc(_$hash, chunkKeyEpoch.hashCode);
    _$hash = $jc(_$hash, manifestKeyEpoch.hashCode);
    _$hash = $jc(_$hash, manifestRevision.hashCode);
    _$hash = $jc(_$hash, chunkCount.hashCode);
    _$hash = $jc(_$hash, totalCiphertextBytes.hashCode);
    _$hash = $jc(_$hash, manifestCiphertext.hashCode);
    _$hash = $jc(_$hash, manifestCiphertextBytes.hashCode);
    _$hash = $jc(_$hash, chunks.hashCode);
    _$hash = $jc(_$hash, committedAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'AttachmentManifestData')
          ..add('dataRekeyPhase', dataRekeyPhase)
          ..add('attachmentId', attachmentId)
          ..add('uploadId', uploadId)
          ..add('chunkKeyEpoch', chunkKeyEpoch)
          ..add('manifestKeyEpoch', manifestKeyEpoch)
          ..add('manifestRevision', manifestRevision)
          ..add('chunkCount', chunkCount)
          ..add('totalCiphertextBytes', totalCiphertextBytes)
          ..add('manifestCiphertext', manifestCiphertext)
          ..add('manifestCiphertextBytes', manifestCiphertextBytes)
          ..add('chunks', chunks)
          ..add('committedAt', committedAt))
        .toString();
  }
}

class AttachmentManifestDataBuilder
    implements Builder<AttachmentManifestData, AttachmentManifestDataBuilder> {
  _$AttachmentManifestData? _$v;

  AttachmentManifestDataDataRekeyPhaseEnum? _dataRekeyPhase;
  AttachmentManifestDataDataRekeyPhaseEnum? get dataRekeyPhase =>
      _$this._dataRekeyPhase;
  set dataRekeyPhase(
    AttachmentManifestDataDataRekeyPhaseEnum? dataRekeyPhase,
  ) => _$this._dataRekeyPhase = dataRekeyPhase;

  String? _attachmentId;
  String? get attachmentId => _$this._attachmentId;
  set attachmentId(String? attachmentId) => _$this._attachmentId = attachmentId;

  String? _uploadId;
  String? get uploadId => _$this._uploadId;
  set uploadId(String? uploadId) => _$this._uploadId = uploadId;

  int? _chunkKeyEpoch;
  int? get chunkKeyEpoch => _$this._chunkKeyEpoch;
  set chunkKeyEpoch(int? chunkKeyEpoch) =>
      _$this._chunkKeyEpoch = chunkKeyEpoch;

  int? _manifestKeyEpoch;
  int? get manifestKeyEpoch => _$this._manifestKeyEpoch;
  set manifestKeyEpoch(int? manifestKeyEpoch) =>
      _$this._manifestKeyEpoch = manifestKeyEpoch;

  int? _manifestRevision;
  int? get manifestRevision => _$this._manifestRevision;
  set manifestRevision(int? manifestRevision) =>
      _$this._manifestRevision = manifestRevision;

  int? _chunkCount;
  int? get chunkCount => _$this._chunkCount;
  set chunkCount(int? chunkCount) => _$this._chunkCount = chunkCount;

  int? _totalCiphertextBytes;
  int? get totalCiphertextBytes => _$this._totalCiphertextBytes;
  set totalCiphertextBytes(int? totalCiphertextBytes) =>
      _$this._totalCiphertextBytes = totalCiphertextBytes;

  String? _manifestCiphertext;
  String? get manifestCiphertext => _$this._manifestCiphertext;
  set manifestCiphertext(String? manifestCiphertext) =>
      _$this._manifestCiphertext = manifestCiphertext;

  int? _manifestCiphertextBytes;
  int? get manifestCiphertextBytes => _$this._manifestCiphertextBytes;
  set manifestCiphertextBytes(int? manifestCiphertextBytes) =>
      _$this._manifestCiphertextBytes = manifestCiphertextBytes;

  ListBuilder<AttachmentManifestChunk>? _chunks;
  ListBuilder<AttachmentManifestChunk> get chunks =>
      _$this._chunks ??= ListBuilder<AttachmentManifestChunk>();
  set chunks(ListBuilder<AttachmentManifestChunk>? chunks) =>
      _$this._chunks = chunks;

  DateTime? _committedAt;
  DateTime? get committedAt => _$this._committedAt;
  set committedAt(DateTime? committedAt) => _$this._committedAt = committedAt;

  AttachmentManifestDataBuilder() {
    AttachmentManifestData._defaults(this);
  }

  AttachmentManifestDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _dataRekeyPhase = $v.dataRekeyPhase;
      _attachmentId = $v.attachmentId;
      _uploadId = $v.uploadId;
      _chunkKeyEpoch = $v.chunkKeyEpoch;
      _manifestKeyEpoch = $v.manifestKeyEpoch;
      _manifestRevision = $v.manifestRevision;
      _chunkCount = $v.chunkCount;
      _totalCiphertextBytes = $v.totalCiphertextBytes;
      _manifestCiphertext = $v.manifestCiphertext;
      _manifestCiphertextBytes = $v.manifestCiphertextBytes;
      _chunks = $v.chunks.toBuilder();
      _committedAt = $v.committedAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AttachmentManifestData other) {
    _$v = other as _$AttachmentManifestData;
  }

  @override
  void update(void Function(AttachmentManifestDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  AttachmentManifestData build() => _build();

  _$AttachmentManifestData _build() {
    _$AttachmentManifestData _$result;
    try {
      _$result =
          _$v ??
          _$AttachmentManifestData._(
            dataRekeyPhase: BuiltValueNullFieldError.checkNotNull(
              dataRekeyPhase,
              r'AttachmentManifestData',
              'dataRekeyPhase',
            ),
            attachmentId: BuiltValueNullFieldError.checkNotNull(
              attachmentId,
              r'AttachmentManifestData',
              'attachmentId',
            ),
            uploadId: BuiltValueNullFieldError.checkNotNull(
              uploadId,
              r'AttachmentManifestData',
              'uploadId',
            ),
            chunkKeyEpoch: BuiltValueNullFieldError.checkNotNull(
              chunkKeyEpoch,
              r'AttachmentManifestData',
              'chunkKeyEpoch',
            ),
            manifestKeyEpoch: BuiltValueNullFieldError.checkNotNull(
              manifestKeyEpoch,
              r'AttachmentManifestData',
              'manifestKeyEpoch',
            ),
            manifestRevision: BuiltValueNullFieldError.checkNotNull(
              manifestRevision,
              r'AttachmentManifestData',
              'manifestRevision',
            ),
            chunkCount: BuiltValueNullFieldError.checkNotNull(
              chunkCount,
              r'AttachmentManifestData',
              'chunkCount',
            ),
            totalCiphertextBytes: BuiltValueNullFieldError.checkNotNull(
              totalCiphertextBytes,
              r'AttachmentManifestData',
              'totalCiphertextBytes',
            ),
            manifestCiphertext: BuiltValueNullFieldError.checkNotNull(
              manifestCiphertext,
              r'AttachmentManifestData',
              'manifestCiphertext',
            ),
            manifestCiphertextBytes: BuiltValueNullFieldError.checkNotNull(
              manifestCiphertextBytes,
              r'AttachmentManifestData',
              'manifestCiphertextBytes',
            ),
            chunks: chunks.build(),
            committedAt: BuiltValueNullFieldError.checkNotNull(
              committedAt,
              r'AttachmentManifestData',
              'committedAt',
            ),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'chunks';
        chunks.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'AttachmentManifestData',
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
