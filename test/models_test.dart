import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/data/models/azkar_models.dart';
import 'package:zad/data/models/quran_models.dart';
import 'package:zad/data/models/settings_models.dart';

/// Persisted models must survive round-trips and, crucially, must never throw
/// on corrupt or outdated payloads — a single bad record must not be able to
/// wipe the user's saved data.
void main() {
  group('ReadingPosition', () {
    test('round-trips through JSON', () {
      final original = ReadingPosition(
        surah: 18,
        ayah: 10,
        page: 293,
        juz: 15,
        mode: QuranDisplayMode.mushaf,
        updatedAt: DateTime(2025, 2, 3, 4, 5, 6),
      );
      final restored = ReadingPosition.tryParse(
        jsonEncode(original.toJson()),
      )!;
      expect(restored.surah, 18);
      expect(restored.ayah, 10);
      expect(restored.page, 293);
      expect(restored.juz, 15);
      expect(restored.mode, QuranDisplayMode.mushaf);
      expect(restored.updatedAt, original.updatedAt);
    });

    test('initial() is a neutral, unsaved position', () {
      final initial = ReadingPosition.initial();
      expect(initial.surah, 1);
      expect(initial.ayah, 1);
      expect(initial.page, 1);
      expect(initial.mode, QuranDisplayMode.text);
      expect(initial.updatedAt.millisecondsSinceEpoch, 0);
    });

    test('returns null for corrupt, empty or out-of-range payloads', () {
      expect(ReadingPosition.tryParse(null), isNull);
      expect(ReadingPosition.tryParse(''), isNull);
      expect(ReadingPosition.tryParse('not json'), isNull);
      expect(ReadingPosition.tryParse('[]'), isNull);
      expect(ReadingPosition.tryParse('{"surah":999}'), isNull);
      expect(ReadingPosition.tryParse('{"surah":0}'), isNull);
      expect(ReadingPosition.tryParse('{"surah":"x"}'), isNull);
    });

    test('tolerates a partial payload by filling safe defaults', () {
      final parsed = ReadingPosition.tryParse('{"surah":2}')!;
      expect(parsed.surah, 2);
      expect(parsed.ayah, 1);
      expect(parsed.page, 1);
      expect(parsed.juz, 1);
      expect(parsed.mode, QuranDisplayMode.text);
    });
  });

  group('QuranBookmark', () {
    test('round-trips and exposes a stable key', () {
      final bookmark = QuranBookmark(
        id: '2_255',
        surah: 2,
        ayah: 255,
        page: 42,
        juz: 3,
        createdAt: DateTime(2025, 1, 1),
      );
      expect(bookmark.key, '2:255');
      final restored = QuranBookmark.tryParse(bookmark.toJson())!;
      expect(restored.surah, 2);
      expect(restored.ayah, 255);
      expect(restored.page, 42);
      expect(restored.key, bookmark.key);
    });

    test('returns null for malformed records', () {
      expect(QuranBookmark.tryParse(<String, dynamic>{}), isNull);
      expect(
        QuranBookmark.tryParse(<String, dynamic>{'id': 'x', 'surah': 'two'}),
        isNull,
      );
    });
  });

  group('CustomDhikr', () {
    test('round-trips through JSON', () {
      final dhikr = CustomDhikr(
        id: 'dh_1',
        text: 'سُبْحَانَ اللَّهِ',
        target: 33,
        createdAt: DateTime(2025, 4, 4),
      );
      final restored = CustomDhikr.tryParse(dhikr.toJson())!;
      expect(restored.id, 'dh_1');
      expect(restored.text, 'سُبْحَانَ اللَّهِ');
      expect(restored.target, 33);
      expect(restored.createdAt, dhikr.createdAt);
    });

    test('copyWith preserves identity and creation time', () {
      final dhikr = CustomDhikr(
        id: 'dh_1',
        text: 'a',
        target: 33,
        createdAt: DateTime(2025, 4, 4),
      );
      final updated = dhikr.copyWith(text: 'b', target: 100);
      expect(updated.id, dhikr.id);
      expect(updated.createdAt, dhikr.createdAt);
      expect(updated.text, 'b');
      expect(updated.target, 100);
    });

    test('rejects malformed entries so one bad record cannot wipe the list', () {
      expect(CustomDhikr.tryParse(null), isNull);
      expect(CustomDhikr.tryParse('nope'), isNull);
      expect(
        CustomDhikr.tryParse(<String, dynamic>{'id': 'x', 'text': '  ', 'target': 33}),
        isNull,
      );
      expect(
        CustomDhikr.tryParse(<String, dynamic>{'id': 'x', 'text': 'ok', 'target': 0}),
        isNull,
      );
      expect(
        CustomDhikr.tryParse(<String, dynamic>{'id': 'x', 'text': 'ok', 'target': -5}),
        isNull,
      );
    });
  });

  group('ActiveDhikr', () {
    test('namespaces built-in and custom storage ids', () {
      const builtIn = ActiveDhikr(
        id: 'subhan',
        text: 'سُبْحَانَ اللَّهِ',
        target: 33,
        isCustom: false,
      );
      const custom = ActiveDhikr(
        id: 'dh_1',
        text: 'mine',
        target: 100,
        isCustom: true,
      );
      expect(builtIn.storageId, 'builtin:subhan');
      expect(custom.storageId, 'custom:dh_1');
      expect(builtIn.storageId == custom.storageId, isFalse);
    });
  });

  group('QuranDisplayMode', () {
    test('round-trips through storage', () {
      for (final mode in QuranDisplayMode.values) {
        expect(QuranDisplayMode.fromStorage(mode.storageKey), mode);
      }
      expect(QuranDisplayMode.fromStorage(null), QuranDisplayMode.text);
      expect(QuranDisplayMode.fromStorage('garbage'), QuranDisplayMode.text);
    });
  });

  group('settings enums', () {
    test('calculation methods round-trip and default to the Egyptian method', () {
      for (final method in PrayerCalculationMethod.values) {
        expect(PrayerCalculationMethod.fromStorage(method.name), method);
        expect(method.labelKey, 'settings.method.${method.name}');
      }
      // Egypt's own authority is the calendar this app is judged against.
      expect(
        PrayerCalculationMethod.fromStorage('nonsense'),
        PrayerCalculationMethod.egyptian,
      );
      expect(
        const AppSettings().calculationMethod,
        PrayerCalculationMethod.egyptian,
      );
    });

    test('high-latitude options expose matching label keys', () {
      expect(HighLatitudeOption.none.labelKey, 'prayer.highLatitudeNone');
      expect(
        HighLatitudeOption.middleOfTheNight.labelKey,
        'prayer.highLatitudeMiddleOfTheNight',
      );
      expect(
        HighLatitudeOption.seventhOfTheNight.labelKey,
        'prayer.highLatitudeSeventhOfTheNight',
      );
      expect(
        HighLatitudeOption.angleBased.labelKey,
        'prayer.highLatitudeAngleBased',
      );
      expect(HighLatitudeOption.none.adhanRule, isNull);
    });

    test('theme mode falls back to system', () {
      expect(AppThemeMode.fromStorage('dark'), AppThemeMode.dark);
      expect(AppThemeMode.fromStorage('??'), AppThemeMode.system);
    });
  });

  group('PrayerLocation', () {
    test('validates coordinates', () {
      expect(PrayerLocation.validateCoordinates('30.04', '31.23'), isNull);
      expect(PrayerLocation.validateCoordinates('91', '0'), 'invalid');
      expect(PrayerLocation.validateCoordinates('0', '181'), 'invalid');
      expect(PrayerLocation.validateCoordinates('abc', '0'), 'invalid');
      expect(PrayerLocation.validateCoordinates('', ''), 'invalid');
    });

    test('hasCoordinates rejects out-of-range and non-finite values', () {
      expect(
        const PrayerLocation(useDeviceLocation: false, latitude: 30, longitude: 31)
            .hasCoordinates,
        isTrue,
      );
      expect(
        const PrayerLocation(useDeviceLocation: false, latitude: 200, longitude: 31)
            .hasCoordinates,
        isFalse,
      );
      expect(
        const PrayerLocation(useDeviceLocation: false).hasCoordinates,
        isFalse,
      );
      expect(
        const PrayerLocation(
          useDeviceLocation: false,
          latitude: double.nan,
          longitude: 31,
        ).hasCoordinates,
        isFalse,
      );
    });

    test('copyWith can clear the city name', () {
      const location = PrayerLocation(
        useDeviceLocation: false,
        latitude: 1,
        longitude: 2,
        cityName: 'Cairo',
      );
      expect(location.copyWith().cityName, 'Cairo');
      expect(location.copyWith(clearCity: true).cityName, isNull);
      expect(location.copyWith(cityName: 'Giza').cityName, 'Giza');
    });
  });

  group('LocalizedText', () {
    test('resolves by locale and tolerates a plain string', () {
      const text = LocalizedText(ar: 'صباح', en: 'Morning');
      expect(text.resolve(true), 'صباح');
      expect(text.resolve(false), 'Morning');
      expect(LocalizedText.tryParse('plain')!.resolve(true), 'plain');
      expect(LocalizedText.tryParse(42), isNull);
    });
  });

  group('QuranRef', () {
    test('defaults toAyah to the starting ayah', () {
      final single = QuranRef.fromJson(<String, dynamic>{'surah': 112, 'ayah': 1});
      expect(single.fromAyah, 1);
      expect(single.toAyah, 1);

      final range = QuranRef.fromJson(<String, dynamic>{
        'surah': 112,
        'ayah': 1,
        'toAyah': 4,
      });
      expect(range.toAyah, 4);
    });
  });
}
