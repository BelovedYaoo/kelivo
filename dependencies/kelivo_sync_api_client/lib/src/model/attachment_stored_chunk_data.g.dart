// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attachment_stored_chunk_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const AttachmentStoredChunkDataStatusEnum
_$attachmentStoredChunkDataStatusEnum_stored =
    const AttachmentStoredChunkDataStatusEnum._('stored');

AttachmentStoredChunkDataStatusEnum
_$attachmentStoredChunkDataStatusEnumValueOf(String name) {
  switch (name) {
    case 'stored':
      return _$attachmentStoredChunkDataStatusEnum_stored;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<AttachmentStoredChunkDataStatusEnum>
_$attachmentStoredChunkDataStatusEnumValues =
    BuiltSet<AttachmentStoredChunkDataStatusEnum>(
      const <AttachmentStoredChunkDataStatusEnum>[
        _$attachmentStoredChunkDataStatusEnum_stored,
      ],
    );

Serializer<AttachmentStoredChunkDataStatusEnum>
_$attachmentStoredChunkDataStatusEnumSerializer =
    _$AttachmentStoredChunkDataStatusEnumSerializer();

class _$AttachmentStoredChunkDataStatusEnumSerializer
    implements PrimitiveSerializer<AttachmentStoredChunkDataStatusEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'stored': 'stored',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'stored': 'stored',
  };

  @override
  final Iterable<Type> types = const <Type>[
    AttachmentStoredChunkDataStatusEnum,
  ];
  @override
  final String wireName = 'AttachmentStoredChunkDataStatusEnum';

  @override
  Object serialize(
    Serializers serializers,
    AttachmentStoredChunkDataStatusEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  AttachmentStoredChunkDataStatusEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => AttachmentStoredChunkDataStatusEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$AttachmentStoredChunkData extends AttachmentStoredChunkData {
  @override
  final String attachmentId;
  @override
  final String uploadId;
  @override
  final int chunkIndex;
  @override
  final int ciphertextBytes;
  @override
  final AttachmentStoredChunkDataStatusEnum status;

  factory _$AttachmentStoredChunkData([
    void Function(AttachmentStoredChunkDataBuilder)? updates,
  ]) => (AttachmentStoredChunkDataBuilder()..update(updates))._build();

  _$AttachmentStoredChunkData._({
    required this.attachmentId,
    required this.uploadId,
    required this.chunkIndex,
    required this.ciphertextBytes,
    required this.status,
  }) : super._();
  @override
  AttachmentStoredChunkData rebuild(
    void Function(AttachmentStoredChunkDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  AttachmentStoredChunkDataBuilder toBuilder() =>
      AttachmentStoredChunkDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AttachmentStoredChunkData &&
        attachmentId == other.attachmentId &&
        uploadId == other.uploadId &&
        chunkIndex == other.chunkIndex &&
        ciphertextBytes == other.ciphertextBytes &&
        status == other.status;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, attachmentId.hashCode);
    _$hash = $jc(_$hash, uploadId.hashCode);
    _$hash = $jc(_$hash, chunkIndex.hashCode);
    _$hash = $jc(_$hash, ciphertextBytes.hashCode);
    _$hash = $jc(_$hash, status.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'AttachmentStoredChunkData')
          ..add('attachmentId', attachmentId)
          ..add('uploadId', uploadId)
          ..add('chunkIndex', chunkIndex)
          ..add('ciphertextBytes', ciphertextBytes)
          ..add('status', status))
        .toString();
  }
}

class AttachmentStoredChunkDataBuilder
    implements
        Builder<AttachmentStoredChunkData, AttachmentStoredChunkDataBuilder> {
  _$AttachmentStoredChunkData? _$v;

  String? _attachmentId;
  String? get attachmentId => _$this._attachmentId;
  set attachmentId(String? attachmentId) => _$this._attachmentId = attachmentId;

  String? _uploadId;
  String? get uploadId => _$this._uploadId;
  set uploadId(String? uploadId) => _$this._uploadId = uploadId;

  int? _chunkIndex;
  int? get chunkIndex => _$this._chunkIndex;
  set chunkIndex(int? chunkIndex) => _$this._chunkIndex = chunkIndex;

  int? _ciphertextBytes;
  int? get ciphertextBytes => _$this._ciphertextBytes;
  set ciphertextBytes(int? ciphertextBytes) =>
      _$this._ciphertextBytes = ciphertextBytes;

  AttachmentStoredChunkDataStatusEnum? _status;
  AttachmentStoredChunkDataStatusEnum? get status => _$this._status;
  set status(AttachmentStoredChunkDataStatusEnum? status) =>
      _$this._status = status;

  AttachmentStoredChunkDataBuilder() {
    AttachmentStoredChunkData._defaults(this);
  }

  AttachmentStoredChunkDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _attachmentId = $v.attachmentId;
      _uploadId = $v.uploadId;
      _chunkIndex = $v.chunkIndex;
      _ciphertextBytes = $v.ciphertextBytes;
      _status = $v.status;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AttachmentStoredChunkData other) {
    _$v = other as _$AttachmentStoredChunkData;
  }

  @override
  void update(void Function(AttachmentStoredChunkDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  AttachmentStoredChunkData build() => _build();

  _$AttachmentStoredChunkData _build() {
    final _$result =
        _$v ??
        _$AttachmentStoredChunkData._(
          attachmentId: BuiltValueNullFieldError.checkNotNull(
            attachmentId,
            r'AttachmentStoredChunkData',
            'attachmentId',
          ),
          uploadId: BuiltValueNullFieldError.checkNotNull(
            uploadId,
            r'AttachmentStoredChunkData',
            'uploadId',
          ),
          chunkIndex: BuiltValueNullFieldError.checkNotNull(
            chunkIndex,
            r'AttachmentStoredChunkData',
            'chunkIndex',
          ),
          ciphertextBytes: BuiltValueNullFieldError.checkNotNull(
            ciphertextBytes,
            r'AttachmentStoredChunkData',
            'ciphertextBytes',
          ),
          status: BuiltValueNullFieldError.checkNotNull(
            status,
            r'AttachmentStoredChunkData',
            'status',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
