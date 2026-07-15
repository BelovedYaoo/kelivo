// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'system_health_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const SystemHealthDataServiceEnum _$systemHealthDataServiceEnum_kelivoApi =
    const SystemHealthDataServiceEnum._('kelivoApi');

SystemHealthDataServiceEnum _$systemHealthDataServiceEnumValueOf(String name) {
  switch (name) {
    case 'kelivoApi':
      return _$systemHealthDataServiceEnum_kelivoApi;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<SystemHealthDataServiceEnum>
_$systemHealthDataServiceEnumValues = BuiltSet<SystemHealthDataServiceEnum>(
  const <SystemHealthDataServiceEnum>[_$systemHealthDataServiceEnum_kelivoApi],
);

const SystemHealthDataStatusEnum _$systemHealthDataStatusEnum_ok =
    const SystemHealthDataStatusEnum._('ok');

SystemHealthDataStatusEnum _$systemHealthDataStatusEnumValueOf(String name) {
  switch (name) {
    case 'ok':
      return _$systemHealthDataStatusEnum_ok;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<SystemHealthDataStatusEnum> _$systemHealthDataStatusEnumValues =
    BuiltSet<SystemHealthDataStatusEnum>(const <SystemHealthDataStatusEnum>[
      _$systemHealthDataStatusEnum_ok,
    ]);

Serializer<SystemHealthDataServiceEnum>
_$systemHealthDataServiceEnumSerializer =
    _$SystemHealthDataServiceEnumSerializer();
Serializer<SystemHealthDataStatusEnum> _$systemHealthDataStatusEnumSerializer =
    _$SystemHealthDataStatusEnumSerializer();

class _$SystemHealthDataServiceEnumSerializer
    implements PrimitiveSerializer<SystemHealthDataServiceEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'kelivoApi': 'kelivo-api',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'kelivo-api': 'kelivoApi',
  };

  @override
  final Iterable<Type> types = const <Type>[SystemHealthDataServiceEnum];
  @override
  final String wireName = 'SystemHealthDataServiceEnum';

  @override
  Object serialize(
    Serializers serializers,
    SystemHealthDataServiceEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  SystemHealthDataServiceEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => SystemHealthDataServiceEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$SystemHealthDataStatusEnumSerializer
    implements PrimitiveSerializer<SystemHealthDataStatusEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{'ok': 'ok'};
  static const Map<Object, String> _fromWire = const <Object, String>{
    'ok': 'ok',
  };

  @override
  final Iterable<Type> types = const <Type>[SystemHealthDataStatusEnum];
  @override
  final String wireName = 'SystemHealthDataStatusEnum';

  @override
  Object serialize(
    Serializers serializers,
    SystemHealthDataStatusEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  SystemHealthDataStatusEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => SystemHealthDataStatusEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$SystemHealthData extends SystemHealthData {
  @override
  final SystemHealthDataServiceEnum service;
  @override
  final SystemHealthDataStatusEnum status;
  @override
  final DateTime timestamp;

  factory _$SystemHealthData([
    void Function(SystemHealthDataBuilder)? updates,
  ]) => (SystemHealthDataBuilder()..update(updates))._build();

  _$SystemHealthData._({
    required this.service,
    required this.status,
    required this.timestamp,
  }) : super._();
  @override
  SystemHealthData rebuild(void Function(SystemHealthDataBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  SystemHealthDataBuilder toBuilder() =>
      SystemHealthDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SystemHealthData &&
        service == other.service &&
        status == other.status &&
        timestamp == other.timestamp;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, service.hashCode);
    _$hash = $jc(_$hash, status.hashCode);
    _$hash = $jc(_$hash, timestamp.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'SystemHealthData')
          ..add('service', service)
          ..add('status', status)
          ..add('timestamp', timestamp))
        .toString();
  }
}

class SystemHealthDataBuilder
    implements Builder<SystemHealthData, SystemHealthDataBuilder> {
  _$SystemHealthData? _$v;

  SystemHealthDataServiceEnum? _service;
  SystemHealthDataServiceEnum? get service => _$this._service;
  set service(SystemHealthDataServiceEnum? service) =>
      _$this._service = service;

  SystemHealthDataStatusEnum? _status;
  SystemHealthDataStatusEnum? get status => _$this._status;
  set status(SystemHealthDataStatusEnum? status) => _$this._status = status;

  DateTime? _timestamp;
  DateTime? get timestamp => _$this._timestamp;
  set timestamp(DateTime? timestamp) => _$this._timestamp = timestamp;

  SystemHealthDataBuilder() {
    SystemHealthData._defaults(this);
  }

  SystemHealthDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _service = $v.service;
      _status = $v.status;
      _timestamp = $v.timestamp;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SystemHealthData other) {
    _$v = other as _$SystemHealthData;
  }

  @override
  void update(void Function(SystemHealthDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SystemHealthData build() => _build();

  _$SystemHealthData _build() {
    final _$result =
        _$v ??
        _$SystemHealthData._(
          service: BuiltValueNullFieldError.checkNotNull(
            service,
            r'SystemHealthData',
            'service',
          ),
          status: BuiltValueNullFieldError.checkNotNull(
            status,
            r'SystemHealthData',
            'status',
          ),
          timestamp: BuiltValueNullFieldError.checkNotNull(
            timestamp,
            r'SystemHealthData',
            'timestamp',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
