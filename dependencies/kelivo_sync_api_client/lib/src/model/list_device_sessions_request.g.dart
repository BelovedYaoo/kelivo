// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_device_sessions_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const ListDeviceSessionsRequestStatusEnum
_$listDeviceSessionsRequestStatusEnum_active =
    const ListDeviceSessionsRequestStatusEnum._('active');
const ListDeviceSessionsRequestStatusEnum
_$listDeviceSessionsRequestStatusEnum_revoked =
    const ListDeviceSessionsRequestStatusEnum._('revoked');

ListDeviceSessionsRequestStatusEnum
_$listDeviceSessionsRequestStatusEnumValueOf(String name) {
  switch (name) {
    case 'active':
      return _$listDeviceSessionsRequestStatusEnum_active;
    case 'revoked':
      return _$listDeviceSessionsRequestStatusEnum_revoked;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<ListDeviceSessionsRequestStatusEnum>
_$listDeviceSessionsRequestStatusEnumValues =
    BuiltSet<ListDeviceSessionsRequestStatusEnum>(
      const <ListDeviceSessionsRequestStatusEnum>[
        _$listDeviceSessionsRequestStatusEnum_active,
        _$listDeviceSessionsRequestStatusEnum_revoked,
      ],
    );

Serializer<ListDeviceSessionsRequestStatusEnum>
_$listDeviceSessionsRequestStatusEnumSerializer =
    _$ListDeviceSessionsRequestStatusEnumSerializer();

class _$ListDeviceSessionsRequestStatusEnumSerializer
    implements PrimitiveSerializer<ListDeviceSessionsRequestStatusEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'active': 'active',
    'revoked': 'revoked',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'active': 'active',
    'revoked': 'revoked',
  };

  @override
  final Iterable<Type> types = const <Type>[
    ListDeviceSessionsRequestStatusEnum,
  ];
  @override
  final String wireName = 'ListDeviceSessionsRequestStatusEnum';

  @override
  Object serialize(
    Serializers serializers,
    ListDeviceSessionsRequestStatusEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  ListDeviceSessionsRequestStatusEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => ListDeviceSessionsRequestStatusEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$ListDeviceSessionsRequest extends ListDeviceSessionsRequest {
  @override
  final ListDeviceSessionsRequestStatusEnum? status;
  @override
  final int? pageIndex;
  @override
  final int? pageSize;

  factory _$ListDeviceSessionsRequest([
    void Function(ListDeviceSessionsRequestBuilder)? updates,
  ]) => (ListDeviceSessionsRequestBuilder()..update(updates))._build();

  _$ListDeviceSessionsRequest._({this.status, this.pageIndex, this.pageSize})
    : super._();
  @override
  ListDeviceSessionsRequest rebuild(
    void Function(ListDeviceSessionsRequestBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  ListDeviceSessionsRequestBuilder toBuilder() =>
      ListDeviceSessionsRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ListDeviceSessionsRequest &&
        status == other.status &&
        pageIndex == other.pageIndex &&
        pageSize == other.pageSize;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, status.hashCode);
    _$hash = $jc(_$hash, pageIndex.hashCode);
    _$hash = $jc(_$hash, pageSize.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'ListDeviceSessionsRequest')
          ..add('status', status)
          ..add('pageIndex', pageIndex)
          ..add('pageSize', pageSize))
        .toString();
  }
}

class ListDeviceSessionsRequestBuilder
    implements
        Builder<ListDeviceSessionsRequest, ListDeviceSessionsRequestBuilder> {
  _$ListDeviceSessionsRequest? _$v;

  ListDeviceSessionsRequestStatusEnum? _status;
  ListDeviceSessionsRequestStatusEnum? get status => _$this._status;
  set status(ListDeviceSessionsRequestStatusEnum? status) =>
      _$this._status = status;

  int? _pageIndex;
  int? get pageIndex => _$this._pageIndex;
  set pageIndex(int? pageIndex) => _$this._pageIndex = pageIndex;

  int? _pageSize;
  int? get pageSize => _$this._pageSize;
  set pageSize(int? pageSize) => _$this._pageSize = pageSize;

  ListDeviceSessionsRequestBuilder() {
    ListDeviceSessionsRequest._defaults(this);
  }

  ListDeviceSessionsRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _status = $v.status;
      _pageIndex = $v.pageIndex;
      _pageSize = $v.pageSize;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ListDeviceSessionsRequest other) {
    _$v = other as _$ListDeviceSessionsRequest;
  }

  @override
  void update(void Function(ListDeviceSessionsRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ListDeviceSessionsRequest build() => _build();

  _$ListDeviceSessionsRequest _build() {
    final _$result =
        _$v ??
        _$ListDeviceSessionsRequest._(
          status: status,
          pageIndex: pageIndex,
          pageSize: pageSize,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
