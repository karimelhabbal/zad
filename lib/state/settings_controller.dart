import 'package:flutter/material.dart';

import '../data/models/quran_models.dart';
import '../data/models/reciter.dart';
import '../data/models/settings_models.dart';
import '../data/repositories/local_store.dart';
import '../data/repositories/settings_repository.dart';

/// Owns the persisted application settings: theme, language, Quran reading
/// preferences, prayer-time calculation and notification toggles.
class SettingsController extends ChangeNotifier {
  SettingsController(this._store) : _repository = SettingsRepository(_store) {
    _settings = _repository.load();
  }

  final LocalStore _store;
  final SettingsRepository _repository;

  late AppSettings _settings;

  AppSettings get settings => _settings;

  ThemeMode get themeMode => switch (_settings.themeMode) {
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
    AppThemeMode.system => ThemeMode.system,
  };

  Locale get locale => Locale(_settings.localeCode);

  bool get isArabic => _settings.isArabic;

  Future<void> _apply(AppSettings next) async {
    _settings = next;
    notifyListeners();
    await _repository.save(next);
  }

  Future<void> setThemeMode(AppThemeMode mode) =>
      _apply(_settings.copyWith(themeMode: mode));

  Future<void> setLocale(String code) =>
      _apply(_settings.copyWith(localeCode: code == 'en' ? 'en' : 'ar'));

  Future<void> toggleLocale() =>
      setLocale(_settings.isArabic ? 'en' : 'ar');

  Future<void> setQuranDisplayMode(QuranDisplayMode mode) =>
      _apply(_settings.copyWith(quranDisplayMode: mode));

  Future<void> setQuranFontScale(double scale) =>
      _apply(_settings.copyWith(quranFontScale: scale.clamp(0.8, 1.8)));

  Future<void> setMushafTajweed(bool value) =>
      _apply(_settings.copyWith(mushafTajweed: value));

  Future<void> setCalculationMethod(PrayerCalculationMethod method) =>
      _apply(_settings.copyWith(calculationMethod: method));

  Future<void> setAsrMadhab(AsrMadhab madhab) =>
      _apply(_settings.copyWith(asrMadhab: madhab));

  Future<void> setHighLatitude(HighLatitudeOption option) =>
      _apply(_settings.copyWith(highLatitude: option));

  Future<void> setPrayerNotifications(bool value) =>
      _apply(_settings.copyWith(prayerNotifications: value));

  Future<void> setMorningReminder(bool value) =>
      _apply(_settings.copyWith(morningReminder: value));

  Future<void> setEveningReminder(bool value) =>
      _apply(_settings.copyWith(eveningReminder: value));

  Future<void> setReminderTime(int hour, int minute) => _apply(
    _settings.copyWith(
      reminderHour: hour.clamp(0, 23),
      reminderMinute: minute.clamp(0, 59),
    ),
  );

  Future<void> setUseDeviceLocation(bool value) => _apply(
    _settings.copyWith(
      location: _settings.location.copyWith(useDeviceLocation: value),
    ),
  );

  Future<void> setManualLocation({
    required double latitude,
    required double longitude,
    String? cityName,
  }) => _apply(
    _settings.copyWith(
      location: PrayerLocation(
        useDeviceLocation: false,
        latitude: latitude,
        longitude: longitude,
        cityName: cityName,
      ),
    ),
  );

  Future<void> setTasbeehVibration(bool value) =>
      _apply(_settings.copyWith(tasbeehVibration: value));

  Future<void> setKeepScreenAwake(bool value) =>
      _apply(_settings.copyWith(keepScreenAwake: value));

  /// Sets the daily Qur'an portion in pages. `0` clears it.
  Future<void> setDailyWirdPages(int pages) =>
      _apply(_settings.copyWith(dailyWirdPages: pages.clamp(0, 604)));

  /// The reciter used for Qur'an audio. Only verified catalogue ids are
  /// accepted, so playback can never be pointed at an edition the CDN rejects.
  QuranReciter get reciter => _settings.reciter;

  Future<void> setReciter(QuranReciter reciter) {
    if (!QuranReciters.isVerified(reciter.id)) return Future<void>.value();
    return _apply(_settings.copyWith(reciterId: reciter.id));
  }

  /// Clears every Zad-owned preference and local record.
  Future<void> resetAppData() async {
    await _store.clearAppData();
    _settings = const AppSettings();
    notifyListeners();
  }
}
