import 'package:adhan_dart/adhan_dart.dart' as adhan;

import 'quran_models.dart';
import 'reciter.dart';

enum AppThemeMode {
  system,
  light,
  dark;

  static AppThemeMode fromStorage(String? value) => AppThemeMode.values
      .firstWhere((e) => e.name == value, orElse: () => AppThemeMode.system);
}

/// Prayer-time calculation methods exposed in settings. The identifiers map
/// onto the pure-Dart `adhan_dart` library — no paid service is involved.
///
/// [egyptian] is the default: this app's audience is Egyptian, and it is the
/// calendar Al-Azhar and the Ministry of Awqaf actually publish. See
/// [PrayerTimesService] for how it is pinned to the published table.
enum PrayerCalculationMethod {
  muslimWorldLeague,
  egyptian,
  karachi,
  ummAlQura,
  dubai,
  moonSightingCommittee,
  northAmerica,
  kuwait,
  qatar,
  singapore,
  turkey,
  tehran;

  String get labelKey => 'settings.method.$name';

  /// The library's parameters for this method.
  ///
  /// `adhan_dart` exposes the presets as factories on
  /// [adhan.CalculationMethodParameters] rather than as values on the
  /// [adhan.CalculationMethod] enum, and every call returns a fresh, mutable
  /// [adhan.CalculationParameters] — so callers may adjust the result without
  /// affecting any other calculation.
  adhan.CalculationParameters get adhanParameters => switch (this) {
    PrayerCalculationMethod.muslimWorldLeague =>
      adhan.CalculationMethodParameters.muslimWorldLeague(),
    PrayerCalculationMethod.egyptian =>
      adhan.CalculationMethodParameters.egyptian(),
    PrayerCalculationMethod.karachi =>
      adhan.CalculationMethodParameters.karachi(),
    PrayerCalculationMethod.ummAlQura =>
      adhan.CalculationMethodParameters.ummAlQura(),
    PrayerCalculationMethod.dubai => adhan.CalculationMethodParameters.dubai(),
    PrayerCalculationMethod.moonSightingCommittee =>
      adhan.CalculationMethodParameters.moonsightingCommittee(),
    PrayerCalculationMethod.northAmerica =>
      adhan.CalculationMethodParameters.northAmerica(),
    PrayerCalculationMethod.kuwait =>
      adhan.CalculationMethodParameters.kuwait(),
    PrayerCalculationMethod.qatar => adhan.CalculationMethodParameters.qatar(),
    PrayerCalculationMethod.singapore =>
      adhan.CalculationMethodParameters.singapore(),
    PrayerCalculationMethod.turkey =>
      adhan.CalculationMethodParameters.turkiye(),
    PrayerCalculationMethod.tehran =>
      adhan.CalculationMethodParameters.tehran(),
  };

  static PrayerCalculationMethod fromStorage(String? value) =>
      PrayerCalculationMethod.values.firstWhere(
        (e) => e.name == value,
        orElse: () => PrayerCalculationMethod.egyptian,
      );
}

enum AsrMadhab {
  standard,
  hanafi;

  /// Shadow-length factor for Asr: 1 (Shafi) or 2 (Hanafi).
  adhan.Madhab get adhanMadhab => this == AsrMadhab.hanafi
      ? adhan.Madhab.hanafi
      : adhan.Madhab.shafi;

  static AsrMadhab fromStorage(String? value) => AsrMadhab.values.firstWhere(
    (e) => e.name == value,
    orElse: () => AsrMadhab.standard,
  );
}

enum HighLatitudeOption {
  none,
  middleOfTheNight,
  seventhOfTheNight,
  angleBased;

  String get labelKey => 'prayer.highLatitude${name[0].toUpperCase()}${name.substring(1)}';

  adhan.HighLatitudeRule? get adhanRule => switch (this) {
    HighLatitudeOption.none => null,
    HighLatitudeOption.middleOfTheNight =>
      adhan.HighLatitudeRule.middleOfTheNight,
    HighLatitudeOption.seventhOfTheNight =>
      adhan.HighLatitudeRule.seventhOfTheNight,
    HighLatitudeOption.angleBased => adhan.HighLatitudeRule.twilightAngle,
  };

  static HighLatitudeOption fromStorage(String? value) =>
      HighLatitudeOption.values.firstWhere(
        (e) => e.name == value,
        orElse: () => HighLatitudeOption.none,
      );
}

/// Where prayer times / Qibla coordinates come from.
class PrayerLocation {
  const PrayerLocation({
    required this.useDeviceLocation,
    this.latitude,
    this.longitude,
    this.cityName,
  });

  final bool useDeviceLocation;
  final double? latitude;
  final double? longitude;
  final String? cityName;

  bool get hasCoordinates =>
      latitude != null &&
      longitude != null &&
      latitude!.isFinite &&
      longitude!.isFinite &&
      latitude!.abs() <= 90 &&
      longitude!.abs() <= 180;

  /// True when we have enough information to compute prayer times.
  bool get isUsable => hasCoordinates;

  PrayerLocation copyWith({
    bool? useDeviceLocation,
    double? latitude,
    double? longitude,
    String? cityName,
    bool clearCity = false,
  }) => PrayerLocation(
    useDeviceLocation: useDeviceLocation ?? this.useDeviceLocation,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    cityName: clearCity ? null : (cityName ?? this.cityName),
  );

