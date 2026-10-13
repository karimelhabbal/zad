// Flutter-free verification harness.
//
// `flutter test` and `dart analyze` both need to spawn helper processes, which
// this sandbox cannot do (Windows named-pipe exhaustion: "CreateFile failed
// 231 (All pipe instances are busy)"). `dart --disable-dart-dev` still runs a
// script on the Dart VM in-process, so this harness exercises the parts of the
// app that have no Flutter dependency — the Arabic search pipeline, the reciter
// catalogue and the localisation resources — against the real bundled asset.
//
// Run from the project root:
//
//     dart --disable-dart-dev tool/verify_offline.dart
//
// It is a smoke check, not a replacement for `flutter test`: anything that
// touches `dart:ui` (widgets, `TimeOfDay`, `Color`) cannot run here and is
// covered by the real test suite instead.

import 'dart:convert';
import 'dart:io';

import 'package:zad/core/utils/arabic_text.dart';
import 'package:zad/data/models/quran_models.dart';
import 'package:zad/data/models/reciter.dart';
import 'package:zad/data/search/quran_search.dart';
import 'package:zad/l10n/strings_ar.dart';
import 'package:zad/l10n/strings_en.dart';

int _passed = 0;
int _failed = 0;

void check(String label, bool condition, [String? detail]) {
  if (condition) {
    _passed++;
    return;
  }
  _failed++;
  stdout.writeln('  FAIL  $label${detail == null ? '' : ' — $detail'}');
}

void section(String title) => stdout.writeln('\n== $title ==');

