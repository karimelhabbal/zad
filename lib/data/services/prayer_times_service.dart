import 'package:adhan/adhan.dart' as adhan;

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

  static PrayerSlot? fromAdhan(adhan.Prayer prayer) => switch (prayer) {
    adhan.Prayer.fajr => PrayerSlot.fajr,
    adhan.Prayer.sunrise => PrayerSlot.sunrise,
    adhan.Prayer.dhuhr => PrayerSlot.dhuhr,
    adhan.Prayer.asr => PrayerSlot.asr,
    adhan.Prayer.maghrib => PrayerSlot.maghrib,
    adhan.Prayer.isha => PrayerSlot.isha,
    adhan.Prayer.none => null,
  };
}

/// A computed prayer schedule for one calendar day at one location.
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

/// Computes real prayer times with the pure-Dart `adhan` library — a verified
/// astronomical implementation, so no paid API is required.
class PrayerTimesService {
  const PrayerTimesService();

  /// Builds the adhan parameters from the user's settings.
  adhan.CalculationParameters parametersFor(AppSettings settings) {
    final params = settings.calculationMethod.adhanMethod.getParameters();
    params.madhab = settings.asrMadhab.adhanMadhab;

    if (settings.calculationMethod == PrayerCalculationMethod.egyptian) {
      // **Dhuhr.** `adhan`'s Egyptian preset carries a one-minute precaution on
      // Dhuhr (`methodAdjustments.dhuhr = 1`). The Egyptian General Authority
      // of Survey publishes the plain astronomical transit instead, and that
      // extra minute is the whole of the disagreement: with it, all eight
      // cities in `tool/verify_prayer_times.dart` land 1-2 minutes late; with
      // it cancelled, seven of the eight match the published table exactly and
      // Cairo is one minute out. Cancelling a *method* adjustment is not the
      // same as inventing an offset — it restores the raw transit the authority
      // prints, so it is expressed that way rather than as a magic -1.
      params.adjustments = adhan.PrayerAdjustments(
        dhuhr: -params.methodAdjustments.dhuhr,
      );
    }

    var rule = settings.highLatitude.adhanRule;
    if (rule != null) {
      // The angle-based rule is defined in terms of the Fajr and Isha *angles*.
      // Some methods (Umm al-Qura, for example) define Isha as a fixed interval
      // after Maghrib and therefore carry no Isha angle at all; `adhan` throws
      // rather than guessing in that case. Fall back to the seventh-of-the-night
      // rule, which is well defined for every method, so a user who selects this
      // combination still gets real times instead of an error screen.
      if (rule == adhan.HighLatitudeRule.twilight_angle &&
          params.ishaAngle == null) {
        rule = adhan.HighLatitudeRule.seventh_of_the_night;
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
        coordinates,
        adhan.DateComponents.from(target),
        params,
      );
      final times = <PrayerSlot, DateTime>{
        PrayerSlot.fajr: today.fajr,
        PrayerSlot.sunrise: today.sunrise,
        PrayerSlot.dhuhr: today.dhuhr,
        PrayerSlot.asr: today.asr,
        PrayerSlot.maghrib: today.maghrib,
        PrayerSlot.isha: today.isha,
      };

      final now = DateTime.now();
      final isToday = _sameDay(target, now);
      final reference = isToday ? now : target;

      var next = PrayerSlot.fromAdhan(today.nextPrayerByDateTime(reference));
      var nextTime = next == null ? null : times[next];

      // After Isha the adhan library reports `none`; the next prayer is
      // tomorrow's Fajr, so compute it explicitly.
      if (nextTime == null || nextTime.isBefore(reference)) {
        final tomorrow = adhan.PrayerTimes(
          coordinates,
          adhan.DateComponents.from(
            DateTime(target.year, target.month, target.day + 1),
          ),
          params,
        );
        next = PrayerSlot.fajr;
        nextTime = tomorrow.fajr;
      }

      final current = PrayerSlot.fromAdhan(today.currentPrayerByDateTime(reference));

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
