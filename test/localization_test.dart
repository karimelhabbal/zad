import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/l10n/app_localizations.dart';
import 'package:zad/l10n/strings_ar.dart';
import 'package:zad/l10n/strings_en.dart';

/// Guards the source-based localisation: both locales must stay in lockstep so
/// no screen can silently fall back to Arabic (or render a raw key).
void main() {
  test('Arabic and English expose exactly the same keys', () {
    final ar = stringsAr.keys.toSet();
    final en = stringsEn.keys.toSet();

    final missingInEn = ar.difference(en).toList()..sort();
    final missingInAr = en.difference(ar).toList()..sort();

    expect(missingInEn, isEmpty, reason: 'keys present only in Arabic');
    expect(missingInAr, isEmpty, reason: 'keys present only in English');
  });

  test('no key is defined twice and no value is empty', () {
    expect(stringsAr.length, stringsAr.keys.toSet().length);
    expect(stringsEn.length, stringsEn.keys.toSet().length);
    for (final entry in stringsAr.entries) {
      expect(entry.value.trim(), isNotEmpty, reason: entry.key);
    }
    for (final entry in stringsEn.entries) {
      expect(entry.value.trim(), isNotEmpty, reason: entry.key);
    }
  });

  test('placeholder tokens match between locales', () {
    final tokenPattern = RegExp(r'\{(\w+)\}');
    for (final key in stringsAr.keys) {
      final ar = tokenPattern
          .allMatches(stringsAr[key]!)
          .map((m) => m.group(1))
          .toSet();
      final en = tokenPattern
          .allMatches(stringsEn[key]!)
          .map((m) => m.group(1))
          .toSet();
      expect(
        ar,
        en,
        reason: 'placeholder mismatch for "$key" (ar=$ar en=$en)',
      );
    }
  });

  group('AppLocalizations', () {
    final ar = AppLocalizations(const Locale('ar'));
    final en = AppLocalizations(const Locale('en'));

    test('reports direction and language correctly', () {
      expect(ar.isArabic, isTrue);
      expect(ar.isRtl, isTrue);
      expect(ar.direction, TextDirection.rtl);
      expect(en.isArabic, isFalse);
      expect(en.isRtl, isFalse);
      expect(en.direction, TextDirection.ltr);
    });

    test('substitutes placeholders', () {
      expect(
        ar.t('quran.pageShort', args: <String, Object?>{'n': '١٢'}),
        'صفحة ١٢',
      );
      expect(en.t('quran.pageShort', args: <String, Object?>{'n': '12'}), 'Page 12');
    });

    test('formats digits with Arabic-Indic numerals for Arabic only', () {
      expect(ar.n(604), '٦٠٤');
      expect(en.n(604), '604');
      expect(ar.n(0), '٠');
    });

    test('digits() localises every ASCII digit in a string', () {
      expect(ar.digits('12:05:09'), '١٢:٠٥:٠٩');
      expect(en.digits('12:05:09'), '12:05:09');
      // Non-digit characters must survive untouched.
      expect(ar.digits('ص 7'), 'ص ٧');
    });

    test('formats durations with a single digit set per locale', () {
      expect(ar.duration(const Duration(minutes: 5, seconds: 3)), '٠٥:٠٣');
      expect(en.duration(const Duration(minutes: 5, seconds: 3)), '05:03');
      expect(
        ar.duration(const Duration(hours: 1, minutes: 42, seconds: 11)),
        '٠١:٤٢:١١',
      );
      expect(
        en.duration(const Duration(hours: 1, minutes: 42, seconds: 11)),
        '01:42:11',
      );
      expect(en.duration(const Duration(seconds: -10)), '00:00');
      expect(ar.duration(const Duration(seconds: -10)), '٠٠:٠٠');
    });

    test('formats times of day with a single digit set per locale', () {
      expect(en.timeOfDay(const TimeOfDay(hour: 13, minute: 5)), '1:05 PM');
      expect(ar.timeOfDay(const TimeOfDay(hour: 13, minute: 5)), '١:٠٥ م');
      expect(en.timeOfDay(const TimeOfDay(hour: 0, minute: 0)), '12:00 AM');
      expect(ar.timeOfDay(const TimeOfDay(hour: 0, minute: 0)), '١٢:٠٠ ص');
      expect(ar.timeOfDay(const TimeOfDay(hour: 4, minute: 32)), '٤:٣٢ ص');
    });

    test('clock() matches timeOfDay() and never mixes digit sets', () {
      final moment = DateTime(2026, 10, 12, 17, 42);
      expect(ar.clock(moment), ar.timeOfDay(TimeOfDay.fromDateTime(moment)));
      expect(en.clock(moment), en.timeOfDay(TimeOfDay.fromDateTime(moment)));
      expect(ar.clock(moment), '٥:٤٢ م');
      expect(en.clock(moment), '5:42 PM');
    });

    test('no formatted time mixes Arabic-Indic and Western digits', () {
      // Regression guard: an earlier version rendered the hour through the
      // Arabic-Indic converter but left the minute as a Western string.
      final western = RegExp(r'[0-9]');
      final arabicIndic = RegExp('[\u0660-\u0669]');

      for (final minute in <int>[0, 5, 9, 42, 59]) {
        for (final hour in <int>[0, 4, 12, 13, 17, 23]) {
          final time = TimeOfDay(hour: hour, minute: minute);

          final arabic = ar.timeOfDay(time);
          expect(
            western.hasMatch(arabic),
            isFalse,
            reason: 'Arabic time "$arabic" contains Western digits',
          );
          expect(arabicIndic.hasMatch(arabic), isTrue);

          final english = en.timeOfDay(time);
          expect(
            arabicIndic.hasMatch(english),
            isFalse,
            reason: 'English time "$english" contains Arabic-Indic digits',
          );
        }
      }

      for (final seconds in <int>[0, 7, 59]) {
        final d = Duration(hours: 2, minutes: 8, seconds: seconds);
        expect(western.hasMatch(ar.duration(d)), isFalse);
        expect(arabicIndic.hasMatch(en.duration(d)), isFalse);
      }
    });

    test('falls back to the reference locale for an unknown key', () {
      expect(ar.t('does.not.exist'), 'does.not.exist');
    });

    test('resolves an unsupported locale to Arabic', () {
      expect(AppLocalizations.resolve(const Locale('fr'), AppLocalizations.supportedLocales).languageCode, 'ar');
      expect(AppLocalizations.resolve(const Locale('en'), AppLocalizations.supportedLocales).languageCode, 'en');
    });
  });
}
