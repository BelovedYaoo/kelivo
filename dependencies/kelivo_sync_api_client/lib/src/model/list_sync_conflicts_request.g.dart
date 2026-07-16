// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_sync_conflicts_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const ListSyncConflictsRequestStateEnum
_$listSyncConflictsRequestStateEnum_open =
    const ListSyncConflictsRequestStateEnum._('open');
const ListSyncConflictsRequestStateEnum
_$listSyncConflictsRequestStateEnum_resolved =
    const ListSyncConflictsRequestStateEnum._('resolved');

ListSyncConflictsRequestStateEnum _$listSyncConflictsRequestStateEnumValueOf(
  String name,
) {
  switch (name) {
    case 'open':
      return _$listSyncConflictsRequestStateEnum_open;
    case 'resolved':
      return _$listSyncConflictsRequestStateEnum_resolved;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<ListSyncConflictsRequestStateEnum>
_$listSyncConflictsRequestStateEnumValues =
    BuiltSet<ListSyncConflictsRequestStateEnum>(
      const <ListSyncConflictsRequestStateEnum>[
        _$listSyncConflictsRequestStateEnum_open,
        _$listSyncConflictsRequestStateEnum_resolved,
      ],
    );

Serializer<ListSyncConflictsRequestStateEnum>
_$listSyncConflictsRequestStateEnumSerializer =
    _$ListSyncConflictsRequestStateEnumSerializer();

class _$ListSyncConflictsRequestStateEnumSerializer
    implements PrimitiveSerializer<ListSyncConflictsRequestStateEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'open': 'open',
    'resolved': 'resolved',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'open': 'open',
    'resolved': 'resolved',
  };

  @override
  final Iterable<Type> types = const <Type>[ListSyncConflictsRequestStateEnum];
  @override
  final String wireName = 'ListSyncConflictsRequestStateEnum';

  @override
  Object serialize(
    Serializers serializers,
    ListSyncConflictsRequestStateEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  ListSyncConflictsRequestStateEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => ListSyncConflictsRequestStateEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$ListSyncConflictsRequest extends ListSyncConflictsRequest {
  @override
  final ListSyncConflictsRequestStateEnum? state;
  @override
  final int? limit;

  factory _$ListSyncConflictsRequest([
    void Function(ListSyncConflictsRequestBuilder)? updates,
  ]) => (ListSyncConflictsRequestBuilder()..update(updates))._build();

  _$ListSyncConflictsRequest._({this.state, this.limit}) : super._();
  @override
  ListSyncConflictsRequest rebuild(
    void Function(ListSyncConflictsRequestBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  ListSyncConflictsRequestBuilder toBuilder() =>
      ListSyncConflictsRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ListSyncConflictsRequest &&
        state == other.state &&
        limit == other.limit;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, state.hashCode);
    _$hash = $jc(_$hash, limit.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'ListSyncConflictsRequest')
          ..add('state', state)
          ..add('limit', limit))
        .toString();
  }
}

class ListSyncConflictsRequestBuilder
    implements
        Builder<ListSyncConflictsRequest, ListSyncConflictsRequestBuilder> {
  _$ListSyncConflictsRequest? _$v;

  ListSyncConflictsRequestStateEnum? _state;
  ListSyncConflictsRequestStateEnum? get state => _$this._state;
  set state(ListSyncConflictsRequestStateEnum? state) => _$this._state = state;

  int? _limit;
  int? get limit => _$this._limit;
  set limit(int? limit) => _$this._limit = limit;

  ListSyncConflictsRequestBuilder() {
    ListSyncConflictsRequest._defaults(this);
  }

  ListSyncConflictsRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _state = $v.state;
      _limit = $v.limit;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ListSyncConflictsRequest other) {
    _$v = other as _$ListSyncConflictsRequest;
  }

  @override
  void update(void Function(ListSyncConflictsRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ListSyncConflictsRequest build() => _build();

  _$ListSyncConflictsRequest _build() {
    final _$result =
        _$v ?? _$ListSyncConflictsRequest._(state: state, limit: limit);
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
