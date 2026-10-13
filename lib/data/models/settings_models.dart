import 'package:adhan/adhan.dart' as adhan;

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
/// onto the pure-Dart `adhan` library — no paid service is involved.
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

  adhan.CalculationMethod get adhanMethod => switch (this) {
    PrayerCalculationMethod.muslimWorldLeague =>
      adhan.CalculationMethod.muslim_world_league,
    PrayerCalculationMethod.egyptian => adhan.CalculationMethod.egyptian,
    PrayerCalculationMethod.karachi => adhan.CalculationMethod.karachi,
    PrayerCalculationMethod.ummAlQura => adhan.CalculationMethod.umm_al_qura,
    PrayerCalculationMethod.dubai => adhan.CalculationMethod.dubai,
    PrayerCalculationMethod.moonSightingCommittee =>
      adhan.CalculationMethod.moon_sighting_committee,
    PrayerCalculationMethod.northAmerica =>
      adhan.CalculationMethod.north_america,
    PrayerCalculationMethod.kuwait => adhan.CalculationMethod.kuwait,
    PrayerCalculationMethod.qatar => adhan.CalculationMethod.qatar,
    PrayerCalculationMethod.singapore => adhan.CalculationMethod.singapore,
    PrayerCalculationMethod.turkey => adhan.CalculationMethod.turkey,
    PrayerCalculationMethod.tehran => adhan.CalculationMethod.tehran,
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
      adhan.HighLatitudeRule.middle_of_the_night,
    HighLatitudeOption.seventhOfTheNight =>
      adhan.HighLatitudeRule.seventh_of_the_night,
    HighLatitudeOption.angleBased => adhan.HighLatitudeRule.twilight_angle,
  };

  static HighLatitudeOption fromStorage(String? value) =>
      HighLatitudeOption.values.firstWhere(
        (e) => e.name == value,
        orElse: () => HighLatitudeOption.none,
      );
}

/// How a Mushaf page photograph is treated for display.
///
/// Every page is a photograph of white paper with black ink. That is exactly
/// what you want in daylight, and a torch in the face at night — which is why
/// a Mushaf reader needs a decision here rather than a single rendering.
enum MushafPageTreatment {
  /// Follow the theme: as printed in light mode, inverted in dark mode.
  auto,

  /// Always the photograph as printed — white paper, black ink.
  asPrinted,

  /// Keep the paper white but dim it, like reading under a low lamp.
  dim,

  /// Invert the page — dark paper, light ink. The only option that does not
  /// light up an OLED screen, and the gentlest on the eyes at night.
  invert;

  String get labelKey => 'quran.treatment.$name';

  /// The treatment actually applied for a given theme brightness.
  MushafPageTreatment resolve({required bool isDark}) {
    if (this != MushafPageTreatment.auto) return this;
    return isDark ? MushafPageTreatment.invert : MushafPageTreatment.asPrinted;
  }

  static MushafPageTreatment fromStorage(String? value) =>
      MushafPageTreatment.values.firstWhere(
        (e) => e.name == value,
        orElse: () => MushafPageTreatment.auto,
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
    this.mushafPageTreatment = MushafPageTreatment.auto,
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
  });

  final AppThemeMode themeMode;
  final String localeCode;
  final QuranDisplayMode quranDisplayMode;

  /// 0.85 – 1.6 multiplier applied to the text-reading font size.
  final double quranFontScale;

  /// How the Mushaf page photograph is rendered — see [MushafPageTreatment].
  final MushafPageTreatment mushafPageTreatment;
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

  /// The resolved reciter, guaranteed to be one the CDN actually serves.
  QuranReciter get reciter => QuranReciters.byId(reciterId);

  bool get isArabic => localeCode != 'en';

  AppSettings copyWith({
    AppThemeMode? themeMode,
    String? localeCode,
    QuranDisplayMode? quranDisplayMode,
    double? quranFontScale,
    MushafPageTreatment? mushafPageTreatment,
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
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    localeCode: localeCode ?? this.localeCode,
    quranDisplayMode: quranDisplayMode ?? this.quranDisplayMode,
    quranFontScale: quranFontScale ?? this.quranFontScale,
    mushafPageTreatment: mushafPageTreatment ?? this.mushafPageTreatment,
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
