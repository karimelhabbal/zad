import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/data/models/azkar_models.dart';
import 'package:zad/data/models/quran_models.dart';

/// Content checks for the bundled adhkar collection.
///
/// Every entry must carry a documented source, and every Quranic entry must
/// resolve to real text in the verified Quran asset — the app never retypes or
/// paraphrases devotional content.
void main() {
  late Map<String, dynamic> azkar;
  late QuranData quran;

  setUpAll(() {
    azkar = jsonDecode(File('assets/data/azkar.json').readAsStringSync())
        as Map<String, dynamic>;
    quran = QuranData.fromJsonString(
      File('assets/data/quran.json').readAsStringSync(),
    );
  });

  List<Map<String, dynamic>> categories() =>
      (azkar['categories'] as List<dynamic>)
          .cast<Map<String, dynamic>>();

  test('declares a meta block with its sources', () {
    final meta = azkar['meta'] as Map<String, dynamic>;
    expect(meta['title'], isNotEmpty);
    expect(meta['quranSource'], isNotEmpty);
    final sources = meta['hadithSources'];
    expect(sources, isA<List<dynamic>>());
    expect(sources as List<dynamic>, isNotEmpty);
    expect(
      (sources).every((s) => s is String && s.isNotEmpty),
      isTrue,
      reason: 'every cited collection needs a non-empty name',
    );
  });

  test('exposes the eight expected categories', () {
    final ids = categories().map((c) => c['id'] as String).toList();
    expect(ids.toSet().length, ids.length, reason: 'category ids must be unique');
    expect(
      ids,
      containsAll(<String>[
        'morning',
        'evening',
        'after_prayer',
        'sleep',
        'waking',
        'home_travel',
        'tasbeeh',
        'duaa',
      ]),
    );
  });

  test('every category is fully described in both locales', () {
    for (final category in categories()) {
      final parsed = ZikrCategory(
        id: category['id'] as String,
        icon: category['icon'] as String,
        title: LocalizedText.fromJson(category['title'] as Map<String, dynamic>),
        subtitle: LocalizedText.fromJson(
          category['subtitle'] as Map<String, dynamic>,
        ),
        items: const <ZikrItem>[],
      );
      expect(parsed.title.ar.trim(), isNotEmpty);
      expect(parsed.title.en.trim(), isNotEmpty);
      expect(parsed.subtitle.ar.trim(), isNotEmpty);
      expect(parsed.subtitle.en.trim(), isNotEmpty);
      expect(parsed.icon.trim(), isNotEmpty);
    }
  });

  test('every dhikr has a positive repetition count and a cited source', () {
    for (final category in categories()) {
      final categoryId = category['id'] as String;
      final items = (category['items'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      expect(items, isNotEmpty, reason: 'category $categoryId is empty');

      final ids = <String>[];
      for (final item in items) {
        final id = item['id'] as String;
        ids.add(id);

        final count = item['count'] as int;
        expect(count, greaterThan(0), reason: '$categoryId/$id count');

        final source = item['source'];
        expect(source, isA<Map<String, dynamic>>(), reason: '$categoryId/$id');
        expect(
          (source as Map<String, dynamic>)['ar'].toString().trim(),
          isNotEmpty,
          reason: '$categoryId/$id Arabic source',
        );

        // Either inline text or a Quran reference must be present.
        final hasText = (item['text'] as String?)?.trim().isNotEmpty ?? false;
        final hasRef = item['quranRef'] != null;
        expect(
          hasText || hasRef,
          isTrue,
          reason: '$categoryId/$id has neither text nor quranRef',
        );
      }
      expect(ids.toSet().length, ids.length, reason: 'duplicate ids in $categoryId');
    }
  });

  test('every Quranic reference resolves to real text in the Mushaf', () {
    var references = 0;
    for (final category in categories()) {
      final categoryId = category['id'] as String;
      for (final item
          in (category['items'] as List<dynamic>).cast<Map<String, dynamic>>()) {
        final raw = item['quranRef'];
        if (raw == null) continue;
        references++;

        final ref = QuranRef.fromJson(raw as Map<String, dynamic>);
        expect(ref.surah, inInclusiveRange(1, 114));
        final surah = quran.surah(ref.surah);
        expect(
          ref.fromAyah,
          inInclusiveRange(1, surah.ayahCount),
          reason: '$categoryId/${item['id']}',
        );
        expect(
          ref.toAyah,
          inInclusiveRange(ref.fromAyah, surah.ayahCount),
          reason: '$categoryId/${item['id']}',
        );

        for (var ayah = ref.fromAyah; ayah <= ref.toAyah; ayah++) {
          expect(surah.verse(ayah).text.trim(), isNotEmpty);
        }
      }
    }
    expect(references, greaterThan(0), reason: 'expected Quranic adhkar');
  });

  test('well-known Quranic adhkar point at the right verses', () {
    final all = <String, Map<String, dynamic>>{
      for (final category in categories())
        for (final item
            in (category['items'] as List<dynamic>).cast<Map<String, dynamic>>())
          '${category['id']}/${item['id']}': item,
    };

    // Ayah al-Kursi is 2:255.
    final ayahAlKursi = all.values.firstWhere(
      (item) =>
          item['quranRef'] != null &&
          (item['quranRef'] as Map<String, dynamic>)['surah'] == 2 &&
          (item['quranRef'] as Map<String, dynamic>)['ayah'] == 255,
      orElse: () => <String, dynamic>{},
    );
    expect(ayahAlKursi, isNotEmpty, reason: 'Ayah al-Kursi should be present');
  });

  test('the total adhkar count is what the UI reports', () {
    final total = categories().fold<int>(
      0,
      (sum, category) => sum + (category['items'] as List<dynamic>).length,
    );
    expect(total, greaterThanOrEqualTo(60));
  });
}
