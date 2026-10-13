// Verifies the app's prayer times against the times actually published in
// Egypt by the General Authority of Survey (الهيئة العامة للمساحة) — the body
// whose calendar Al-Azhar and the Ministry of Awqaf publish.
//
// The app is generic, but an Egyptian user judges it against that calendar, and
// "close enough" is not good enough for a prayer time: a method that is four
// minutes out on Fajr is a different method. This tool therefore pins the real
// `PrayerTimesService` to real published values and fails if they drift.
//
// Comparison is done on **UTC instants**, never on local wall-clock time, so the
// result does not depend on the timezone of the machine running the check. The
// published table is in Egyptian summer time (EEST, UTC+3) on 2026-05-19.
//
// Run with:
//   dart --disable-dart-dev --packages=.dart_tool/package_config.json \
//       tool/verify_prayer_times.dart
//
// Exits 1 when any prayer is outside the tolerance.

import 'dart:io';

import 'package:zad/data/models/settings_models.dart';
import 'package:zad/data/services/prayer_times_service.dart';

/// The offset the published table is expressed in.
const Duration _publishedOffset = Duration(hours: 3);

/// How far a computed time may differ before it is a real disagreement. The
/// authority rounds to the minute, so one minute is rounding, not an error.
const int _toleranceMinutes = 1;

/// The date the published table is for.
const (int, int, int) _publishedDate = (2026, 5, 19);

class PublishedCity {
  const PublishedCity({
    required this.name,
    required this.nameAr,
    required this.latitude,
    required this.longitude,
    required this.times,
  });

  final String name;
  final String nameAr;
  final double latitude;
  final double longitude;

  /// Fajr, sunrise, Dhuhr, Asr, Maghrib, Isha — local clock time (HH:MM).
  final Map<PrayerSlot, (int, int)> times;
}

/// Transcribed from the General Authority of Survey bulletin for 2026-05-19,
/// covering the whole length of the country (Alexandria 31.2°N to Aswan 24.1°N).
const List<PublishedCity> _published = <PublishedCity>[
  PublishedCity(
    name: 'Cairo',
    nameAr: 'القاهرة',
    latitude: 30.0444,
    longitude: 31.2357,
    times: <PrayerSlot, (int, int)>{
      PrayerSlot.fajr: (4, 19),
      PrayerSlot.sunrise: (5, 59),
      PrayerSlot.dhuhr: (12, 51),
      PrayerSlot.asr: (16, 28),
      PrayerSlot.maghrib: (19, 44),
      PrayerSlot.isha: (21, 13),
    },
  ),
  PublishedCity(
    name: 'Giza',
    nameAr: 'الجيزة',
    latitude: 30.0131,
    longitude: 31.2089,
    times: <PrayerSlot, (int, int)>{
      PrayerSlot.fajr: (4, 19),
      PrayerSlot.sunrise: (6, 00),
      PrayerSlot.dhuhr: (12, 52),
      PrayerSlot.asr: (16, 28),
      PrayerSlot.maghrib: (19, 44),
      PrayerSlot.isha: (21, 13),
    },
  ),
  PublishedCity(
    name: 'Alexandria',
    nameAr: 'الإسكندرية',
    latitude: 31.2001,
    longitude: 29.9187,
    times: <PrayerSlot, (int, int)>{
      PrayerSlot.fajr: (4, 20),
      PrayerSlot.sunrise: (6, 02),
      PrayerSlot.dhuhr: (12, 57),
      PrayerSlot.asr: (16, 36),
      PrayerSlot.maghrib: (19, 52),
      PrayerSlot.isha: (21, 22),
    },
  ),
  PublishedCity(
    name: 'Port Said',
    nameAr: 'بورسعيد',
    latitude: 31.2653,
    longitude: 32.3019,
    times: <PrayerSlot, (int, int)>{
      PrayerSlot.fajr: (4, 10),
      PrayerSlot.sunrise: (5, 53),
      PrayerSlot.dhuhr: (12, 47),
      PrayerSlot.asr: (16, 27),
      PrayerSlot.maghrib: (19, 42),
      PrayerSlot.isha: (21, 13),
    },
  ),
  PublishedCity(
    name: 'Sharm El-Sheikh',
    nameAr: 'شرم الشيخ',
    latitude: 27.9158,
    longitude: 34.3300,
    times: <PrayerSlot, (int, int)>{
      PrayerSlot.fajr: (4, 14),
      PrayerSlot.sunrise: (5, 51),
      PrayerSlot.dhuhr: (12, 39),
      PrayerSlot.asr: (16, 11),
      PrayerSlot.maghrib: (19, 28),
      PrayerSlot.isha: (20, 54),
    },
  ),
  PublishedCity(
    name: 'Hurghada',
    nameAr: 'الغردقة',
    latitude: 27.2579,
    longitude: 33.8116,
    times: <PrayerSlot, (int, int)>{
      PrayerSlot.fajr: (4, 19),
      PrayerSlot.sunrise: (5, 55),
      PrayerSlot.dhuhr: (12, 41),
      PrayerSlot.asr: (16, 12),
      PrayerSlot.maghrib: (19, 28),
      PrayerSlot.isha: (20, 53),
    },
  ),
  PublishedCity(
    name: 'Luxor',
    nameAr: 'الأقصر',
    latitude: 25.6872,
    longitude: 32.6396,
    times: <PrayerSlot, (int, int)>{
      PrayerSlot.fajr: (4, 28),
      PrayerSlot.sunrise: (6, 02),
      PrayerSlot.dhuhr: (12, 46),
      PrayerSlot.asr: (16, 13),
      PrayerSlot.maghrib: (19, 30),
      PrayerSlot.isha: (20, 54),
    },
  ),
  PublishedCity(
    name: 'Aswan',
    nameAr: 'أسوان',
    latitude: 24.0889,
    longitude: 32.8998,
    times: <PrayerSlot, (int, int)>{
      PrayerSlot.fajr: (4, 32),
      PrayerSlot.sunrise: (6, 04),
      PrayerSlot.dhuhr: (12, 45),
      PrayerSlot.asr: (16, 08),
      PrayerSlot.maghrib: (19, 26),
      PrayerSlot.isha: (20, 48),
    },
  ),
];

