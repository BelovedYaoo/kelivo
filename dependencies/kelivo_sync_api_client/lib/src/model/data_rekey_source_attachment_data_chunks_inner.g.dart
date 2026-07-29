// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_rekey_source_attachment_data_chunks_inner.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$DataRekeySourceAttachmentDataChunksInner
    extends DataRekeySourceAttachmentDataChunksInner {
  @override
  final int chunkIndex;
  @override
  final int ciphertextBytes;
  @override
  final String ciphertextDigest;

  factory _$DataRekeySourceAttachmentDataChunksInner([
    void Function(DataRekeySourceAttachmentDataChunksInnerBuilder)? updates,
  ]) => (DataRekeySourceAttachmentDataChunksInnerBuilder()..update(updates))
      ._build();

  _$DataRekeySourceAttachmentDataChunksInner._({
    required this.chunkIndex,
    required this.ciphertextBytes,
    required this.ciphertextDigest,
  }) : super._();
  @override
  DataRekeySourceAttachmentDataChunksInner rebuild(
    void Function(DataRekeySourceAttachmentDataChunksInnerBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  DataRekeySourceAttachmentDataChunksInnerBuilder toBuilder() =>
      DataRekeySourceAttachmentDataChunksInnerBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DataRekeySourceAttachmentDataChunksInner &&
        chunkIndex == other.chunkIndex &&
        ciphertextBytes == other.ciphertextBytes &&
        ciphertextDigest == other.ciphertextDigest;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, chunkIndex.hashCode);
    _$hash = $jc(_$hash, ciphertextBytes.hashCode);
    _$hash = $jc(_$hash, ciphertextDigest.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(
            r'DataRekeySourceAttachmentDataChunksInner',
          )
          ..add('chunkIndex', chunkIndex)
          ..add('ciphertextBytes', ciphertextBytes)
          ..add('ciphertextDigest', ciphertextDigest))
        .toString();
  }
}

class DataRekeySourceAttachmentDataChunksInnerBuilder
    implements
        Builder<
          DataRekeySourceAttachmentDataChunksInner,
          DataRekeySourceAttachmentDataChunksInnerBuilder
        > {
  _$DataRekeySourceAttachmentDataChunksInner? _$v;

  int? _chunkIndex;
  int? get chunkIndex => _$this._chunkIndex;
  set chunkIndex(int? chunkIndex) => _$this._chunkIndex = chunkIndex;

  int? _ciphertextBytes;
  int? get ciphertextBytes => _$this._ciphertextBytes;
  set ciphertextBytes(int? ciphertextBytes) =>
      _$this._ciphertextBytes = ciphertextBytes;

  String? _ciphertextDigest;
  String? get ciphertextDigest => _$this._ciphertextDigest;
  set ciphertextDigest(String? ciphertextDigest) =>
      _$this._ciphertextDigest = ciphertextDigest;

  DataRekeySourceAttachmentDataChunksInnerBuilder() {
    DataRekeySourceAttachmentDataChunksInner._defaults(this);
  }

  DataRekeySourceAttachmentDataChunksInnerBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _chunkIndex = $v.chunkIndex;
      _ciphertextBytes = $v.ciphertextBytes;
      _ciphertextDigest = $v.ciphertextDigest;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DataRekeySourceAttachmentDataChunksInner other) {
    _$v = other as _$DataRekeySourceAttachmentDataChunksInner;
  }

  @override
  void update(
    void Function(DataRekeySourceAttachmentDataChunksInnerBuilder)? updates,
  ) {
    if (updates != null) updates(this);
  }

  @override
  DataRekeySourceAttachmentDataChunksInner build() => _build();

  _$DataRekeySourceAttachmentDataChunksInner _build() {
    final _$result =
        _$v ??
        _$DataRekeySourceAttachmentDataChunksInner._(
          chunkIndex: BuiltValueNullFieldError.checkNotNull(
            chunkIndex,
            r'DataRekeySourceAttachmentDataChunksInner',
            'chunkIndex',
          ),
          ciphertextBytes: BuiltValueNullFieldError.checkNotNull(
            ciphertextBytes,
            r'DataRekeySourceAttachmentDataChunksInner',
            'ciphertextBytes',
          ),
          ciphertextDigest: BuiltValueNullFieldError.checkNotNull(
            ciphertextDigest,
            r'DataRekeySourceAttachmentDataChunksInner',
            'ciphertextDigest',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
