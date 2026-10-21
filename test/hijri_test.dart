import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/utils/hijri_date.dart';

/// Reference conversions taken from the official Umm al-Qura calendar
/// (High Judicial Council of Saudi Arabia), which is also the calendar
/// published by the Egyptian authorities for the same dates.
void main() {
  group('HijriDate.fromGregorian - official Umm al-Qura values', () {
    final cases = <(DateTime, int, int, int, String)>[
      (DateTime(2024, 3, 20), 1445, 9, 10, 'Ramadan 1445'),
      (DateTime(2024, 7, 7), 1446, 1, 1, '1 Muharram 1446'),
      (DateTime(2024, 8, 5), 1446, 2, 1, '1 Safar 1446'),
      (DateTime(2025, 1, 1), 1446, 7, 1, '1 Rajab 1446'),
      (DateTime(2025, 3, 1), 1446, 9, 1, '1 Ramadan 1446'),
      (DateTime(2025, 3, 30), 1446, 10, 1, '1 Shawwal 1446 (Eid al-Fitr)'),
      (DateTime(2025, 6, 26), 1447, 1, 1, '1 Muharram 1447'),
      (DateTime(2026, 1, 1), 1447, 7, 12, '12 Rajab 1447'),
      (DateTime(2026, 1, 20), 1447, 8, 1, "1 Sha'ban 1447"),
      (DateTime(2026, 5, 18), 1447, 12, 1, '1 Dhu al-Hijjah 1447'),
      (DateTime(2026, 5, 27), 1447, 12, 10, '10 Dhu al-Hijjah 1447'),
      (DateTime(2026, 6, 16), 1448, 1, 1, '1 Muharram 1448'),
      (DateTime(2026, 8, 14), 1448, 3, 1, "1 Rabi' I 1448"),
      (DateTime(2026, 9, 12), 1448, 4, 1, "1 Rabi' II 1448"),
      (DateTime(2026, 10, 12), 1448, 5, 1, '1 Jumada al-Ula 1448'),
      (DateTime(2026, 10, 14), 1448, 5, 3, '3 Jumada al-Ula 1448'),
      (DateTime(2016, 10, 2), 1438, 1, 1, '1 Muharram 1438 (table start)'),
      (DateTime(2050, 9, 17), 1472, 12, 30, '30 Dhu al-Hijjah 1472 (table end)'),
    ];

    for (final (date, year, month, day, label) in cases) {
      test('${date.year}-${date.month}-${date.day} → $label', () {
        final hijri = HijriDate.fromGregorian(date);
        expect(hijri.year, year, reason: label);
        expect(hijri.month, month, reason: label);
        expect(hijri.day, day, reason: label);
      });
    }
  });

  group('HijriDate.fromGregorian - robustness', () {
    test('always produces a valid month and day across three years', () {
      for (var i = 0; i < 1200; i++) {
        final gregorian = DateTime(2024, 1, 1).add(Duration(days: i));
        final hijri = HijriDate.fromGregorian(gregorian);
        expect(hijri.year, inInclusiveRange(1440, 1474));
        expect(hijri.month, inInclusiveRange(1, 12));
        expect(
          hijri.day,
          inInclusiveRange(1, 30),
          reason: 'day out of range for '
              '${gregorian.year}-${gregorian.month}-${gregorian.day}',
        );
      }
    });

    test('the Hijri year advances roughly every 354 days', () {
      final start = HijriDate.fromGregorian(DateTime(2024, 1, 1));
      final later = HijriDate.fromGregorian(DateTime(2025, 1, 1));
      expect(later.year - start.year, inInclusiveRange(1, 2));
    });

    test('consecutive Gregorian days are consecutive Hijri days', () {
      final first = DateTime(2026, 1, 1);
      var previous = HijriDate.fromGregorian(first);
      for (var i = 1; i < 400; i++) {
        final current =
            HijriDate.fromGregorian(first.add(Duration(days: i)));

        final isNextInMonth =
            current.day == previous.day + 1 && current.month == previous.month;
        final isRollover = current.day == 1 &&
            (previous.day == 29 || previous.day == 30) &&
            current.month == previous.month % 12 + 1 &&
            current.year ==
                (previous.month == 12 ? previous.year + 1 : previous.year);

        expect(
          isNextInMonth || isRollover,
          isTrue,
          reason: 'jump from ${previous.day}/${previous.month}/${previous.year}'
              ' to ${current.day}/${current.month}/${current.year} on day $i',
        );
        previous = current;
      }
    });
  });

  group('formatting', () {
    test('exposes twelve month names in both languages', () {
      expect(HijriDate.monthNamesAr.length, 12);
      expect(HijriDate.monthNamesEn.length, 12);
      expect(HijriDate.monthNamesAr[8], 'رمضان');
    });

    test('monthName respects the locale', () {
      final hijri = HijriDate.fromGregorian(DateTime(2025, 3, 1));
      expect(hijri.monthName(true), 'رمضان');
      expect(hijri.monthName(false), 'Ramadan');
    });

    test('format uses the supplied digit converter', () {
      final hijri = HijriDate.fromGregorian(DateTime(2025, 3, 1));
      final arabic = hijri.format(true, (n) => 'AR$n');
      expect(arabic, contains('AR'));
      expect(arabic, contains('رمضان'));

      final latin = hijri.format(false, (n) => '$n');
      expect(latin, contains('Ramadan'));
      expect(latin, isNot(contains('AR')));
    });
  });
}
