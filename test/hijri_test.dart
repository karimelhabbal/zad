import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/utils/hijri_date.dart';

void main() {
  group('HijriDate.fromGregorian', () {
    test('converts the start of Ramadan 1445', () {
      final hijri = HijriDate.fromGregorian(DateTime(2024, 3, 20));
      expect(hijri.year, 1445);
      expect(hijri.month, 9);
      expect(hijri.day, inInclusiveRange(1, 30));
    });

    test('converts the start of Muharram 1445', () {
      final hijri = HijriDate.fromGregorian(DateTime(2023, 7, 20));
      expect(hijri.year, 1445);
      expect(hijri.month, 1);
    });

    test('converts a date in 1447', () {
      final hijri = HijriDate.fromGregorian(DateTime(2025, 7, 1));
      expect(hijri.year, 1447);
      expect(hijri.month, inInclusiveRange(1, 12));
      expect(hijri.day, inInclusiveRange(1, 30));
    });

    test('always produces a valid month and day for a range of dates', () {
      for (var i = 0; i < 400; i++) {
        final gregorian = DateTime(2024, 1, 1).add(Duration(days: i * 3));
        final hijri = HijriDate.fromGregorian(gregorian);
        expect(hijri.year, inInclusiveRange(1440, 1460));
        expect(hijri.month, inInclusiveRange(1, 12));
        expect(hijri.day, inInclusiveRange(1, 30));
      }
    });

    test('the Hijri year advances roughly every 354 days', () {
      final start = HijriDate.fromGregorian(DateTime(2024, 1, 1));
      final later = HijriDate.fromGregorian(DateTime(2025, 1, 1));
      expect(later.year - start.year, inInclusiveRange(1, 2));
    });
  });

  group('formatting', () {
    test('exposes twelve month names in both languages', () {
      expect(HijriDate.monthNamesAr.length, 12);
      expect(HijriDate.monthNamesEn.length, 12);
      expect(HijriDate.monthNamesAr[8], 'رمضان');
    });

    test('monthName respects the locale', () {
      final hijri = HijriDate.fromGregorian(DateTime(2024, 3, 20));
      expect(hijri.monthName(true), 'رمضان');
      expect(hijri.monthName(false), 'Ramadan');
    });

    test('format uses the supplied digit converter', () {
      final hijri = HijriDate.fromGregorian(DateTime(2024, 3, 20));
      final arabic = hijri.format(true, (n) => 'AR$n');
      expect(arabic, contains('AR'));
      expect(arabic, contains('رمضان'));

      final latin = hijri.format(false, (n) => '$n');
      expect(latin, contains('Ramadan'));
      expect(latin, isNot(contains('AR')));
    });
  });
}
