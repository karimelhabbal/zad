import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/data/models/quran_models.dart';

/// Integrity checks for the bundled Quran dataset.
///
/// The asset is generated from the Tanzil Uthmani (Hafs 'an Asim) edition and
/// is the single source of truth for every Quranic string the app renders.
/// These tests fail loudly if the asset is ever regenerated incorrectly.
void main() {
  late QuranData data;

  setUpAll(() {
    final raw = File('assets/data/quran.json').readAsStringSync();
    data = QuranData.fromJsonString(raw);
  });

  test('contains all 114 surahs and 6236 ayahs', () {
    expect(data.surahs.length, 114);
    expect(data.meta.totalSurahs, 114);
    expect(data.meta.totalAyahs, 6236);

    final counted = data.surahs.fold<int>(0, (sum, s) => sum + s.verses.length);
    expect(counted, 6236);
  });

  test('declares the authentic 604-page Madinah Mushaf layout', () {
    expect(data.meta.totalPages, 604);
    // The riwayah is recorded in Arabic; its Latin transliteration is part of
    // the source attribution line.
    expect(data.meta.riwayah, contains('حفص'));
    expect(data.meta.source.toLowerCase(), contains('hafs'));
    expect(data.meta.source.toLowerCase(), contains('tanzil'));
  });

  test('every ayah carries a valid page (1-604) and juz (1-30)', () {
    for (final surah in data.surahs) {
      for (final verse in surah.verses) {
        expect(
          verse.page,
          inInclusiveRange(1, 604),
          reason: 'surah ${surah.number} ayah ${verse.numberInSurah}',
        );
        expect(
          verse.juz,
          inInclusiveRange(1, 30),
          reason: 'surah ${surah.number} ayah ${verse.numberInSurah}',
        );
        expect(verse.text.trim(), isNotEmpty);
      }
    }
  });

  test('ayah numbering is sequential inside every surah', () {
    for (final surah in data.surahs) {
      expect(
        surah.ayahCount,
        surah.verses.length,
        reason: 'surah ${surah.number} declares ${surah.ayahCount}',
      );
      for (var i = 0; i < surah.verses.length; i++) {
        expect(surah.verses[i].numberInSurah, i + 1);
      }
    }
  });

  test('pages are monotonically non-decreasing across the Mushaf', () {
    var last = 1;
    for (final surah in data.surahs) {
      for (final verse in surah.verses) {
        expect(
          verse.page,
          greaterThanOrEqualTo(last),
          reason: 'surah ${surah.number} ayah ${verse.numberInSurah}',
        );
        last = verse.page;
      }
    }
    expect(last, 604);
  });

  test('juz boundaries map to the expected Mushaf pages', () {
    expect(data.meta.juzStartPage[1], 1);
    expect(data.meta.juzStartPage[15], 282);
    expect(data.meta.juzStartPage[30], 582);
    expect(data.juzForPage(1), 1);
    expect(data.juzForPage(604), 30);
  });

  test('known surah start pages are correct', () {
    expect(data.surah(1).startPage, 1); // Al-Fatihah
    expect(data.surah(2).startPage, 2); // Al-Baqarah
    expect(data.surah(18).startPage, 293); // Al-Kahf
    expect(data.surah(114).startPage, 604); // An-Nas
  });

  test('the Basmalah is split out of the first ayah', () {
    // Al-Fatihah: the Basmalah IS ayah 1.
    expect(data.surah(1).verses.first.text, contains('بِسْمِ'));

    // Al-Baqarah and Aal-Imran begin with the disjoint letters.
    expect(data.surah(2).verses.first.text.trim(), 'الٓمٓ');
    expect(data.surah(3).verses.first.text.trim(), 'الٓمٓ');

    // At-Tawbah has no Basmalah at all.
    expect(data.surah(9).hasBismillah, isFalse);
    expect(data.surah(9).verses.first.text, isNot(startsWith('بِسْمِ')));

    // Every other surah declares one.
    for (final surah in data.surahs) {
      if (surah.number == 9) continue;
      expect(surah.hasBismillah, isTrue, reason: 'surah ${surah.number}');
    }
  });

  test('surah names keep their maddah and are free of diacritics', () {
    expect(data.surah(3).arabicName, contains('آل عمران'));
    expect(data.surah(1).arabicName, 'الفاتحة');
    expect(data.surah(18).arabicName, 'الكهف');
    for (final surah in data.surahs) {
      expect(surah.arabicName.trim(), isNotEmpty);
      expect(surah.arabicName, isNot(contains('سُورَةُ')));
    }
  });

  test('exactly 15 prostration ayahs are recorded', () {
    expect(data.meta.sajdaAyahs.length, 15);
    expect(data.meta.isSajda(7, 206), isTrue);
    expect(data.meta.isSajda(1, 1), isFalse);
  });

  test('verse of the day is stable for a calendar day and inside the Mushaf', () {
    final morning = data.verseOfTheDay(DateTime(2025, 6, 1, 6));
    final evening = data.verseOfTheDay(DateTime(2025, 6, 1, 22));
    expect(morning.$1.number, evening.$1.number);
    expect(morning.$2.numberInSurah, evening.$2.numberInSurah);
    expect(morning.$2.page, inInclusiveRange(1, 604));
  });

  test('page lookups resolve to a real surah', () {
    expect(data.surahForPage(1).number, 1);
    expect(data.surahForPage(604).number, 114);
    expect(data.pageOf(18, 1), 293);
    expect(data.surahStartingOnPage(2)?.number, 2);
  });

  test('a corrupt payload does not crash the parser', () {
    expect(
      () => QuranData.fromJsonString('{"meta":{},"surahs":[]}'),
      throwsA(anything),
    );
  });
}
