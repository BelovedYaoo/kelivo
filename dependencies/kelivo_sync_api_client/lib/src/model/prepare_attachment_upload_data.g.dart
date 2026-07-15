// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'prepare_attachment_upload_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const PrepareAttachmentUploadDataUploadMethodEnum
_$prepareAttachmentUploadDataUploadMethodEnum_PUT =
    const PrepareAttachmentUploadDataUploadMethodEnum._('PUT');

PrepareAttachmentUploadDataUploadMethodEnum
_$prepareAttachmentUploadDataUploadMethodEnumValueOf(String name) {
  switch (name) {
    case 'PUT':
      return _$prepareAttachmentUploadDataUploadMethodEnum_PUT;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<PrepareAttachmentUploadDataUploadMethodEnum>
_$prepareAttachmentUploadDataUploadMethodEnumValues =
    BuiltSet<PrepareAttachmentUploadDataUploadMethodEnum>(
      const <PrepareAttachmentUploadDataUploadMethodEnum>[
        _$prepareAttachmentUploadDataUploadMethodEnum_PUT,
      ],
    );

Serializer<PrepareAttachmentUploadDataUploadMethodEnum>
_$prepareAttachmentUploadDataUploadMethodEnumSerializer =
    _$PrepareAttachmentUploadDataUploadMethodEnumSerializer();

class _$PrepareAttachmentUploadDataUploadMethodEnumSerializer
    implements
        PrimitiveSerializer<PrepareAttachmentUploadDataUploadMethodEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'PUT': 'PUT',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'PUT': 'PUT',
  };

  @override
  final Iterable<Type> types = const <Type>[
    PrepareAttachmentUploadDataUploadMethodEnum,
  ];
  @override
  final String wireName = 'PrepareAttachmentUploadDataUploadMethodEnum';

  @override
  Object serialize(
    Serializers serializers,
    PrepareAttachmentUploadDataUploadMethodEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  PrepareAttachmentUploadDataUploadMethodEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => PrepareAttachmentUploadDataUploadMethodEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$PrepareAttachmentUploadData extends PrepareAttachmentUploadData {
  @override
  final String blobId;
  @override
  final bool alreadyExists;
  @override
  final PrepareAttachmentUploadDataUploadMethodEnum uploadMethod;
  @override
  final String? uploadUrl;
  @override
  final DateTime? uploadExpiresAt;
  @override
  final BuiltMap<String, String> uploadHeaders;
  @override
  final String? etag;

  factory _$PrepareAttachmentUploadData([
    void Function(PrepareAttachmentUploadDataBuilder)? updates,
  ]) => (PrepareAttachmentUploadDataBuilder()..update(updates))._build();

  _$PrepareAttachmentUploadData._({
    required this.blobId,
    required this.alreadyExists,
    required this.uploadMethod,
    this.uploadUrl,
    this.uploadExpiresAt,
    required this.uploadHeaders,
    this.etag,
  }) : super._();
  @override
  PrepareAttachmentUploadData rebuild(
    void Function(PrepareAttachmentUploadDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  PrepareAttachmentUploadDataBuilder toBuilder() =>
      PrepareAttachmentUploadDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PrepareAttachmentUploadData &&
        blobId == other.blobId &&
        alreadyExists == other.alreadyExists &&
        uploadMethod == other.uploadMethod &&
        uploadUrl == other.uploadUrl &&
        uploadExpiresAt == other.uploadExpiresAt &&
        uploadHeaders == other.uploadHeaders &&
        etag == other.etag;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, blobId.hashCode);
    _$hash = $jc(_$hash, alreadyExists.hashCode);
    _$hash = $jc(_$hash, uploadMethod.hashCode);
    _$hash = $jc(_$hash, uploadUrl.hashCode);
    _$hash = $jc(_$hash, uploadExpiresAt.hashCode);
    _$hash = $jc(_$hash, uploadHeaders.hashCode);
    _$hash = $jc(_$hash, etag.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'PrepareAttachmentUploadData')
          ..add('blobId', blobId)
          ..add('alreadyExists', alreadyExists)
          ..add('uploadMethod', uploadMethod)
          ..add('uploadUrl', uploadUrl)
          ..add('uploadExpiresAt', uploadExpiresAt)
          ..add('uploadHeaders', uploadHeaders)
          ..add('etag', etag))
        .toString();
  }
}

class PrepareAttachmentUploadDataBuilder
    implements
        Builder<
          PrepareAttachmentUploadData,
          PrepareAttachmentUploadDataBuilder
        > {
  _$PrepareAttachmentUploadData? _$v;

  String? _blobId;
  String? get blobId => _$this._blobId;
  set blobId(String? blobId) => _$this._blobId = blobId;

  bool? _alreadyExists;
  bool? get alreadyExists => _$this._alreadyExists;
  set alreadyExists(bool? alreadyExists) =>
      _$this._alreadyExists = alreadyExists;

  PrepareAttachmentUploadDataUploadMethodEnum? _uploadMethod;
  PrepareAttachmentUploadDataUploadMethodEnum? get uploadMethod =>
      _$this._uploadMethod;
  set uploadMethod(PrepareAttachmentUploadDataUploadMethodEnum? uploadMethod) =>
      _$this._uploadMethod = uploadMethod;

  String? _uploadUrl;
  String? get uploadUrl => _$this._uploadUrl;
  set uploadUrl(String? uploadUrl) => _$this._uploadUrl = uploadUrl;

  DateTime? _uploadExpiresAt;
  DateTime? get uploadExpiresAt => _$this._uploadExpiresAt;
  set uploadExpiresAt(DateTime? uploadExpiresAt) =>
      _$this._uploadExpiresAt = uploadExpiresAt;

  MapBuilder<String, String>? _uploadHeaders;
  MapBuilder<String, String> get uploadHeaders =>
      _$this._uploadHeaders ??= MapBuilder<String, String>();
  set uploadHeaders(MapBuilder<String, String>? uploadHeaders) =>
      _$this._uploadHeaders = uploadHeaders;

  String? _etag;
  String? get etag => _$this._etag;
  set etag(String? etag) => _$this._etag = etag;

  PrepareAttachmentUploadDataBuilder() {
    PrepareAttachmentUploadData._defaults(this);
  }

  PrepareAttachmentUploadDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _blobId = $v.blobId;
      _alreadyExists = $v.alreadyExists;
      _uploadMethod = $v.uploadMethod;
      _uploadUrl = $v.uploadUrl;
      _uploadExpiresAt = $v.uploadExpiresAt;
      _uploadHeaders = $v.uploadHeaders.toBuilder();
      _etag = $v.etag;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(PrepareAttachmentUploadData other) {
    _$v = other as _$PrepareAttachmentUploadData;
  }

  @override
  void update(void Function(PrepareAttachmentUploadDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  PrepareAttachmentUploadData build() => _build();

  _$PrepareAttachmentUploadData _build() {
    _$PrepareAttachmentUploadData _$result;
    try {
      _$result =
          _$v ??
          _$PrepareAttachmentUploadData._(
            blobId: BuiltValueNullFieldError.checkNotNull(
              blobId,
              r'PrepareAttachmentUploadData',
              'blobId',
            ),
            alreadyExists: BuiltValueNullFieldError.checkNotNull(
              alreadyExists,
              r'PrepareAttachmentUploadData',
              'alreadyExists',
            ),
            uploadMethod: BuiltValueNullFieldError.checkNotNull(
              uploadMethod,
              r'PrepareAttachmentUploadData',
              'uploadMethod',
            ),
            uploadUrl: uploadUrl,
            uploadExpiresAt: uploadExpiresAt,
            uploadHeaders: uploadHeaders.build(),
            etag: etag,
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'uploadHeaders';
        uploadHeaders.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'PrepareAttachmentUploadData',
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