void main() {
  final quranJson = File('assets/data/quran.json');
  if (!quranJson.existsSync()) {
    stderr.writeln('assets/data/quran.json not found — run from the project root');
    exit(2);
  }
  final data = QuranData.fromJsonString(quranJson.readAsStringSync());

  // ------------------------------------------------------- normalisation --
  section('normalizeArabic');
  check('strips harakat', normalizeArabic('ٱلرَّحْمَٰنِ') == 'الرحمن',
      normalizeArabic('ٱلرَّحْمَٰنِ'));
  check('strips harakat (2)', normalizeArabic('ٱلْفَاتِحَةِ') == 'الفاتحه',
      normalizeArabic('ٱلْفَاتِحَةِ'));
  check('unifies alef hamza', normalizeArabic('أحمد') == normalizeArabic('احمد'));
  check('unifies alef madda', normalizeArabic('آدم') == normalizeArabic('ادم'));
  check('unifies alef wasla', normalizeArabic('ٱللَّهِ') == normalizeArabic('الله'),
      normalizeArabic('ٱللَّهِ'));
  check('unifies yaa', normalizeArabic('موسى') == normalizeArabic('موسي'));
  check('unifies taa marbuta', normalizeArabic('صلاة') == normalizeArabic('صلاه'));
  check('drops tatweel', normalizeArabic('الـــرحمن') == 'الرحمن');
  check('collapses whitespace',
      normalizeArabic('  الفاتحة   والبقرة ') == 'الفاتحه والبقره',
      normalizeArabic('  الفاتحة   والبقرة '));
  check('maps Arabic-Indic digits', normalizeArabic('٦٠٤') == '604',
      normalizeArabic('٦٠٤'));
  check('lower-cases Latin', normalizeArabic('Al-Fatihah') == 'al-fatihah');
  for (final sample in <String>[
    'ٱلرَّحْمَٰنِ',
    'Al-Fatihah',
    '٦٠٤',
    'بِسْمِ ٱللَّهِ',
  ]) {
    final once = normalizeArabic(sample);
    check('idempotent: $sample', normalizeArabic(once) == once, once);
  }

  // ------------------------------------------------------- dagger alef ----
  section('arabicForms / arabicMatches (Uthmani dagger alef)');
  final rahman = arabicForms('ٱلرَّحْمَٰنِ');
  check('plain drops the dagger alef', rahman.plain == 'الرحمن', rahman.plain);
  check('expanded turns it into a full alef', rahman.expanded == 'الرحمان',
      rahman.expanded);
  final siraat = arabicForms('ٱلصِّرَٰطَ');
  check('plain drops the dagger alef (2)', siraat.plain == 'الصرط', siraat.plain);
  check('expanded turns it into a full alef (2)', siraat.expanded == 'الصراط',
      siraat.expanded);
  check('matches the reader spelling without an alef',
      arabicMatches('ٱلرَّحْمَٰنِ', 'الرحمن'));
  check('matches the reader spelling with a full alef',
      arabicMatches('ٱلصِّرَٰطَ', 'الصراط'));
  check('rejects an absent needle', !arabicMatches('ٱلصِّرَٰطَ', 'الجن'));
  check('rejects an empty needle', !arabicMatches('anything', ''));

  // -------------------------------------------------------- surah search --
  section('searchSurahs (real dataset)');
  check('empty query returns all 114', searchSurahs(data, '').length == 114);
  check('whitespace query returns all 114',
      searchSurahs(data, '   ').length == 114);
  check('Arabic name finds Al-Fatihah',
      searchSurahs(data, 'الفاتحة').any((s) => s.number == 1));
  check('English name finds Al-Kahf',
      searchSurahs(data, 'kahf').any((s) => s.number == 18));
  check('translation finds Al-Kahf',
      searchSurahs(data, 'cave').any((s) => s.number == 18));
  check('surah number finds Ya-Sin',
      searchSurahs(data, '36').any((s) => s.number == 36));
  check('juz number matches', searchSurahs(data, '30').any((s) => s.startJuz == 30));
  check('page number matches',
      searchSurahs(data, '604').any((s) => s.startPage == 604));
  check('diacritic-free query finds the vocalised name',
      searchSurahs(data, 'الرحمن').isNotEmpty);
  check('nonsense query returns nothing', searchSurahs(data, 'zzzzz').isEmpty);

  // --------------------------------------------------------- ayah search --
  section('searchVerses (real dataset)');
  final fatihah = searchVerses(data, 'اهدنا الصراط المستقيم');
  check('finds Al-Fatihah 1:6', fatihah.isNotEmpty);
  if (fatihah.isNotEmpty) {
    final (surah, verse) = fatihah.first;
    check('  surah is 1', surah.number == 1, '${surah.number}');
    check('  ayah is 6', verse.numberInSurah == 6, '${verse.numberInSurah}');
    check('  page is 1', verse.page == 1, '${verse.page}');
  }

  String key((Surah, QuranVerse) m) => '${m.$1.number}:${m.$2.numberInSurah}';
  final withDiacritics = searchVerses(data, 'ٱلْحَمْدُ لِلَّهِ');
  final withoutDiacritics = searchVerses(data, 'الحمد لله');
  check('diacritic-insensitive search agrees',
      withDiacritics.map(key).join(',') == withoutDiacritics.map(key).join(','));
  check('vocalised query returns hits', withDiacritics.isNotEmpty);

  final sabr = searchVerses(data, 'الصبر', limit: 25);
  check('capped search respects the limit', sabr.length <= 25);
  check('capped search returns hits', sabr.isNotEmpty);
  var allContain = true;
  var positionsValid = true;
  for (final (_, verse) in sabr) {
    if (!arabicMatches(verse.text, 'الصبر')) allContain = false;
    if (verse.page < 1 || verse.page > 604) positionsValid = false;
    if (verse.juz < 1 || verse.juz > 30) positionsValid = false;
  }
  check('every hit really contains the query', allContain);
  check('every hit has a valid page/juz', positionsValid);

  final sirat = searchVerses(data, 'الصراط المستقيم');
  check('finds the dagger-alef passage "الصراط المستقيم"', sirat.isNotEmpty);
  check('  and maps it to Al-Fatihah 1:6',
      sirat.isNotEmpty && '${sirat.first.$1.number}:${sirat.first.$2.numberInSurah}' == '1:6',
      sirat.isEmpty ? 'no hits' : '${sirat.first.$1.number}:${sirat.first.$2.numberInSurah}');
  check('finds "الرحمن" in the vocalised text',
      searchVerses(data, 'الرحمن', limit: 5).isNotEmpty);
  check('limit of 10 yields 10', searchVerses(data, 'الله', limit: 10).length == 10);
  check('one-character query is ignored', searchVerses(data, 'ا').isEmpty);
  check('empty query is ignored', searchVerses(data, '').isEmpty);
  check('nonsense query returns nothing', searchVerses(data, 'قققققق').isEmpty);

  section('countVerseMatches');
  final total = countVerseMatches(data, 'الله');
  check('count >= shown', total >= searchVerses(data, 'الله', limit: 5).length);
  check('agrees with an uncapped search',
      countVerseMatches(data, 'الرحمن') ==
          searchVerses(data, 'الرحمن', limit: 100000).length);
  check('zero for a too-short query', countVerseMatches(data, 'ا') == 0);

  // ----------------------------------------------------- reciter catalogue --
  section('QuranReciters');
  check('catalogue is not empty', QuranReciters.all.isNotEmpty);
  final ids = QuranReciters.all.map((r) => r.id).toList();
  check('ids are unique', ids.toSet().length == ids.length);
  var idsOk = true;
  var namesOk = true;
  var hostsOk = true;
  for (final reciter in QuranReciters.all) {
    if (!reciter.id.startsWith('ar.')) idsOk = false;
    if (reciter.arabicName.trim().isEmpty ||
        reciter.englishName.trim().isEmpty) {
      namesOk = false;
    }
    if (Uri.parse(reciter.surahAudioUrl(1)).host != 'cdn.islamic.network') {
      hostsOk = false;
    }
  }
  check('every id is ar.*', idsOk);
  check('every entry has both names', namesOk);
  check('every URL points at cdn.islamic.network', hostsOk);
  check('default reciter is verified',
      QuranReciters.isVerified(QuranReciters.defaultReciterId));
  check('default reciter is in the catalogue',
      QuranReciters.all.contains(QuranReciters.defaultReciter));
  check('isVerified rejects null', !QuranReciters.isVerified(null));
  check('isVerified rejects empty', !QuranReciters.isVerified(''));
  check('isVerified rejects the 403 editions',
      !QuranReciters.isVerified('ar.husary') &&
          !QuranReciters.isVerified('ar.mahermuaiqly'));
  check('byId falls back for unknown ids',
      QuranReciters.byId('nope').id == QuranReciters.defaultReciterId);
  check('byId resolves a known id', QuranReciters.byId('ar.alafasy').id == 'ar.alafasy');
  check(
    'URL shape is exact',
    QuranReciters.defaultReciter.surahAudioUrl(1) ==
        'https://cdn.islamic.network/quran/audio-surah/128/ar.alafasy/1.mp3',
    QuranReciters.defaultReciter.surahAudioUrl(1),
  );
  check(
    'URL shape is exact for surah 114',
    QuranReciters.defaultReciter.surahAudioUrl(114) ==
        'https://cdn.islamic.network/quran/audio-surah/128/ar.alafasy/114.mp3',
    QuranReciters.defaultReciter.surahAudioUrl(114),
  );

  // The catalogue used to be a hand-written list of 18, which silently omitted
  // reciters the CDN does serve (notably عبد الله المطرود). These guard the
  // generated list against regressing to a narrow one.
  check('catalogue is comprehensive', QuranReciters.all.length >= 100,
      '${QuranReciters.all.length}');
  check('Arabic names are unique',
      QuranReciters.all.map((r) => r.arabicName).toSet().length ==
          QuranReciters.all.length);
  check('includes عبد الله المطرود (ar.abdullahalmatrood)',
      QuranReciters.isVerified('ar.abdullahalmatrood'));
  check(
    'the 403 editions are still excluded',
    !QuranReciters.isVerified('ar.minshawi') &&
        !QuranReciters.isVerified('ar.abdurrahmaansudais') &&
        !QuranReciters.isVerified('ar.hudhaify') &&
        !QuranReciters.isVerified('ar.alafasy-2'),
  );

  // Picker search: Arabic is normalised, Latin matches the English name.
  check('search with an empty query returns everything',
      QuranReciters.search('').length == QuranReciters.all.length);
  check('search by Arabic name finds the reciter',
      QuranReciters.search('المطرود').any((r) => r.id == 'ar.abdullahalmatrood'),
      QuranReciters.search('المطرود').map((r) => r.id).join(','));
  check('search ignores harakat',
      QuranReciters.search('العفاسي').any((r) => r.id == 'ar.alafasy'));
  check('search by Latin name works',
      QuranReciters.search('matrood').any((r) => r.id == 'ar.abdullahalmatrood'));
  check('search by id works',
      QuranReciters.search('ar.alafasy').any((r) => r.id == 'ar.alafasy'));
  check('search for nonsense returns nothing',
      QuranReciters.search('zzqqxx').isEmpty);
  check('search results are a subset of the catalogue',
      QuranReciters.search('محمد').every(QuranReciters.all.contains));

  // --------------------------------------------------------- localisation --
  section('localisation resources');
  final arKeys = stringsAr.keys.toSet();
  final enKeys = stringsEn.keys.toSet();
  check('key sets are identical', arKeys.difference(enKeys).isEmpty &&
      enKeys.difference(arKeys).isEmpty,
      'ar-only=${arKeys.difference(enKeys)} en-only=${enKeys.difference(arKeys)}');
  check('no duplicate keys in Arabic',
      stringsAr.length == arKeys.length);
  check('no duplicate keys in English', stringsEn.length == enKeys.length);
  var noEmpty = true;
  for (final entry in stringsAr.entries) {
    if (entry.value.trim().isEmpty) noEmpty = false;
  }
  for (final entry in stringsEn.entries) {
    if (entry.value.trim().isEmpty) noEmpty = false;
  }
  check('no empty values', noEmpty);

  final tokenPattern = RegExp(r'\{(\w+)\}');
  Set<String> tokens(String value) =>
      tokenPattern.allMatches(value).map((m) => m.group(1)!).toSet();
  var placeholdersMatch = true;
  for (final k in arKeys) {
    if (tokens(stringsAr[k]!).join(',') != tokens(stringsEn[k]!).join(',')) {
      placeholdersMatch = false;
    }
  }
  check('placeholder tokens match across locales', placeholdersMatch);

  const newKeys = <String>[
    'audio.title',
    'audio.selectReciter',
    'audio.reciter',
    'audio.nowPlaying',
    'audio.play',
    'audio.pause',
    'audio.resume',
    'audio.stop',
    'audio.loading',
    'audio.completed',
    'audio.retry',
    'audio.error',
    'audio.errorNetwork',
    'audio.errorTimeout',
    'audio.errorUnavailable',
    'audio.errorPlayback',
    'audio.streamedNote',
    'audio.listenSurah',
    'audio.stopListening',
    'audio.reciterCount',
    'audio.notPlaying',
    'audio.verifiedSource',
    'audio.skipBack',
    'audio.skipForward',
    'audio.speed',
    'audio.speedValue',
    'audio.durationUnknown',
    'audio.errorUnavailableFor',
    'audio.searchReciter',
    'audio.noReciterMatches',
    'search.title',
    'search.hint',
    'search.surahMatches',
    'search.ayahMatches',
    'search.noResults',
    'search.noResultsBody',
    'search.clear',
    'search.startTyping',
    'search.resultsCount',
    'search.showingOf',
    'search.ayahLabel',
  ];
  for (final k in newKeys) {
    check('key present in both locales: $k',
        stringsAr.containsKey(k) && stringsEn.containsKey(k));
  }
  check('total key count', stringsAr.length == enKeys.length,
      'ar=${stringsAr.length} en=${stringsEn.length}');

  // ------------------------------------------------------------- dataset --
  section('dataset sanity');
  check('114 surahs', data.surahs.length == 114);
  check('6236 ayahs', data.meta.totalAyahs == 6236);
  check('604 pages', data.meta.totalPages == 604);

  // --------------------------------------------------------------- azkar --
  // The Azkar screen has its own search field backed by `AzkarController`,
  // which was switched to `arabicMatches` for the same reason as the Quran
  // search. `AzkarController` itself imports Flutter, so it cannot run here —
  // but the normalisation it delegates to can, against the real asset.
  section('azkar search (real asset)');
  final azkarFile = File('assets/data/azkar.json');
  check('azkar asset exists', azkarFile.existsSync());
  if (azkarFile.existsSync()) {
    final collected = <String>[];
    void collect(Object? node) {
      if (node is Map) {
        for (final value in node.values) {
          collect(value);
        }
      } else if (node is List) {
        for (final value in node) {
          collect(value);
        }
      } else if (node is String) {
        collected.add(node);
      }
    }

    collect(jsonDecode(azkarFile.readAsStringSync()));
    final arabic = collected
        .where((s) => s.runes.any((r) => r >= 0x0600 && r <= 0x06FF))
        .toList();
    check('arabic azkar strings present', arabic.length > 50, '${arabic.length}');

    /// Mimics a reader typing the text on an ordinary keyboard: harakat are
    /// never typed, and the Uthmani dagger alef has no key. A reader may or
    /// may not insert a full alef where the dagger sat, so both spellings are
    /// simulated — the dual-normalisation design must accept both.
    String asTyped(String value, {required bool daggerAsAlef}) {
      final buffer = StringBuffer();
      for (final rune in value.runes) {
        if (rune >= 0x064B && rune <= 0x0652) continue; // harakat
        if (rune == 0x0640) continue; // tatweel
        if (rune == daggerAlef) {
          if (daggerAsAlef) buffer.writeCharCode(0x0627);
          continue;
        }
        buffer.writeCharCode(rune);
      }
      return buffer.toString();
    }

    var plainOk = 0;
    var expandedOk = 0;
    var plainBad = 0;
    var expandedBad = 0;
    for (final raw in arabic) {
      final words = raw.split(RegExp(r'\s+'));
      if (words.length < 4) continue;
      final query = words.take(3).join(' ');
      if (normalizeArabic(query).length < 2) continue;

      if (arabicMatches(raw, asTyped(query, daggerAsAlef: false))) {
        plainOk++;
      } else {
        plainBad++;
      }
      if (arabicMatches(raw, asTyped(query, daggerAsAlef: true))) {
        expandedOk++;
      } else {
        expandedBad++;
      }
    }

    check('typed queries (dagger alef dropped) all match',
        plainOk > 30 && plainBad == 0, 'ok=$plainOk bad=$plainBad');
    check('typed queries (dagger alef as alef) all match',
        expandedOk > 30 && expandedBad == 0, 'ok=$expandedOk bad=$expandedBad');
    check(
      'gibberish matches nothing',
      !arabic.any((s) => arabicMatches(s, 'zxqvw')),
    );
    check(
      'a real phrase is findable',
      arabic.any((s) => arabicMatches(s, 'سبحان')),
    );
  }

  // ------------------------------------------------------------ timings --
  // Why the UI debounces: an ayah scan normalises all 6236 verses per query.
  section('search cost (informational)');
  final stopwatch = Stopwatch()..start();
  for (var i = 0; i < 5; i++) {
    searchVerses(data, 'الرحمن', limit: 60);
  }
  stopwatch.stop();
  final perScan = stopwatch.elapsedMicroseconds / 5 / 1000;
  stdout.writeln('  full ayah scan: ${perScan.toStringAsFixed(1)} ms per query');

  final countWatch = Stopwatch()..start();
  countVerseMatches(data, 'الرحمن');
  countWatch.stop();
  stdout.writeln(
      '  uncapped count: ${(countWatch.elapsedMicroseconds / 1000).toStringAsFixed(1)} ms');
  check('a full scan stays well under the 220 ms debounce window',
      perScan < 220, '${perScan.toStringAsFixed(1)} ms');

  stdout.writeln('\n${'=' * 58}');
  stdout.writeln('passed: $_passed    failed: $_failed');
  stdout.writeln('=' * 58);
  if (_failed > 0) exit(1);
}
