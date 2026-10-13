import '../../core/utils/arabic_text.dart';
import '../models/quran_models.dart';

/// Qur'an search over the bundled dataset.
///
/// Kept as pure functions on [QuranData] (rather than methods on the
/// controller) so the matching rules can be tested directly against the real
/// asset without standing up the whole app.
///
/// Matching goes through [arabicMatches], so it is insensitive to diacritics,
/// letter variants and both Uthmani spellings of the dagger alef: `الرحمن`
/// finds `ٱلرَّحْمَٰنِ` and `الصراط` finds `ٱلصِّرَٰطَ`.

/// Surah-name search: Arabic name, fully vocalised name, English name, English
/// translation, and numeric surah / juz / page references.
List<Surah> searchSurahs(QuranData data, String query) {
  final trimmed = query.trim();
  final q = arabicForms(trimmed);
  if (q.isEmpty) return data.surahs;
  final numeric = int.tryParse(q.plain);

  return data.surahs
      .where((s) {
        if (arabicMatches(s.arabicName, trimmed) ||
            arabicMatches(s.fullName, trimmed) ||
            s.englishName.toLowerCase().contains(q.plain) ||
            s.englishTranslation.toLowerCase().contains(q.plain)) {
          return true;
        }
        if (numeric != null &&
            (s.number == numeric ||
                s.startJuz == numeric ||
                s.startPage == numeric)) {
          return true;
        }
        return false;
      })
      .toList(growable: false);
}

/// Ayah-text search across the whole Qur'an, in Mushaf order.
///
/// Capped at [limit] so a common word cannot build a 6236-row list on the UI
/// thread. A query shorter than two normalised characters matches almost
/// everything and is treated as "no search".
List<(Surah, QuranVerse)> searchVerses(
  QuranData data,
  String query, {
  int limit = 60,
}) {
  final trimmed = query.trim();
  if (arabicForms(trimmed).plain.length < 2) {
    return const <(Surah, QuranVerse)>[];
  }
  final results = <(Surah, QuranVerse)>[];
  for (final surah in data.surahs) {
    for (final verse in surah.verses) {
      if (arabicMatches(verse.text, trimmed)) {
        results.add((surah, verse));
        if (results.length >= limit) return results;
      }
    }
  }
  return results;
}

/// Total number of ayahs matching [query], ignoring [searchVerses]'s cap, so
/// the UI can say how many matches exist beyond the ones it shows.
int countVerseMatches(QuranData data, String query) {
  final trimmed = query.trim();
  if (arabicForms(trimmed).plain.length < 2) return 0;
  var total = 0;
  for (final surah in data.surahs) {
    for (final verse in surah.verses) {
      if (arabicMatches(verse.text, trimmed)) total++;
    }
  }
  return total;
}