const Map<PrayerSlot, String> _labels = <PrayerSlot, String>{
  PrayerSlot.fajr: 'Fajr',
  PrayerSlot.sunrise: 'Sunrise',
  PrayerSlot.dhuhr: 'Dhuhr',
  PrayerSlot.asr: 'Asr',
  PrayerSlot.maghrib: 'Maghrib',
  PrayerSlot.isha: 'Isha',
};

String _hhmm(DateTime utc) {
  final local = utc.toUtc().add(_publishedOffset);
  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

DateTime _expectedUtc((int, int) hhmm) => DateTime.utc(
      _publishedDate.$1,
      _publishedDate.$2,
      _publishedDate.$3,
      hhmm.$1,
      hhmm.$2,
    ).subtract(_publishedOffset);

void main() {
  const service = PrayerTimesService();

  // The Egyptian General Authority of Survey method with the Shafi'i shadow
  // length — what Egyptian mosques work to. `highLatitude: none` because Egypt
  // never gets near the latitudes where a twilight rule is needed, and applying
  // one there would silently bend Fajr and Isha.
  const settings = AppSettings(
    calculationMethod: PrayerCalculationMethod.egyptian,
    asrMadhab: AsrMadhab.standard,
    highLatitude: HighLatitudeOption.none,
  );

  final hostOffset = DateTime.now().timeZoneOffset;
  stdout.writeln('== Prayer times vs the Egyptian General Authority of Survey ==');
  stdout.writeln('published date: ${_publishedDate.$1}-'
      '${_publishedDate.$2.toString().padLeft(2, '0')}-'
      '${_publishedDate.$3.toString().padLeft(2, '0')} (EEST, UTC+3)');
  stdout.writeln('method: egyptian | madhab: shafi | high latitude: none');
  stdout.writeln('host timezone offset: $hostOffset (irrelevant: UTC instants compared)');
  stdout.writeln('');

  var checks = 0;
  var failures = 0;
  final worst = <String, int>{};

  for (final city in _published) {
    final schedule = service.compute(
      latitude: city.latitude,
      longitude: city.longitude,
      settings: settings,
      date: DateTime(_publishedDate.$1, _publishedDate.$2, _publishedDate.$3),
    );

    if (schedule == null) {
      stdout.writeln('${city.nameAr} (${city.name}): COMPUTE FAILED');
      failures++;
      continue;
    }

    stdout.writeln('${city.nameAr} (${city.name})  '
        '${city.latitude.toStringAsFixed(2)}, ${city.longitude.toStringAsFixed(2)}');
    for (final entry in city.times.entries) {
      final slot = entry.key;
      final computed = schedule.times[slot];
      if (computed == null) {
        stdout.writeln('  ${_labels[slot]}: MISSING');
        failures++;
        continue;
      }
      final label = _labels[slot]!;
      final expected = _expectedUtc(entry.value);
      final delta = computed.toUtc().difference(expected).inMinutes;
      final abs = delta.abs();
      checks++;
      if (abs > _toleranceMinutes) failures++;
      if (abs > (worst[label] ?? -1)) worst[label] = abs;
      final mark = abs <= _toleranceMinutes ? 'ok ' : 'BAD';
      stdout.writeln('  $mark ${label.padRight(7)} '
          'published ${_hhmm(expected)}  computed ${_hhmm(computed.toUtc())}  '
          'delta ${delta >= 0 ? '+' : ''}${delta}m');
    }
    stdout.writeln('');
  }

  stdout.writeln('worst absolute delta per prayer (minutes): '
      '${_labels.values.map((l) => '$l=${worst[l] ?? '-'}').join(', ')}');
  stdout.writeln('');
  stdout.writeln('checks: $checks  failures: $failures');

  if (failures == 0) {
    stdout.writeln('RESULT: computed times match the published Egyptian calendar '
        'within ±$_toleranceMinutes minute.');
  } else {
    stdout.writeln('RESULT: $failures value(s) outside ±$_toleranceMinutes minute.');
  }
  // Non-zero exit so this can gate a commit.
  if (failures != 0) {
    throw StateError('prayer times disagree with the published calendar');
  }
}
