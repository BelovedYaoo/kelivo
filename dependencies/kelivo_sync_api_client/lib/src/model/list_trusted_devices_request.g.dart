// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_trusted_devices_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const ListTrustedDevicesRequestStatusEnum
_$listTrustedDevicesRequestStatusEnum_active =
    const ListTrustedDevicesRequestStatusEnum._('active');
const ListTrustedDevicesRequestStatusEnum
_$listTrustedDevicesRequestStatusEnum_revoked =
    const ListTrustedDevicesRequestStatusEnum._('revoked');

ListTrustedDevicesRequestStatusEnum
_$listTrustedDevicesRequestStatusEnumValueOf(String name) {
  switch (name) {
    case 'active':
      return _$listTrustedDevicesRequestStatusEnum_active;
    case 'revoked':
      return _$listTrustedDevicesRequestStatusEnum_revoked;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<ListTrustedDevicesRequestStatusEnum>
_$listTrustedDevicesRequestStatusEnumValues =
    BuiltSet<ListTrustedDevicesRequestStatusEnum>(
      const <ListTrustedDevicesRequestStatusEnum>[
        _$listTrustedDevicesRequestStatusEnum_active,
        _$listTrustedDevicesRequestStatusEnum_revoked,
      ],
    );

Serializer<ListTrustedDevicesRequestStatusEnum>
_$listTrustedDevicesRequestStatusEnumSerializer =
    _$ListTrustedDevicesRequestStatusEnumSerializer();

class _$ListTrustedDevicesRequestStatusEnumSerializer
    implements PrimitiveSerializer<ListTrustedDevicesRequestStatusEnum> {
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
    ListTrustedDevicesRequestStatusEnum,
  ];
  @override
  final String wireName = 'ListTrustedDevicesRequestStatusEnum';

  @override
  Object serialize(
    Serializers serializers,
    ListTrustedDevicesRequestStatusEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  ListTrustedDevicesRequestStatusEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => ListTrustedDevicesRequestStatusEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$ListTrustedDevicesRequest extends ListTrustedDevicesRequest {
  @override
  final ListTrustedDevicesRequestStatusEnum? status;
  @override
  final int? pageIndex;
  @override
  final int? pageSize;

  factory _$ListTrustedDevicesRequest([
    void Function(ListTrustedDevicesRequestBuilder)? updates,
  ]) => (ListTrustedDevicesRequestBuilder()..update(updates))._build();

  _$ListTrustedDevicesRequest._({this.status, this.pageIndex, this.pageSize})
    : super._();
  @override
  ListTrustedDevicesRequest rebuild(
    void Function(ListTrustedDevicesRequestBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  ListTrustedDevicesRequestBuilder toBuilder() =>
      ListTrustedDevicesRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ListTrustedDevicesRequest &&
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
    return (newBuiltValueToStringHelper(r'ListTrustedDevicesRequest')
          ..add('status', status)
          ..add('pageIndex', pageIndex)
          ..add('pageSize', pageSize))
        .toString();
  }
}

class ListTrustedDevicesRequestBuilder
    implements
        Builder<ListTrustedDevicesRequest, ListTrustedDevicesRequestBuilder> {
  _$ListTrustedDevicesRequest? _$v;

  ListTrustedDevicesRequestStatusEnum? _status;
  ListTrustedDevicesRequestStatusEnum? get status => _$this._status;
  set status(ListTrustedDevicesRequestStatusEnum? status) =>
      _$this._status = status;

  int? _pageIndex;
  int? get pageIndex => _$this._pageIndex;
  set pageIndex(int? pageIndex) => _$this._pageIndex = pageIndex;

  int? _pageSize;
  int? get pageSize => _$this._pageSize;
  set pageSize(int? pageSize) => _$this._pageSize = pageSize;

  ListTrustedDevicesRequestBuilder() {
    ListTrustedDevicesRequest._defaults(this);
  }

  ListTrustedDevicesRequestBuilder get _$this {
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
  void replace(ListTrustedDevicesRequest other) {
    _$v = other as _$ListTrustedDevicesRequest;
  }

  @override
  void update(void Function(ListTrustedDevicesRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ListTrustedDevicesRequest build() => _build();

  _$ListTrustedDevicesRequest _build() {
    final _$result =
        _$v ??
        _$ListTrustedDevicesRequest._(
          status: status,
          pageIndex: pageIndex,
          pageSize: pageSize,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
