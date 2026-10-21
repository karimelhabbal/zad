import 'package:adhan_dart/adhan_dart.dart' as adhan;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zad/data/models/settings_models.dart';
import 'package:zad/data/repositories/local_store.dart';
import 'package:zad/data/repositories/settings_repository.dart';
import 'package:zad/data/services/prayer_times_service.dart';

/// Prayer times are computed with the pure-Dart `adhan_dart` implementation.
/// These tests lock in the contract the UI depends on.
void main() {
  const service = PrayerTimesService();

  // Cairo, Egypt.
  const latitude = 30.0444;
  const longitude = 31.2357;

  AppSettings settingsWith({
    PrayerCalculationMethod method = PrayerCalculationMethod.ummAlQura,
    AsrMadhab madhab = AsrMadhab.standard,
    HighLatitudeOption highLatitude = HighLatitudeOption.none,
  }) => AppSettings(
    calculationMethod: method,
    asrMadhab: madhab,
    highLatitude: highLatitude,
  );

  test('produces all six daily milestones in chronological order', () {
    final schedule = service.compute(
      latitude: latitude,
      longitude: longitude,
      settings: settingsWith(),
      date: DateTime(2024, 3, 20),
    );

    expect(schedule, isNotNull);
    expect(schedule!.times.length, 6);

    final ordered = <PrayerSlot>[
      PrayerSlot.fajr,
      PrayerSlot.sunrise,
      PrayerSlot.dhuhr,
      PrayerSlot.asr,
      PrayerSlot.maghrib,
      PrayerSlot.isha,
    ];
    for (var i = 1; i < ordered.length; i++) {
      final previous = schedule.timeOf(ordered[i - 1])!;
      final current = schedule.timeOf(ordered[i])!;
      expect(
        current.isAfter(previous),
        isTrue,
        reason: '${ordered[i]} must follow ${ordered[i - 1]}',
      );
    }
  });

  test('morning milestones land in the expected hours for Cairo', () {
    final schedule = service.compute(
      latitude: latitude,
      longitude: longitude,
      settings: settingsWith(),
      date: DateTime(2024, 6, 21),
    )!;

    // Late June in Cairo: Fajr before 4am, Dhuhr around midday.
    expect(schedule.timeOf(PrayerSlot.fajr)!.hour, lessThan(5));
    expect(schedule.timeOf(PrayerSlot.dhuhr)!.hour, inInclusiveRange(11, 13));
    expect(schedule.timeOf(PrayerSlot.isha)!.hour, inInclusiveRange(19, 23));
  });

  test('the next prayer is always in the future', () {
    final schedule = service.compute(
      latitude: latitude,
      longitude: longitude,
      settings: settingsWith(),
    )!;
    expect(schedule.nextTime, isNotNull);
    expect(schedule.nextTime!.isAfter(DateTime.now()), isTrue);
  });

  test('the Hanafi Asr comes after the standard Asr', () {
    final date = DateTime(2024, 3, 20);
    final standard = service.compute(
      latitude: latitude,
      longitude: longitude,
      settings: settingsWith(madhab: AsrMadhab.standard),
      date: date,
    )!;
    final hanafi = service.compute(
      latitude: latitude,
      longitude: longitude,
      settings: settingsWith(madhab: AsrMadhab.hanafi),
      date: date,
    )!;

    expect(
      hanafi.timeOf(PrayerSlot.asr)!.isAfter(standard.timeOf(PrayerSlot.asr)!),
      isTrue,
    );
  });

  test('the calculation method changes the Fajr time', () {
    final date = DateTime(2024, 3, 20);
    final ummAlQura = service.compute(
      latitude: latitude,
      longitude: longitude,
      settings: settingsWith(method: PrayerCalculationMethod.ummAlQura),
      date: date,
    )!;
    final karachi = service.compute(
      latitude: latitude,
      longitude: longitude,
      settings: settingsWith(method: PrayerCalculationMethod.karachi),
      date: date,
    )!;

    expect(
      ummAlQura.timeOf(PrayerSlot.fajr),
      isNot(equals(karachi.timeOf(PrayerSlot.fajr))),
    );
  });

  test('a high-latitude city still yields a usable schedule', () {
    final schedule = service.compute(
      latitude: 59.9139, // Oslo
      longitude: 10.7522,
      settings: settingsWith(highLatitude: HighLatitudeOption.angleBased),
      date: DateTime(2024, 6, 21),
    );
    expect(schedule, isNotNull);
    expect(schedule!.times.length, 6);
  });

  test('invalid coordinates are rejected instead of producing fake times', () {
    expect(
      service.compute(
        latitude: 120,
        longitude: longitude,
        settings: settingsWith(),
      ),
      isNull,
    );
    expect(
      service.compute(
        latitude: latitude,
        longitude: 200,
        settings: settingsWith(),
      ),
      isNull,
    );
    expect(
      service.compute(
        latitude: double.nan,
        longitude: longitude,
        settings: settingsWith(),
      ),
      isNull,
    );
  });

  test('remaining() never goes negative', () {
    final schedule = service.compute(
      latitude: latitude,
      longitude: longitude,
      settings: settingsWith(),
    )!;
    expect(schedule.remaining(DateTime(2000))!.isNegative, isFalse);
    final farFuture = schedule.nextTime!.add(const Duration(days: 1));
    expect(schedule.remaining(farFuture), Duration.zero);
  });

  test('progress() stays inside 0..1', () {
    final schedule = service.compute(
      latitude: latitude,
      longitude: longitude,
      settings: settingsWith(),
    )!;
    expect(schedule.progress(DateTime(2000)), 0.0);
    expect(schedule.progress(DateTime(2100)), 1.0);
  });

  test('tomorrowFajr is after today and non-null', () {
    final tomorrow = service.tomorrowFajr(
      latitude: latitude,
      longitude: longitude,
      settings: settingsWith(),
    );
    expect(tomorrow, isNotNull);
    expect(tomorrow!.isAfter(DateTime.now()), isTrue);
  });

  test('PrayerSlot metadata is consistent', () {
    expect(PrayerSlot.sunrise.isObligatory, isFalse);
    expect(PrayerSlot.fajr.isObligatory, isTrue);
    expect(PrayerSlot.maghrib.labelKey, 'prayer.maghrib');
  });

  group('the Egyptian method matches the published calendar', () {
    // The General Authority of Survey's own table for 2026-05-19 (EEST, UTC+3),
    // reproduced from its daily bulletin. Compared as UTC instants so the test
    // does not depend on the timezone of the machine running it.
    // `tool/verify_prayer_times.dart` carries the full eight-city table.
    const published = <(String, double, double, Map<PrayerSlot, (int, int)>)>[
      (
        'Cairo',
        30.0444,
        31.2357,
        <PrayerSlot, (int, int)>{
          PrayerSlot.fajr: (4, 19),
          PrayerSlot.sunrise: (5, 59),
          PrayerSlot.dhuhr: (12, 51),
          PrayerSlot.asr: (16, 28),
          PrayerSlot.maghrib: (19, 44),
          PrayerSlot.isha: (21, 13),
        },
      ),
      (
        'Alexandria',
        31.2001,
        29.9187,
        <PrayerSlot, (int, int)>{
          PrayerSlot.fajr: (4, 20),
          PrayerSlot.sunrise: (6, 2),
          PrayerSlot.dhuhr: (12, 57),
          PrayerSlot.asr: (16, 36),
          PrayerSlot.maghrib: (19, 52),
          PrayerSlot.isha: (21, 22),
        },
      ),
      (
        'Aswan',
        24.0889,
        32.8998,
        <PrayerSlot, (int, int)>{
          PrayerSlot.fajr: (4, 32),
          PrayerSlot.sunrise: (6, 4),
          PrayerSlot.dhuhr: (12, 45),
          PrayerSlot.asr: (16, 8),
          PrayerSlot.maghrib: (19, 26),
          PrayerSlot.isha: (20, 48),
        },
      ),
    ];

    for (final (name, lat, lng, times) in published) {
      test('$name is within a minute of the authority, Dhuhr included', () {
        final schedule = service.compute(
          latitude: lat,
          longitude: lng,
          settings: settingsWith(method: PrayerCalculationMethod.egyptian),
          date: DateTime(2026, 5, 19),
        );
        expect(schedule, isNotNull);

        for (final entry in times.entries) {
          final expected = DateTime.utc(
            2026,
            5,
            19,
            entry.value.$1,
            entry.value.$2,
          ).subtract(const Duration(hours: 3));
          final delta = schedule!
              .timeOf(entry.key)!
              .toUtc()
              .difference(expected)
              .inMinutes
              .abs();
          expect(
            delta,
            lessThanOrEqualTo(1),
            reason: '${entry.key} disagrees with the published table for $name',
          );
        }
      });
    }

    test('Dhuhr is the transit, without the extra precautionary minute', () {
      // The Egyptian preset carries `methodAdjustments[Prayer.dhuhr] = 1`. The
      // authority prints the plain transit, so the service cancels it; if that
      // cancellation is ever dropped, every city lands 1-2 minutes late.
      final params = service.parametersFor(
        settingsWith(method: PrayerCalculationMethod.egyptian),
      );
      expect(
        (params.adjustments[adhan.Prayer.dhuhr] ?? 0) +
            (params.methodAdjustments[adhan.Prayer.dhuhr] ?? 0),
        0,
        reason: 'the method precaution must cancel out',
      );
      // Other methods keep whatever their own preset specifies.
      final karachi = service.parametersFor(
        settingsWith(method: PrayerCalculationMethod.karachi),
      );
      expect(karachi.adjustments[adhan.Prayer.dhuhr] ?? 0, 0);
    });

    test('the Egyptian method is the app default', () {
      expect(
        const AppSettings().calculationMethod,
        PrayerCalculationMethod.egyptian,
      );
    });
  });

  group('the calculation-method migration', () {
    late LocalStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      LocalStore.overrideInstance(null);
      store = await LocalStore.instance();
    });

    test('a stored legacy default is corrected to the Egyptian method', () async {
      // What the previous build wrote for every user who never opened the
      // method picker.
      await store.setJson(LocalStore.keySettings, <String, dynamic>{
        'calculationMethod': 'ummAlQura',
      });
      expect(
        SettingsRepository(store).load().calculationMethod,
        PrayerCalculationMethod.egyptian,
      );
    });

    test('a deliberately chosen method survives the migration', () async {
      await store.setJson(LocalStore.keySettings, <String, dynamic>{
        'calculationMethod': 'turkey',
      });
      expect(
        SettingsRepository(store).load().calculationMethod,
        PrayerCalculationMethod.turkey,
      );
    });

    test('choosing Umm al-Qura after the migration is respected', () async {
      // Once the document carries the current revision, a stored Umm al-Qura is
      // a real user choice and must not be migrated away again.
      await store.setJson(LocalStore.keySettings, <String, dynamic>{
        'revision': SettingsRepository.currentRevision,
        'calculationMethod': 'ummAlQura',
      });
      expect(
        SettingsRepository(store).load().calculationMethod,
        PrayerCalculationMethod.ummAlQura,
      );
    });

    test('a saved document is stamped with the current revision', () async {
      await SettingsRepository(store).save(const AppSettings());
      final raw = store.getJsonObject(LocalStore.keySettings)!;
      expect(raw['revision'], SettingsRepository.currentRevision);
      expect(raw['calculationMethod'], 'egyptian');
    });
  });
}
