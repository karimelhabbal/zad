// Prints today's five prayer times for Mansoura (31.0409 N, 31.3785 E) using
// the app's real settings path, so the numbers can be held against the
// Egyptian General Authority of Survey timetable.
//
// Run with:
//   dart --disable-dart-dev --packages=.dart_tool/package_config.json \
//       tool/print_mansoura_times.dart
//
// Times are printed twice: as local wall clock (what the app displays) and as
// the UTC instant (what the authority's printed minute corresponds to once its
// own offset is removed), so the comparison does not depend on the time zone
// of the machine running this.
// ignore_for_file: avoid_print

import 'package:zad/data/models/settings_models.dart';
import 'package:zad/data/services/prayer_times_service.dart';

void main() {
  const latitude = 31.0409; // Mansoura
  const longitude = 31.3785;

  // Exactly what an Egyptian user gets: Egyptian General Authority of Survey,
  // Shafi shadow factor for Asr, no high-latitude rule (Egypt never needs one).
  const settings = AppSettings(
    calculationMethod: PrayerCalculationMethod.egyptian,
    asrMadhab: AsrMadhab.standard,
    highLatitude: HighLatitudeOption.none,
  );

  final schedule = const PrayerTimesService().compute(
    latitude: latitude,
    longitude: longitude,
    settings: settings,
  );

  if (schedule == null) {
    print('Calculation failed for $latitude, $longitude');
    return;
  }

  String two(int value) => value.toString().padLeft(2, '0');
  String clock(DateTime t) => '${two(t.hour)}:${two(t.minute)}';

  print('Mansoura  $latitude, $longitude');
  print('date: ${schedule.date.year}-${two(schedule.date.month)}-'
      '${two(schedule.date.day)}');
  print('method: egyptian (Fajr 19.5°, Isha 17.5°) | asr: shafi (factor 1)');
  print('device time zone offset: ${DateTime.now().timeZoneOffset}');
  print('');
  print('prayer     local   UTC');
  print('---------  -----   -----');

  const labels = <PrayerSlot, String>{
    PrayerSlot.fajr: 'Fajr',
    PrayerSlot.sunrise: 'Sunrise',
    PrayerSlot.dhuhr: 'Dhuhr',
    PrayerSlot.asr: 'Asr',
    PrayerSlot.maghrib: 'Maghrib',
    PrayerSlot.isha: 'Isha',
  };

  for (final slot in <PrayerSlot>[
    PrayerSlot.fajr,
    PrayerSlot.sunrise,
    PrayerSlot.dhuhr,
    PrayerSlot.asr,
    PrayerSlot.maghrib,
    PrayerSlot.isha,
  ]) {
    final time = schedule.timeOf(slot);
    if (time == null) {
      print('${labels[slot]!.padRight(9)}  missing');
      continue;
    }
    print('${labels[slot]!.padRight(9)}  ${clock(time)}   ${clock(time.toUtc())}');
  }

  print('');
  print('current: ${schedule.current?.name ?? '—'}  '
      'next: ${schedule.next?.name ?? '—'} at '
      '${schedule.nextTime == null ? '—' : clock(schedule.nextTime!)}');
}
