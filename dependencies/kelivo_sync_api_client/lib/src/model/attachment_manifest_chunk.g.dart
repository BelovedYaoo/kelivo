// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attachment_manifest_chunk.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$AttachmentManifestChunk extends AttachmentManifestChunk {
  @override
  final int chunkIndex;
  @override
  final int ciphertextBytes;

  factory _$AttachmentManifestChunk([
    void Function(AttachmentManifestChunkBuilder)? updates,
  ]) => (AttachmentManifestChunkBuilder()..update(updates))._build();

  _$AttachmentManifestChunk._({
    required this.chunkIndex,
    required this.ciphertextBytes,
  }) : super._();
  @override
  AttachmentManifestChunk rebuild(
    void Function(AttachmentManifestChunkBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  AttachmentManifestChunkBuilder toBuilder() =>
      AttachmentManifestChunkBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AttachmentManifestChunk &&
        chunkIndex == other.chunkIndex &&
        ciphertextBytes == other.ciphertextBytes;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, chunkIndex.hashCode);
    _$hash = $jc(_$hash, ciphertextBytes.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'AttachmentManifestChunk')
          ..add('chunkIndex', chunkIndex)
          ..add('ciphertextBytes', ciphertextBytes))
        .toString();
  }
}

class AttachmentManifestChunkBuilder
    implements
        Builder<AttachmentManifestChunk, AttachmentManifestChunkBuilder> {
  _$AttachmentManifestChunk? _$v;

  int? _chunkIndex;
  int? get chunkIndex => _$this._chunkIndex;
  set chunkIndex(int? chunkIndex) => _$this._chunkIndex = chunkIndex;

  int? _ciphertextBytes;
  int? get ciphertextBytes => _$this._ciphertextBytes;
  set ciphertextBytes(int? ciphertextBytes) =>
      _$this._ciphertextBytes = ciphertextBytes;

  AttachmentManifestChunkBuilder() {
    AttachmentManifestChunk._defaults(this);
  }

  AttachmentManifestChunkBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _chunkIndex = $v.chunkIndex;
      _ciphertextBytes = $v.ciphertextBytes;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AttachmentManifestChunk other) {
    _$v = other as _$AttachmentManifestChunk;
  }

  @override
  void update(void Function(AttachmentManifestChunkBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  AttachmentManifestChunk build() => _build();

  _$AttachmentManifestChunk _build() {
    final _$result =
        _$v ??
        _$AttachmentManifestChunk._(
          chunkIndex: BuiltValueNullFieldError.checkNotNull(
            chunkIndex,
            r'AttachmentManifestChunk',
            'chunkIndex',
          ),
          ciphertextBytes: BuiltValueNullFieldError.checkNotNull(
            ciphertextBytes,
            r'AttachmentManifestChunk',
            'ciphertextBytes',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
