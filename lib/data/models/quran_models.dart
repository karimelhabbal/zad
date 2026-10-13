import 'dart:convert';

/// How the Quran is presented to the reader.
enum QuranDisplayMode {
  /// The app's own reflowable text reading view.
  text,

  /// The authentic 604-page Madinah Mushaf page images.
  mushaf;

  String get storageKey => name;

  static QuranDisplayMode fromStorage(String? value) {
    return QuranDisplayMode.values.firstWhere(
      (m) => m.name == value,
      orElse: () => QuranDisplayMode.text,
    );
  }
}

enum RevelationType { meccan, medinan }

RevelationType _revelationFrom(String? raw) =>
    (raw ?? '').toLowerCase().startsWith('med') || (raw ?? '') == 'Medinan'
        ? RevelationType.medinan
        : RevelationType.meccan;

/// A single ayah together with its verified Mushaf position.
class QuranVerse {
  const QuranVerse({
    required this.numberInSurah,
    required this.text,
    required this.page,
    required this.juz,
  });

  final int numberInSurah;
  final String text;

  /// 1..604 Madinah Mushaf page.
  final int page;

  /// 1..30.
  final int juz;

  factory QuranVerse.fromJson(Map<String, dynamic> json) => QuranVerse(
    numberInSurah: json['n'] as int,
    text: json['t'] as String,
    page: json['p'] as int,
    juz: json['j'] as int,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'n': numberInSurah,
    't': text,
    'p': page,
    'j': juz,
  };
}

class Surah {
  const Surah({
    required this.number,
    required this.fullName,
    required this.arabicName,
    required this.englishName,
    required this.englishTranslation,
    required this.revelationType,
    required this.ayahCount,
    required this.hasBismillah,
    required this.startPage,
    required this.startJuz,
    required this.verses,
  });

  final int number;

  /// e.g. "سُورَةُ ٱلْفَاتِحَةِ" (as supplied by the source).
  final String fullName;

  /// e.g. "الفاتحة" — used in lists and headers.
  final String arabicName;
  final String englishName;
  final String englishTranslation;
  final RevelationType revelationType;
  final int ayahCount;

  /// Whether the Basmalah heads this surah (all but At-Tawbah).
  final bool hasBismillah;
  final int startPage;
  final int startJuz;
  final List<QuranVerse> verses;

  bool get isMeccan => revelationType == RevelationType.meccan;

  QuranVerse verse(int numberInSurah) =>
      verses[numberInSurah.clamp(1, verses.length) - 1];

  factory Surah.fromJson(Map<String, dynamic> json) => Surah(
    number: json['n'] as int,
    fullName: json['name'] as String,
    arabicName: json['ar'] as String,
    englishName: json['en'] as String,
    englishTranslation: json['tr'] as String,
    revelationType: _revelationFrom(json['type'] as String?),
    ayahCount: json['count'] as int,
    hasBismillah: json['bismillah'] as bool? ?? true,
    startPage: json['startPage'] as int,
    startJuz: json['startJuz'] as int,
    verses: (json['verses'] as List<dynamic>)
        .map((v) => QuranVerse.fromJson(v as Map<String, dynamic>))
        .toList(growable: false),
  );
}

/// Verified page/juz mappings derived from the Madinah Mushaf page order.
class QuranMeta {
  const QuranMeta({
    required this.source,
    required this.riwayah,
    required this.totalSurahs,
    required this.totalAyahs,
    required this.totalPages,
    required this.juzStartPage,
    required this.pageToSurah,
    required this.surahStartPage,
    required this.surahStartJuz,
    required this.sajdaAyahs,
  });

  final String source;
  final String riwayah;
  final int totalSurahs;
  final int totalAyahs;
  final int totalPages;

  /// juz number -> first Mushaf page of that juz.
  final Map<int, int> juzStartPage;

  /// Mushaf page -> surah number that begins on that page.
  final Map<int, int> pageToSurah;
  final Map<int, int> surahStartPage;
  final Map<int, int> surahStartJuz;

  /// "surah:ayah" keys of the 15 prostration ayahs.
  final Set<String> sajdaAyahs;

  bool isSajda(int surah, int ayah) => sajdaAyahs.contains('$surah:$ayah');

  /// Page range covered by a juz (inclusive).
  (int, int) juzPageRange(int juz) {
    final start = juzStartPage[juz] ?? 1;
    final next = juzStartPage[juz + 1] ?? (totalPages + 1);
    return (start, next - 1);
  }

