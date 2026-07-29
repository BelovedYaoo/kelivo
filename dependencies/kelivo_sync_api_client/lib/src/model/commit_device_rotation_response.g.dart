// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'commit_device_rotation_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$CommitDeviceRotationResponse extends CommitDeviceRotationResponse {
  @override
  final CommitDeviceRotationData data;

  factory _$CommitDeviceRotationResponse([
    void Function(CommitDeviceRotationResponseBuilder)? updates,
  ]) => (CommitDeviceRotationResponseBuilder()..update(updates))._build();

  _$CommitDeviceRotationResponse._({required this.data}) : super._();
  @override
  CommitDeviceRotationResponse rebuild(
    void Function(CommitDeviceRotationResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  CommitDeviceRotationResponseBuilder toBuilder() =>
      CommitDeviceRotationResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is CommitDeviceRotationResponse && data == other.data;
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
      r'CommitDeviceRotationResponse',
    )..add('data', data)).toString();
  }
}

class CommitDeviceRotationResponseBuilder
    implements
        Builder<
          CommitDeviceRotationResponse,
          CommitDeviceRotationResponseBuilder
        > {
  _$CommitDeviceRotationResponse? _$v;

  CommitDeviceRotationDataBuilder? _data;
  CommitDeviceRotationDataBuilder get data =>
      _$this._data ??= CommitDeviceRotationDataBuilder();
  set data(CommitDeviceRotationDataBuilder? data) => _$this._data = data;

  CommitDeviceRotationResponseBuilder() {
    CommitDeviceRotationResponse._defaults(this);
  }

  CommitDeviceRotationResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(CommitDeviceRotationResponse other) {
    _$v = other as _$CommitDeviceRotationResponse;
  }

  @override
  void update(void Function(CommitDeviceRotationResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  CommitDeviceRotationResponse build() => _build();

  _$CommitDeviceRotationResponse _build() {
    _$CommitDeviceRotationResponse _$result;
    try {
      _$result = _$v ?? _$CommitDeviceRotationResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'CommitDeviceRotationResponse',
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
