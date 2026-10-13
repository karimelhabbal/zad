import '../models/settings_models.dart';
import '../models/quran_models.dart';
import '../models/reciter.dart';
import 'local_store.dart';

/// Loads and persists [AppSettings] as a single versioned JSON document.
///
/// A single document (rather than many loose keys) keeps migrations simple and
/// means a partially written value can never leave settings half-applied.
class SettingsRepository {
  SettingsRepository(this._store);

  final LocalStore _store;

  /// Bumped whenever a stored *default* changes in a way that must reach
  /// existing installs. See [_calculationMethod].
  static const int currentRevision = 2;

  /// The method name that was this app's default before [currentRevision] 2.
  static const String _legacyDefaultMethod = 'ummAlQura';

  AppSettings load() {
    final json = _store.getJsonObject(LocalStore.keySettings);
    if (json == null) return const AppSettings();
    try {
      final revision = json['revision'] as int? ?? 1;
      return AppSettings(
        themeMode: AppThemeMode.fromStorage(json['themeMode'] as String?),
        localeCode: _locale(json['localeCode'] as String?),
        quranDisplayMode: QuranDisplayMode.fromStorage(
          json['quranDisplayMode'] as String?,
        ),
        quranFontScale: _fontScale(json['quranFontScale']),
        mushafPageTreatment: MushafPageTreatment.fromStorage(
          json['mushafPageTreatment'] as String?,
        ),
        calculationMethod: _calculationMethod(
          json['calculationMethod'] as String?,
          revision,
        ),
        asrMadhab: AsrMadhab.fromStorage(json['asrMadhab'] as String?),
        highLatitude: HighLatitudeOption.fromStorage(
          json['highLatitude'] as String?,
        ),
        prayerNotifications: json['prayerNotifications'] as bool? ?? false,
        morningReminder: json['morningReminder'] as bool? ?? false,
        eveningReminder: json['eveningReminder'] as bool? ?? false,
        reminderHour: _clampInt(json['reminderHour'], 0, 23, 6),
        reminderMinute: _clampInt(json['reminderMinute'], 0, 59, 30),
        location: _location(json['location']),
        tasbeehVibration: json['tasbeehVibration'] as bool? ?? true,
        keepScreenAwake: json['keepScreenAwake'] as bool? ?? false,
        // A stored reciter that is no longer in the verified catalogue falls
        // back to the default rather than producing a dead play button.
        reciterId: QuranReciters.isVerified(json['reciterId'] as String?)
            ? json['reciterId'] as String
            : QuranReciters.defaultReciterId,
      );
    } catch (_) {
      // Outdated / malformed payload — fall back to defaults instead of
      // crashing on startup.
      return const AppSettings();
    }
  }

  Future<void> save(AppSettings settings) => _store.setJson(
    LocalStore.keySettings,
    <String, dynamic>{
      'revision': currentRevision,
      'themeMode': settings.themeMode.name,
      'localeCode': settings.localeCode,
      'quranDisplayMode': settings.quranDisplayMode.name,
      'quranFontScale': settings.quranFontScale,
      'mushafPageTreatment': settings.mushafPageTreatment.name,
      'calculationMethod': settings.calculationMethod.name,
      'asrMadhab': settings.asrMadhab.name,
      'highLatitude': settings.highLatitude.name,
      'prayerNotifications': settings.prayerNotifications,
      'morningReminder': settings.morningReminder,
      'eveningReminder': settings.eveningReminder,
      'reminderHour': settings.reminderHour,
      'reminderMinute': settings.reminderMinute,
      'location': <String, dynamic>{
        'useDeviceLocation': settings.location.useDeviceLocation,
        'latitude': settings.location.latitude,
        'longitude': settings.location.longitude,
        'cityName': settings.location.cityName,
      },
      'tasbeehVibration': settings.tasbeehVibration,
      'keepScreenAwake': settings.keepScreenAwake,
      'reciterId': settings.reciterId,
    },
  );

  static String _locale(String? value) => value == 'en' ? 'en' : 'ar';

  /// Resolves the stored calculation method, applying the revision-2 migration.
  ///
  /// Before revision 2 the app defaulted to Umm al-Qura, which is simply the
  /// wrong calendar for the audience this app is built for: an Egyptian user's
  /// mosque announces the General Authority of Survey's times. A stored value
  /// equal to the *old default* is therefore treated as "never explicitly
  /// chosen" and corrected once. Any other stored method is a deliberate
  /// choice and is left alone.
  static PrayerCalculationMethod _calculationMethod(
    String? stored,
    int revision,
  ) {
    if (revision < currentRevision && stored == _legacyDefaultMethod) {
      return PrayerCalculationMethod.egyptian;
    }
    return PrayerCalculationMethod.fromStorage(stored);
  }

  static double _fontScale(Object? value) {
    final parsed = value is num ? value.toDouble() : 1.0;
    return parsed.clamp(0.8, 1.8);
  }

  static int _clampInt(Object? value, int min, int max, int fallback) {
    if (value is! int) return fallback;
    return value.clamp(min, max);
  }

  static PrayerLocation _location(Object? value) {
    if (value is! Map<String, dynamic>) {
      return const PrayerLocation(useDeviceLocation: true);
    }
    final lat = (value['latitude'] as num?)?.toDouble();
    final lng = (value['longitude'] as num?)?.toDouble();
    return PrayerLocation(
      useDeviceLocation: value['useDeviceLocation'] as bool? ?? true,
      latitude: lat,
      longitude: lng,
      cityName: value['cityName'] as String?,
    );
  }
}
