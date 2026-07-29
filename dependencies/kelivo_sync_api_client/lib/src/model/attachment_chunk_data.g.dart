// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attachment_chunk_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const AttachmentChunkDataDataRekeyPhaseEnum
_$attachmentChunkDataDataRekeyPhaseEnum_ready =
    const AttachmentChunkDataDataRekeyPhaseEnum._('ready');
const AttachmentChunkDataDataRekeyPhaseEnum
_$attachmentChunkDataDataRekeyPhaseEnum_rekeyPending =
    const AttachmentChunkDataDataRekeyPhaseEnum._('rekeyPending');

AttachmentChunkDataDataRekeyPhaseEnum
_$attachmentChunkDataDataRekeyPhaseEnumValueOf(String name) {
  switch (name) {
    case 'ready':
      return _$attachmentChunkDataDataRekeyPhaseEnum_ready;
    case 'rekeyPending':
      return _$attachmentChunkDataDataRekeyPhaseEnum_rekeyPending;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<AttachmentChunkDataDataRekeyPhaseEnum>
_$attachmentChunkDataDataRekeyPhaseEnumValues =
    BuiltSet<AttachmentChunkDataDataRekeyPhaseEnum>(
      const <AttachmentChunkDataDataRekeyPhaseEnum>[
        _$attachmentChunkDataDataRekeyPhaseEnum_ready,
        _$attachmentChunkDataDataRekeyPhaseEnum_rekeyPending,
      ],
    );

Serializer<AttachmentChunkDataDataRekeyPhaseEnum>
_$attachmentChunkDataDataRekeyPhaseEnumSerializer =
    _$AttachmentChunkDataDataRekeyPhaseEnumSerializer();

class _$AttachmentChunkDataDataRekeyPhaseEnumSerializer
    implements PrimitiveSerializer<AttachmentChunkDataDataRekeyPhaseEnum> {
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
    AttachmentChunkDataDataRekeyPhaseEnum,
  ];
  @override
  final String wireName = 'AttachmentChunkDataDataRekeyPhaseEnum';

  @override
  Object serialize(
    Serializers serializers,
    AttachmentChunkDataDataRekeyPhaseEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  AttachmentChunkDataDataRekeyPhaseEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => AttachmentChunkDataDataRekeyPhaseEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$AttachmentChunkData extends AttachmentChunkData {
  @override
  final AttachmentChunkDataDataRekeyPhaseEnum dataRekeyPhase;
  @override
  final String attachmentId;
  @override
  final String uploadId;
  @override
  final int chunkKeyEpoch;
  @override
  final int chunkIndex;
  @override
  final String ciphertext;
  @override
  final int ciphertextBytes;

  factory _$AttachmentChunkData([
    void Function(AttachmentChunkDataBuilder)? updates,
  ]) => (AttachmentChunkDataBuilder()..update(updates))._build();

  _$AttachmentChunkData._({
    required this.dataRekeyPhase,
    required this.attachmentId,
    required this.uploadId,
    required this.chunkKeyEpoch,
    required this.chunkIndex,
    required this.ciphertext,
    required this.ciphertextBytes,
  }) : super._();
  @override
  AttachmentChunkData rebuild(
    void Function(AttachmentChunkDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  AttachmentChunkDataBuilder toBuilder() =>
      AttachmentChunkDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AttachmentChunkData &&
        dataRekeyPhase == other.dataRekeyPhase &&
        attachmentId == other.attachmentId &&
        uploadId == other.uploadId &&
        chunkKeyEpoch == other.chunkKeyEpoch &&
        chunkIndex == other.chunkIndex &&
        ciphertext == other.ciphertext &&
        ciphertextBytes == other.ciphertextBytes;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, dataRekeyPhase.hashCode);
    _$hash = $jc(_$hash, attachmentId.hashCode);
    _$hash = $jc(_$hash, uploadId.hashCode);
    _$hash = $jc(_$hash, chunkKeyEpoch.hashCode);
    _$hash = $jc(_$hash, chunkIndex.hashCode);
    _$hash = $jc(_$hash, ciphertext.hashCode);
    _$hash = $jc(_$hash, ciphertextBytes.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'AttachmentChunkData')
          ..add('dataRekeyPhase', dataRekeyPhase)
          ..add('attachmentId', attachmentId)
          ..add('uploadId', uploadId)
          ..add('chunkKeyEpoch', chunkKeyEpoch)
          ..add('chunkIndex', chunkIndex)
          ..add('ciphertext', ciphertext)
          ..add('ciphertextBytes', ciphertextBytes))
        .toString();
  }
}

class AttachmentChunkDataBuilder
    implements Builder<AttachmentChunkData, AttachmentChunkDataBuilder> {
  _$AttachmentChunkData? _$v;

  AttachmentChunkDataDataRekeyPhaseEnum? _dataRekeyPhase;
  AttachmentChunkDataDataRekeyPhaseEnum? get dataRekeyPhase =>
      _$this._dataRekeyPhase;
  set dataRekeyPhase(AttachmentChunkDataDataRekeyPhaseEnum? dataRekeyPhase) =>
      _$this._dataRekeyPhase = dataRekeyPhase;

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

  int? _chunkIndex;
  int? get chunkIndex => _$this._chunkIndex;
  set chunkIndex(int? chunkIndex) => _$this._chunkIndex = chunkIndex;

  String? _ciphertext;
  String? get ciphertext => _$this._ciphertext;
  set ciphertext(String? ciphertext) => _$this._ciphertext = ciphertext;

  int? _ciphertextBytes;
  int? get ciphertextBytes => _$this._ciphertextBytes;
  set ciphertextBytes(int? ciphertextBytes) =>
      _$this._ciphertextBytes = ciphertextBytes;

  AttachmentChunkDataBuilder() {
    AttachmentChunkData._defaults(this);
  }

  AttachmentChunkDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _dataRekeyPhase = $v.dataRekeyPhase;
      _attachmentId = $v.attachmentId;
      _uploadId = $v.uploadId;
      _chunkKeyEpoch = $v.chunkKeyEpoch;
      _chunkIndex = $v.chunkIndex;
      _ciphertext = $v.ciphertext;
      _ciphertextBytes = $v.ciphertextBytes;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AttachmentChunkData other) {
    _$v = other as _$AttachmentChunkData;
  }

  @override
  void update(void Function(AttachmentChunkDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  AttachmentChunkData build() => _build();

  _$AttachmentChunkData _build() {
    final _$result =
        _$v ??
        _$AttachmentChunkData._(
          dataRekeyPhase: BuiltValueNullFieldError.checkNotNull(
            dataRekeyPhase,
            r'AttachmentChunkData',
            'dataRekeyPhase',
          ),
          attachmentId: BuiltValueNullFieldError.checkNotNull(
            attachmentId,
            r'AttachmentChunkData',
            'attachmentId',
          ),
          uploadId: BuiltValueNullFieldError.checkNotNull(
            uploadId,
            r'AttachmentChunkData',
            'uploadId',
          ),
          chunkKeyEpoch: BuiltValueNullFieldError.checkNotNull(
            chunkKeyEpoch,
            r'AttachmentChunkData',
            'chunkKeyEpoch',
          ),
          chunkIndex: BuiltValueNullFieldError.checkNotNull(
            chunkIndex,
            r'AttachmentChunkData',
            'chunkIndex',
          ),
          ciphertext: BuiltValueNullFieldError.checkNotNull(
            ciphertext,
            r'AttachmentChunkData',
            'ciphertext',
          ),
          ciphertextBytes: BuiltValueNullFieldError.checkNotNull(
            ciphertextBytes,
            r'AttachmentChunkData',
            'ciphertextBytes',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
