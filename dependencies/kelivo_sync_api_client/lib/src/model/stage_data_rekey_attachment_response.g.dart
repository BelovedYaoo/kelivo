// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stage_data_rekey_attachment_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$StageDataRekeyAttachmentResponse
    extends StageDataRekeyAttachmentResponse {
  @override
  final DataRekeyAttachmentStageData data;

  factory _$StageDataRekeyAttachmentResponse([
    void Function(StageDataRekeyAttachmentResponseBuilder)? updates,
  ]) => (StageDataRekeyAttachmentResponseBuilder()..update(updates))._build();

  _$StageDataRekeyAttachmentResponse._({required this.data}) : super._();
  @override
  StageDataRekeyAttachmentResponse rebuild(
    void Function(StageDataRekeyAttachmentResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  StageDataRekeyAttachmentResponseBuilder toBuilder() =>
      StageDataRekeyAttachmentResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is StageDataRekeyAttachmentResponse && data == other.data;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, data.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(
      r'StageDataRekeyAttachmentResponse',
    )..add('data', data)).toString();
  }
}

class StageDataRekeyAttachmentResponseBuilder
    implements
        Builder<
          StageDataRekeyAttachmentResponse,
          StageDataRekeyAttachmentResponseBuilder
        > {
  _$StageDataRekeyAttachmentResponse? _$v;

  DataRekeyAttachmentStageDataBuilder? _data;
  DataRekeyAttachmentStageDataBuilder get data =>
      _$this._data ??= DataRekeyAttachmentStageDataBuilder();
  set data(DataRekeyAttachmentStageDataBuilder? data) => _$this._data = data;

  StageDataRekeyAttachmentResponseBuilder() {
    StageDataRekeyAttachmentResponse._defaults(this);
  }

  StageDataRekeyAttachmentResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(StageDataRekeyAttachmentResponse other) {
    _$v = other as _$StageDataRekeyAttachmentResponse;
  }

  @override
  void update(void Function(StageDataRekeyAttachmentResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  StageDataRekeyAttachmentResponse build() => _build();

  _$StageDataRekeyAttachmentResponse _build() {
    _$StageDataRekeyAttachmentResponse _$result;
    try {
      _$result =
          _$v ?? _$StageDataRekeyAttachmentResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'StageDataRekeyAttachmentResponse',
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
