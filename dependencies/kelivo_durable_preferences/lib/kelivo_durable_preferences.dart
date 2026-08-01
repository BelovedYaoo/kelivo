import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

final class KelivoDurablePreferences extends SharedPreferencesStorePlatform {
  KelivoDurablePreferences({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'kelivo.durable_preferences';
  static const _defaultPrefix = 'flutter.';

  final MethodChannel _channel;

  static Future<void> registerForCurrentPlatform() async {
    if (!Platform.isIOS && !Platform.isMacOS) return;

    final store = KelivoDurablePreferences();
    await store.initialize();
    SharedPreferencesStorePlatform.instance = store;
  }

  Future<void> initialize() => _invokeMutation('initialize');

  @override
  Future<bool> clear() => clearWithParameters(
    ClearParameters(filter: PreferencesFilter(prefix: _defaultPrefix)),
  );

  @override
  Future<bool> clearWithPrefix(String prefix) => clearWithParameters(
    ClearParameters(filter: PreferencesFilter(prefix: prefix)),
  );

  @override
  Future<bool> clearWithParameters(ClearParameters parameters) async {
    await _invokeMutation(
      'clear',
      arguments: _filterArguments(parameters.filter),
    );
    return true;
  }

  @override
  Future<Map<String, Object>> getAll() => getAllWithParameters(
    GetAllParameters(filter: PreferencesFilter(prefix: _defaultPrefix)),
  );

  @override
  Future<Map<String, Object>> getAllWithPrefix(String prefix) =>
      getAllWithParameters(
        GetAllParameters(filter: PreferencesFilter(prefix: prefix)),
      );

  @override
  Future<Map<String, Object>> getAllWithParameters(
    GetAllParameters parameters,
  ) async {
    final raw = await _channel.invokeMethod<Object?>(
      'get-all',
      _filterArguments(parameters.filter),
    );
    if (raw is! Map<Object?, Object?>) {
      throw StateError('kelivo_durable_preferences_invalid_snapshot');
    }

    final values = <String, Object>{};
    for (final entry in raw.entries) {
      final key = entry.key;
      final value = _validatedValue(entry.value);
      if (key is! String || value == null) {
        throw StateError('kelivo_durable_preferences_invalid_snapshot');
      }
      values[key] = value;
    }
    return values;
  }

  @override
  Future<bool> remove(String key) async {
    await _invokeMutation('remove', arguments: <String, Object>{'key': key});
    return true;
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (!_matchesValueType(valueType, value)) {
      throw ArgumentError.value(
        value,
        'value',
        'kelivo_durable_preferences_invalid_value',
      );
    }
    await _invokeMutation(
      'set-value',
      arguments: <String, Object>{
        'key': key,
        'valueType': valueType,
        'value': value,
      },
    );
    return true;
  }

  Future<void> _invokeMutation(
    String method, {
    Map<String, Object>? arguments,
  }) async {
    final response = await _channel.invokeMethod<Object?>(method, arguments);
    if (response != null) {
      throw StateError('kelivo_durable_preferences_invalid_receipt');
    }
  }

  static Map<String, Object> _filterArguments(PreferencesFilter filter) {
    final arguments = <String, Object>{'prefix': filter.prefix};
    final allowList = filter.allowList;
    if (allowList != null) {
      arguments['allowList'] = allowList.toList()..sort();
    }
    return arguments;
  }

  static Object? _validatedValue(Object? value) {
    if (value is bool || value is int || value is double || value is String) {
      return value;
    }
    if (value is List<Object?> && value.every((item) => item is String)) {
      return List<String>.unmodifiable(value.cast<String>());
    }
    return null;
  }

  static bool _matchesValueType(String valueType, Object value) {
    return switch (valueType) {
      'Bool' => value is bool,
      'Double' => value is double,
      'Int' => value is int,
      'String' => value is String,
      'StringList' => value is List<String>,
      _ => false,
    };
  }
}