  factory QuranMeta.fromJson(Map<String, dynamic> json) {
    Map<int, int> intMap(String key) => (json[key] as Map<String, dynamic>).map(
      (k, v) => MapEntry(int.parse(k), v as int),
    );
    return QuranMeta(
      source: json['source'] as String,
      riwayah: json['riwayah'] as String? ?? '',
      totalSurahs: json['totalSurahs'] as int,
      totalAyahs: json['totalAyahs'] as int,
      totalPages: json['totalPages'] as int,
      juzStartPage: intMap('juzStartPage'),
      pageToSurah: intMap('pageToSurah'),
      surahStartPage: intMap('surahStartPage'),
      surahStartJuz: intMap('surahStartJuz'),
      sajdaAyahs: (json['sajdaAyahs'] as List<dynamic>)
          .map((e) => '${(e as Map<String, dynamic>)['s']}:${e['a']}')
          .toSet(),
    );
  }
}

/// The fully loaded Quran dataset.
class QuranData {
  QuranData({required this.meta, required this.surahs});

  final QuranMeta meta;
  final List<Surah> surahs;

  late final Map<int, Surah> byNumber = <int, Surah>{
    for (final s in surahs) s.number: s,
  };

  Surah surah(int number) => byNumber[number] ?? surahs.first;

  /// Surah that begins on [page], used to label Mushaf pages.
  Surah? surahStartingOnPage(int page) {
    final number = meta.pageToSurah[page];
    return number == null ? null : byNumber[number];
  }

  /// Surah containing [page] — the last surah that starts at or before it.
  Surah surahForPage(int page) {
    Surah current = surahs.first;
    for (final s in surahs) {
      if (s.startPage <= page) {
        current = s;
      } else {
        break;
      }
    }
    return current;
  }

  /// Juz containing [page].
  int juzForPage(int page) {
    var result = 1;
    for (var juz = 1; juz <= 30; juz++) {
      final start = meta.juzStartPage[juz];
      if (start != null && page >= start) result = juz;
    }
    return result;
  }

  /// Page that contains [surah]:[ayah].
  int pageOf(int surahNumber, int ayahNumber) =>
      surah(surahNumber).verse(ayahNumber).page;

  /// Deterministic "verse of the day" — stable for the whole calendar day.
  (Surah, QuranVerse) verseOfTheDay(DateTime date) {
    final dayIndex = DateTime(
      date.year,
      date.month,
      date.day,
    ).difference(DateTime(2024, 1, 1)).inDays;
    final total = meta.totalAyahs;
    var target = dayIndex % total;
    if (target < 0) target += total;
    for (final s in surahs) {
      if (target < s.verses.length) {
        return (s, s.verses[target]);
      }
      target -= s.verses.length;
    }
    return (surahs.last, surahs.last.verses.last);
  }

  static QuranData fromJsonString(String source) {
    final decoded = jsonDecode(source) as Map<String, dynamic>;
    return QuranData(
      meta: QuranMeta.fromJson(decoded['meta'] as Map<String, dynamic>),
      surahs: (decoded['surahs'] as List<dynamic>)
          .map((s) => Surah.fromJson(s as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

/// The reader's saved position. Survives restarts and is preserved when the
/// user switches between text and Mushaf modes.
class ReadingPosition {
  const ReadingPosition({
    required this.surah,
    required this.ayah,
    required this.page,
    required this.juz,
    required this.mode,
    required this.updatedAt,
  });

  final int surah;
  final int ayah;
  final int page;
  final int juz;
  final QuranDisplayMode mode;
  final DateTime updatedAt;

  /// Neutral starting point used when nothing has been saved yet.
  static ReadingPosition initial() => ReadingPosition(
    surah: 1,
    ayah: 1,
    page: 1,
    juz: 1,
    mode: QuranDisplayMode.text,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'surah': surah,
    'ayah': ayah,
    'page': page,
    'juz': juz,
    'mode': mode.storageKey,
    'updatedAt': updatedAt.toIso8601String(),
  };

  static ReadingPosition? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final surah = json['surah'] as int?;
      if (surah == null || surah < 1 || surah > 114) return null;
      return ReadingPosition(
        surah: surah,
        ayah: (json['ayah'] as int?) ?? 1,
        page: (json['page'] as int?) ?? 1,
        juz: (json['juz'] as int?) ?? 1,
        mode: QuranDisplayMode.fromStorage(json['mode'] as String?),
        updatedAt:
            DateTime.tryParse((json['updatedAt'] as String?) ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
    } catch (_) {
      // Corrupt or outdated payload — start clean rather than crash.
      return null;
    }
  }
}

class QuranBookmark {
  const QuranBookmark({
    required this.id,
    required this.surah,
    required this.ayah,
    required this.page,
    required this.juz,
    required this.createdAt,
  });

  final String id;
  final int surah;
  final int ayah;
  final int page;
  final int juz;
  final DateTime createdAt;

  String get key => '$surah:$ayah';

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'surah': surah,
    'ayah': ayah,
    'page': page,
    'juz': juz,
    'createdAt': createdAt.toIso8601String(),
  };

  static QuranBookmark? tryParse(Map<String, dynamic> json) {
    try {
      return QuranBookmark(
        id: json['id'] as String,
        surah: json['surah'] as int,
        ayah: json['ayah'] as int,
        page: json['page'] as int,
        juz: json['juz'] as int,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }
}
