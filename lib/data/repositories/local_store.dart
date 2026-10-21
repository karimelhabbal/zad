import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Thin, defensive wrapper around [SharedPreferences].
///
/// Everything the user creates is stored **locally on the device** — there is
/// no backend and no account. Reads never throw: a corrupt or outdated value
/// is reported as `null` so callers can fall back to a safe default instead of
/// losing unrelated data.
class LocalStore {
  LocalStore._(this._prefs);

  final SharedPreferences _prefs;

  static const String keySettings = 'zad.settings.v1';
  static const String keyReadingPosition = 'zad.quran.position.v1';
  static const String keyBookmarks = 'zad.quran.bookmarks.v1';

  /// Distinct Mushaf pages opened today (`{d: yyyy-mm-dd, p: [page, ...]}`).
  static const String keyPagesToday = 'zad.quran.pagesToday.v1';
  static const String keyCustomDhikr = 'zad.tasbeeh.custom.v1';
  static const String keyTasbeehCounters = 'zad.tasbeeh.counters.v1';
  static const String keyActiveDhikr = 'zad.tasbeeh.active.v1';
  static const String keyAzkarProgress = 'zad.azkar.progress.v1';
  static const String keyTasbeehStats = 'zad.tasbeeh.stats.v1';
  static const String keyTasbeehTargets = 'zad.tasbeeh.targets.v1';

  /// Whether the first-run tour has been completed (or skipped) once.
  static const String keyOnboardingSeen = 'zad.onboarding.seen.v1';

  /// Selected Qur'an reciter for audio playback (a `QuranReciters` id).
  static const String keyAudioReciter = 'zad.audio.reciter.v1';

  static LocalStore? _instance;

  static Future<LocalStore> instance() async {
    return _instance ??= LocalStore._(await SharedPreferences.getInstance());
  }

  /// Test/DI hook.
  static void overrideInstance(LocalStore? store) => _instance = store;

  SharedPreferences get raw => _prefs;

  String? getString(String key) => _prefs.getString(key);

  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  bool getBool(String key, {bool fallback = false}) =>
      _prefs.getBool(key) ?? fallback;

  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);

  double? getDouble(String key) => _prefs.getDouble(key);

  Future<void> setDouble(String key, double value) =>
      _prefs.setDouble(key, value);

  int? getInt(String key) => _prefs.getInt(key);

  Future<void> setInt(String key, int value) => _prefs.setInt(key, value);

  Future<void> remove(String key) => _prefs.remove(key);

  /// Decodes a JSON object, returning `null` when the stored value is missing,
  /// empty or malformed.
  Map<String, dynamic>? getJsonObject(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  List<dynamic>? getJsonList(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is List ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> setJson(String key, Object value) =>
      _prefs.setString(key, jsonEncode(value));

  /// Keys owned by Zad — used by the "reset app data" action.
  static const List<String> allKeys = <String>[
    keySettings,
    keyReadingPosition,
    keyBookmarks,
    keyPagesToday,
    keyCustomDhikr,
    keyTasbeehCounters,
    keyActiveDhikr,
    keyAzkarProgress,
    keyTasbeehStats,
    keyTasbeehTargets,
    keyOnboardingSeen,
    keyAudioReciter,
  ];

  /// Clears only Zad-owned keys, leaving any unrelated preference intact.
  Future<void> clearAppData() async {
    for (final key in allKeys) {
      await _prefs.remove(key);
    }
  }
}