  /// Validates coordinates, returning `null` when they are out of range.
  static String? validateCoordinates(String latitude, String longitude) {
    final lat = double.tryParse(latitude.trim());
    final lng = double.tryParse(longitude.trim());
    if (lat == null || lng == null) return 'invalid';
    if (lat.abs() > 90 || lng.abs() > 180) return 'invalid';
    return null;
  }
}

class AppSettings {
  const AppSettings({
    this.themeMode = AppThemeMode.system,
    this.localeCode = 'ar',
    this.quranDisplayMode = QuranDisplayMode.text,
    this.quranFontScale = 1.0,
    this.mushafTajweed = true,
    this.calculationMethod = PrayerCalculationMethod.egyptian,
    this.asrMadhab = AsrMadhab.standard,
    this.highLatitude = HighLatitudeOption.none,
    this.prayerNotifications = false,
    this.morningReminder = false,
    this.eveningReminder = false,
    this.reminderHour = 6,
    this.reminderMinute = 30,
    this.location = const PrayerLocation(useDeviceLocation: true),
    this.tasbeehVibration = true,
    this.keepScreenAwake = false,
    this.reciterId = QuranReciters.defaultReciterId,
    this.dailyWirdPages = 0,
  });

  final AppThemeMode themeMode;
  final String localeCode;
  final QuranDisplayMode quranDisplayMode;

  /// 0.85 – 1.6 multiplier applied to the text-reading font size.
  final double quranFontScale;

  /// Whether the Mushaf page is drawn with Uthmani Tajweed colours.
  ///
  /// Off means a single ink colour for the whole page, which some readers
  /// prefer; the letters themselves are identical either way.
  final bool mushafTajweed;
  final PrayerCalculationMethod calculationMethod;
  final AsrMadhab asrMadhab;
  final HighLatitudeOption highLatitude;
  final bool prayerNotifications;
  final bool morningReminder;
  final bool eveningReminder;
  final int reminderHour;
  final int reminderMinute;
  final PrayerLocation location;
  final bool tasbeehVibration;
  final bool keepScreenAwake;

  /// Identifier of the reciter used for Qur'an audio playback. Always resolves
  /// to a verified catalogue entry via [reciter].
  final String reciterId;

  /// How many Mushaf pages the user wants to read per day. `0` means no wird
  /// has been set, and the home screen simply shows the reading position.
  ///
  /// Deliberately a plain page count rather than a juz/hizb fraction: the
  /// Mushaf reader counts pages, so the target and the progress it drives are
  /// measured in the same unit and can never disagree.
  final int dailyWirdPages;

  /// True when the user has set a daily portion.
  bool get hasDailyWird => dailyWirdPages > 0;

  /// The resolved reciter, guaranteed to be one the CDN actually serves.
  QuranReciter get reciter => QuranReciters.byId(reciterId);

  bool get isArabic => localeCode != 'en';

  AppSettings copyWith({
    AppThemeMode? themeMode,
    String? localeCode,
    QuranDisplayMode? quranDisplayMode,
    double? quranFontScale,
    bool? mushafTajweed,
    PrayerCalculationMethod? calculationMethod,
    AsrMadhab? asrMadhab,
    HighLatitudeOption? highLatitude,
    bool? prayerNotifications,
    bool? morningReminder,
    bool? eveningReminder,
    int? reminderHour,
    int? reminderMinute,
    PrayerLocation? location,
    bool? tasbeehVibration,
    bool? keepScreenAwake,
    String? reciterId,
    int? dailyWirdPages,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    localeCode: localeCode ?? this.localeCode,
    quranDisplayMode: quranDisplayMode ?? this.quranDisplayMode,
    quranFontScale: quranFontScale ?? this.quranFontScale,
    mushafTajweed: mushafTajweed ?? this.mushafTajweed,
    calculationMethod: calculationMethod ?? this.calculationMethod,
    asrMadhab: asrMadhab ?? this.asrMadhab,
    highLatitude: highLatitude ?? this.highLatitude,
    prayerNotifications: prayerNotifications ?? this.prayerNotifications,
    morningReminder: morningReminder ?? this.morningReminder,
    eveningReminder: eveningReminder ?? this.eveningReminder,
    reminderHour: reminderHour ?? this.reminderHour,
    reminderMinute: reminderMinute ?? this.reminderMinute,
    location: location ?? this.location,
    tasbeehVibration: tasbeehVibration ?? this.tasbeehVibration,
    keepScreenAwake: keepScreenAwake ?? this.keepScreenAwake,
    reciterId: reciterId ?? this.reciterId,
    dailyWirdPages: dailyWirdPages ?? this.dailyWirdPages,
  );
}

/// Result of resolving the user's coordinates, including the reason for failure
/// so the UI can render a helpful state instead of a blank screen.
enum LocationStatus {
  ok,
  permissionDenied,
  permissionDeniedForever,
  serviceDisabled,
  unavailable,
  notConfigured,
}

class ResolvedLocation {
  const ResolvedLocation({
    required this.status,
    this.latitude,
    this.longitude,
    this.cityName,
    this.message,
  });

  final LocationStatus status;
  final double? latitude;
  final double? longitude;
  final String? cityName;
  final String? message;

  bool get isOk =>
      status == LocationStatus.ok && latitude != null && longitude != null;

  static const ResolvedLocation notConfigured = ResolvedLocation(
    status: LocationStatus.notConfigured,
  );
}
