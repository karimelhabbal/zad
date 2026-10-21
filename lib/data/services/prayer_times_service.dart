import 'package:adhan_dart/adhan_dart.dart' as adhan;

import '../models/settings_models.dart';

/// The five daily prayers plus sunrise (used as a display milestone).
enum PrayerSlot {
  fajr,
  sunrise,
  dhuhr,
  asr,
  maghrib,
  isha;

  bool get isObligatory => this != PrayerSlot.sunrise;

  String get labelKey => 'prayer.$name';

  /// Maps a library [adhan.Prayer] onto a slot of this schedule.
  ///
  /// `adhan_dart` also reports the neighbouring days' Isha and Fajr
  /// (`ishaBefore`, `fajrAfter`); those are the same two prayers, so they map
  /// onto the same slots. Their *times* must be read from the matching fields
  /// rather than from this day's map — see [PrayerTimesService.compute].
  static PrayerSlot fromAdhan(adhan.Prayer prayer) => switch (prayer) {
    adhan.Prayer.fajr => PrayerSlot.fajr,
    adhan.Prayer.sunrise => PrayerSlot.sunrise,
    adhan.Prayer.dhuhr => PrayerSlot.dhuhr,
    adhan.Prayer.asr => PrayerSlot.asr,
    adhan.Prayer.maghrib => PrayerSlot.maghrib,
    adhan.Prayer.isha => PrayerSlot.isha,
    adhan.Prayer.ishaBefore => PrayerSlot.isha,
    adhan.Prayer.fajrAfter => PrayerSlot.fajr,
  };
}

/// A computed prayer schedule for one calendar day at one location.
///
/// Every [DateTime] in [times] is in the **device's local time zone**: the
/// library returns UTC instants and the service converts them once, on the way
/// out, so nothing downstream has to think about time zones.
class PrayerSchedule {
  const PrayerSchedule({
    required this.times,
    required this.current,
    required this.next,
    required this.nextTime,
    required this.date,
  });

  final Map<PrayerSlot, DateTime> times;

  /// Prayer whose window is currently active (may be null before Fajr).
  final PrayerSlot? current;

  /// Next upcoming prayer — rolls over to tomorrow's Fajr after Isha.
  final PrayerSlot? next;
  final DateTime? nextTime;

  /// The date this schedule was computed for.
  final DateTime date;

  DateTime? timeOf(PrayerSlot slot) => times[slot];

  bool get isEmpty => times.isEmpty;

  Duration? remaining(DateTime now) {
    final target = nextTime;
    if (target == null) return null;
    final delta = target.difference(now);
    return delta.isNegative ? Duration.zero : delta;
  }

  /// Progress through the day's prayer milestones (0..1), used by the home
  /// dashboard arc.
  double progress(DateTime now) {
    if (times.isEmpty) return 0;
    final fajr = times[PrayerSlot.fajr];
    final isha = times[PrayerSlot.isha];
    if (fajr == null || isha == null) return 0;
    final span = isha.difference(fajr).inSeconds;
    if (span <= 0) return 0;
    final elapsed = now.difference(fajr).inSeconds;
    return (elapsed / span).clamp(0.0, 1.0);
  }
}

/// Computes real prayer times with the pure-Dart `adhan_dart` library — a
/// verified astronomical implementation, so no paid API is required.
///
/// **Time zones.** `adhan_dart` returns every time as a UTC [DateTime]
/// (`DateTime.utc(...)`), unlike its predecessor, which returned the device's
/// wall clock directly. Each time is therefore converted with [DateTime.toLocal]
/// exactly once, here. `toLocal` applies the operating system's time-zone
/// rules, so Egypt's daylight-saving transitions (EEST, UTC+3, in force since
/// 2023) are handled by the platform's own tz database — no time-zone package
/// and no manual offset is needed, and the conversion is correct for any
/// location the user picks, not only for Cairo.
class PrayerTimesService {
  const PrayerTimesService();

