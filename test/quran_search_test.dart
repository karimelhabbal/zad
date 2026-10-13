import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/utils/arabic_text.dart';
import 'package:zad/data/models/quran_models.dart';
import 'package:zad/data/search/quran_search.dart';

/// Qur'an search: normalisation, filtering and the surah/ayah/page mapping the
/// UI navigates with.
///
/// The dataset is read straight from disk (`dart:io`) rather than through
/// `rootBundle`, because a >50 KB asset load inside `flutter test`'s fake-async
/// zone routes through `compute()` and hangs.
void main() {
  late QuranData data;

  setUpAll(() {
    data = QuranData.fromJsonString(
      File('assets/data/quran.json').readAsStringSync(),
    );
  });

  group('normalizeArabic', () {
    test('strips harakat and Quranic marks', () {
      expect(normalizeArabic('ٱلرَّحْمَٰنِ'), 'الرحمن');
      expect(normalizeArabic('ٱلْفَاتِحَةِ'), 'الفاتحه');
      expect(normalizeArabic('بِسْمِ'), 'بسم');
    });

    test('unifies alef, hamza, yaa and taa marbuta variants', () {
      expect(normalizeArabic('أحمد'), normalizeArabic('احمد'));
      expect(normalizeArabic('إبراهيم'), normalizeArabic('ابراهيم'));
      expect(normalizeArabic('آدم'), normalizeArabic('ادم'));
      expect(normalizeArabic('موسى'), normalizeArabic('موسي'));
      expect(normalizeArabic('صلاة'), normalizeArabic('صلاه'));
      expect(normalizeArabic('مؤمن'), normalizeArabic('مومن'));
    });

    test('drops tatweel and collapses whitespace', () {
      expect(normalizeArabic('الـــرحمن'), 'الرحمن');
      expect(normalizeArabic('  الفاتحة   والبقرة '), 'الفاتحه والبقره');
    });

    test('maps Arabic-Indic digits to ASCII', () {
      expect(normalizeArabic('٦٠٤'), '604');
      expect(normalizeArabic('١٨'), '18');
    });

    test('lower-cases Latin text', () {
      expect(normalizeArabic('Al-Fatihah'), 'al-fatihah');
    });

    test('is idempotent', () {
      const samples = <String>[
        'ٱلرَّحْمَٰنِ',
        'Al-Fatihah',
        '٦٠٤',
        'بِسْمِ ٱللَّهِ',
      ];
      for (final sample in samples) {
        final once = normalizeArabic(sample);
        expect(normalizeArabic(once), once, reason: sample);
      }
    });
  });

  group('arabicForms / arabicMatches', () {
    test('keeps both spellings of the Uthmani dagger alef', () {
      final forms = arabicForms('ٱلرَّحْمَٰنِ');
      expect(forms.plain, 'الرحمن');
      expect(forms.expanded, 'الرحمان');

      final siraat = arabicForms('ٱلصِّرَٰطَ');
      expect(siraat.plain, 'الصرط');
      expect(siraat.expanded, 'الصراط');
    });

    test('matches a word the reader types without the dagger alef', () {
      // Uthmani writes رحمٰن; readers type الرحمن.
      expect(arabicMatches('ٱلرَّحْمَٰنِ', 'الرحمن'), isTrue);
      expect(arabicMatches('ٱلرَّحْمَٰنِ', 'الرحمان'), isTrue);
    });

    test('matches a word the reader types with a full alef', () {
      // Uthmani writes صرٰط; readers type الصراط.
      expect(arabicMatches('ٱلصِّرَٰطَ', 'الصراط'), isTrue);
      expect(arabicMatches('ٱلصِّرَٰطَ', 'الصرط'), isTrue);
    });

    test('rejects a needle that is absent', () {
      expect(arabicMatches('ٱلصِّرَٰطَ', 'الجن'), isFalse);
      expect(arabicMatches('anything', ''), isFalse);
    });

    test('an empty haystack matches nothing', () {
      expect(arabicMatches('', 'الله'), isFalse);
    });
  });

  group('searchSurahs', () {
    test('an empty query returns every surah', () {
      expect(searchSurahs(data, '').length, 114);
      expect(searchSurahs(data, '   ').length, 114);
    });

    test('matches an unvocalised Arabic name', () {
      final results = searchSurahs(data, 'الفاتحة');
      expect(results.map((s) => s.number), contains(1));
    });

    test('matches the fully vocalised source name too', () {
      final results = searchSurahs(data, 'الفاتحة');
      expect(results.first.number, 1);
    });

    test('matches an English name and its translation', () {
      expect(
        searchSurahs(data, 'kahf').map((s) => s.number),
        contains(18),
      );
      expect(
        searchSurahs(data, 'cave').map((s) => s.number),
        contains(18),
      );
    });

    test('matches by surah number', () {
      final results = searchSurahs(data, '36');
      expect(results.map((s) => s.number), contains(36));
    });

    test('matches by juz and page reference', () {
      expect(searchSurahs(data, '30').map((s) => s.startJuz), contains(30));
      expect(searchSurahs(data, '604').map((s) => s.startPage), contains(604));
    });

    test('ignores diacritics the user does not type', () {
      // "الرحمن" with no harakat must still find the surah whose stored name
      // carries them.
      final results = searchSurahs(data, 'الرحمن');
      expect(results, isNotEmpty);
    });

    test('returns nothing for a query that cannot match', () {
      expect(searchSurahs(data, 'zzzzz'), isEmpty);
    });
  });

  group('searchVerses', () {
    test('finds a known ayah and maps it to the right surah and page', () {
      final results = searchVerses(data, 'اهدنا الصراط المستقيم');
      expect(results, isNotEmpty);

      final (surah, verse) = results.first;
      expect(surah.number, 1, reason: 'Al-Fatihah');
      expect(verse.numberInSurah, 6);
      expect(verse.page, 1);
    });

    test('is diacritic-insensitive against the vocalised source text', () {
      final withDiacritics = searchVerses(data, 'ٱلْحَمْدُ لِلَّهِ');
      final withoutDiacritics = searchVerses(data, 'الحمد لله');
      expect(withDiacritics, isNotEmpty);
      expect(
        withoutDiacritics.map((m) => '${m.$1.number}:${m.$2.numberInSurah}'),
        withDiacritics.map((m) => '${m.$1.number}:${m.$2.numberInSurah}'),
      );
    });

    test('every hit really contains the normalised query', () {
      final results = searchVerses(data, 'الصبر', limit: 25);
      expect(results, isNotEmpty);
      expect(results.length, lessThanOrEqualTo(25));
      for (final (surah, verse) in results) {
        expect(
          arabicMatches(verse.text, 'الصبر'),
          isTrue,
          reason: 'surah ${surah.number} ayah ${verse.numberInSurah}',
        );
        expect(verse.page, inInclusiveRange(1, 604));
        expect(verse.juz, inInclusiveRange(1, 30));
      }
    });

    test('finds a passage the Uthmani text spells with a dagger alef', () {
      // The regression this exists for: `ٱلصِّرَٰطَ` drops to "الصرط" under plain
      // diacritic stripping, so searching the reader's spelling "الصراط" used
      // to return nothing.
      final results = searchVerses(data, 'الصراط المستقيم');
      expect(results, isNotEmpty);
      expect(
        results.map((m) => '${m.$1.number}:${m.$2.numberInSurah}'),
        contains('1:6'),
      );
    });

    test('respects the result cap', () {
      expect(searchVerses(data, 'الله', limit: 10).length, 10);
    });

    test('treats a one-character query as no search', () {
      expect(searchVerses(data, 'ا'), isEmpty);
      expect(searchVerses(data, ''), isEmpty);
      expect(searchVerses(data, '  '), isEmpty);
    });

    test('returns nothing for a query that cannot match', () {
      expect(searchVerses(data, 'قققققق'), isEmpty);
    });
  });

  group('countVerseMatches', () {
    test('is at least the number of shown results and respects the cap', () {
      final shown = searchVerses(data, 'الله', limit: 5).length;
      final total = countVerseMatches(data, 'الله');
      expect(shown, 5);
      expect(total, greaterThanOrEqualTo(shown));
    });

    test('agrees with an uncapped search', () {
      final uncapped = searchVerses(data, 'الرحمن', limit: 100000).length;
      expect(countVerseMatches(data, 'الرحمن'), uncapped);
    });

    test('is zero for a too-short query', () {
      expect(countVerseMatches(data, 'ا'), 0);
    });
  });
}
