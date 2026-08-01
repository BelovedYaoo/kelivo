import 'durable_shared_preferences_store.dart';

final class DurableSharedPreferencesEraser {
  const DurableSharedPreferencesEraser({this.store});

  final DurableSharedPreferencesStore? store;

  Future<void> eraseAll() async {
    final durableStore =
        store ?? PlatformDurableSharedPreferencesStore.forCurrentPlatform();
    final existing = await durableStore.readRawKeys();

    for (final key in existing) {
      await durableStore.remove(key);
    }

    final remaining = await durableStore.readRawKeys();
    if (remaining.isNotEmpty) {
      throw StateError('shared_preferences_wipe_incomplete');
    }
  }
}