  /// Builds the calculation parameters from the user's settings.
  adhan.CalculationParameters parametersFor(AppSettings settings) {
    final params = settings.calculationMethod.adhanParameters;

    // Asr shadow factor, set explicitly: 1 for the Shafi madhab (the app's
    // default) and 2 for Hanafi. The library's default happens to be Shafi,
    // but relying on that would make the Asr time depend on a default we do
    // not control.
    params.madhab = settings.asrMadhab.adhanMadhab;

    if (settings.calculationMethod == PrayerCalculationMethod.egyptian) {
      // **Dhuhr.** The Egyptian preset carries a one-minute precaution on
      // Dhuhr (`methodAdjustments[Prayer.dhuhr] = 1`). The Egyptian General
      // Authority of Survey publishes the plain astronomical transit instead,
      // and that extra minute is the whole of the disagreement: with it, all
      // eight cities in `tool/verify_prayer_times.dart` land 1-2 minutes late;
      // with it cancelled, seven of the eight match the published table exactly
      // and Cairo is one minute out. Cancelling a *method* adjustment is not
      // the same as inventing an offset — it restores the raw transit the
      // authority prints, so it is expressed that way rather than as a magic -1.
      params.adjustments = <adhan.Prayer, int>{
        ...params.adjustments,
        adhan.Prayer.dhuhr:
            -(params.methodAdjustments[adhan.Prayer.dhuhr] ?? 0),
      };
    }

    var rule = settings.highLatitude.adhanRule;
    if (rule != null) {
      // The angle-based rule is defined in terms of the Fajr and Isha *angles*.
      // Some methods (Umm al-Qura, for example) define Isha as a fixed interval
      // after Maghrib and therefore carry no Isha angle at all (the field is
      // 0); the library would then treat Isha as sunset. Fall back to the
      // seventh-of-the-night rule, which is well defined for every method, so a
      // user who selects this combination still gets real times instead of an
      // error screen.
      if (rule == adhan.HighLatitudeRule.twilightAngle &&
          params.ishaAngle <= 0) {
        rule = adhan.HighLatitudeRule.seventhOfTheNight;
      }
      params.highLatitudeRule = rule;
    }
    return params;
  }

  /// Computes the schedule for [date] at the given coordinates.
  ///
  /// Returns `null` when the coordinates are not valid.
  PrayerSchedule? compute({
    required double latitude,
    required double longitude,
    required AppSettings settings,
    DateTime? date,
  }) {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude.abs() > 90 ||
        longitude.abs() > 180) {
      return null;
    }
    final target = date ?? DateTime.now();
    final coordinates = adhan.Coordinates(latitude, longitude);
    final params = parametersFor(settings);

    try {
      final today = adhan.PrayerTimes(
        // Anchored at local noon: only the calendar date is used by the
        // astronomy, and noon can never be shifted onto a neighbouring date by
        // a daylight-saving step the way a midnight anchor can.
        date: DateTime(target.year, target.month, target.day, 12),
        coordinates: coordinates,
        calculationParameters: params,
      );

      final times = <PrayerSlot, DateTime>{
        PrayerSlot.fajr: today.fajr.toLocal(),
        PrayerSlot.sunrise: today.sunrise.toLocal(),
        PrayerSlot.dhuhr: today.dhuhr.toLocal(),
        PrayerSlot.asr: today.asr.toLocal(),
        PrayerSlot.maghrib: today.maghrib.toLocal(),
        PrayerSlot.isha: today.isha.toLocal(),
      };

      final now = DateTime.now();
      final isToday = _sameDay(target, now);
      final reference = isToday ? now : target;
      // The library compares instants, so handing it a UTC reference keeps the
      // comparison unambiguous whichever zone the device is set to.
      final referenceUtc = reference.toUtc();

      // After Isha the library reports tomorrow's Fajr (`fajrAfter`); before
      // Fajr it reports yesterday's Isha (`ishaBefore`). Both are reported with
      // their real time rather than as "none", so the rollover is explicit.
      final nextPrayer = today.nextPrayer(date: referenceUtc);
      final next = PrayerSlot.fromAdhan(nextPrayer);
      final nextTime = switch (nextPrayer) {
        adhan.Prayer.fajrAfter => today.fajrAfter.toLocal(),
        adhan.Prayer.ishaBefore => today.ishaBefore.toLocal(),
        _ => times[next],
      };

      // Before Fajr the library calls the active window yesterday's Isha. The
      // app has always shown no "current" prayer at that hour, and that is what
      // the home dashboard expects, so keep it.
      final currentPrayer = today.currentPrayer(date: referenceUtc);
      final current = currentPrayer == adhan.Prayer.ishaBefore
          ? null
          : PrayerSlot.fromAdhan(currentPrayer);

      return PrayerSchedule(
        times: times,
        current: current,
        next: next,
        nextTime: nextTime,
        date: DateTime(target.year, target.month, target.day),
      );
    } catch (_) {
      return null;
    }
  }

  /// Convenience helper for the home dashboard: tomorrow's Fajr time.
  DateTime? tomorrowFajr({
    required double latitude,
    required double longitude,
    required AppSettings settings,
  }) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final schedule = compute(
      latitude: latitude,
      longitude: longitude,
      settings: settings,
      date: tomorrow,
    );
    return schedule?.times[PrayerSlot.fajr];
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
