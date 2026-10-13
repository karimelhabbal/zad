import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/azkar_models.dart';
import '../models/quran_models.dart';
import 'local_store.dart';

/// Loads the bundled adhkar content and resolves Quranic references against
/// the verified Quran text, so devotional passages are never retyped.
class AzkarRepository {
  AzkarRepository(this._store);

  final LocalStore _store;

  static const String assetPath = 'assets/data/azkar.json';

  List<ZikrCategory>? _cached;

  Future<List<ZikrCategory>> load(QuranData quran) async {
    final cached = _cached;
    if (cached != null) return cached;
    final raw = await rootBundle.loadString(assetPath);
    final decoded = _decode(raw);
    final categories = _build(decoded, quran);
    _cached = categories;
    return categories;
  }

  List<ZikrCategory> get cachedCategories => _cached ?? const <ZikrCategory>[];

  Map<String, dynamic> _decode(String raw) {
    if (raw.isEmpty) return <String, dynamic>{'categories': <dynamic>[]};
    try {
      final value = jsonDecode(raw);
      return value is Map<String, dynamic>
          ? value
          : <String, dynamic>{'categories': <dynamic>[]};
    } catch (_) {
      return <String, dynamic>{'categories': <dynamic>[]};
    }
  }

  List<ZikrCategory> _build(Map<String, dynamic> decoded, QuranData quran) {
    final list = decoded['categories'];
    if (list is! List) return const <ZikrCategory>[];
    final out = <ZikrCategory>[];
    for (final entry in list) {
      if (entry is! Map<String, dynamic>) continue;
      final id = entry['id'] as String?;
      if (id == null) continue;
      final items = <ZikrItem>[];
      final rawItems = entry['items'];
      if (rawItems is List) {
        for (final rawItem in rawItems) {
          if (rawItem is! Map<String, dynamic>) continue;
          final item = _buildItem(rawItem, quran);
          if (item != null) items.add(item);
        }
      }
      out.add(
        ZikrCategory(
          id: id,
          icon: entry['icon'] as String? ?? 'beads',
          title:
              LocalizedText.tryParse(entry['title']) ??
              LocalizedText(ar: id, en: id),
          subtitle:
              LocalizedText.tryParse(entry['subtitle']) ??
              const LocalizedText(ar: '', en: ''),
          items: items,
        ),
      );
    }
    return out;
  }

  ZikrItem? _buildItem(Map<String, dynamic> raw, QuranData quran) {
    final id = raw['id'] as String?;
    if (id == null) return null;
    final count = (raw['count'] as int?) ?? 1;

    QuranRef? ref;
    final rawRef = raw['quranRef'];
    if (rawRef is Map<String, dynamic>) {
      try {
        ref = QuranRef.fromJson(rawRef);
      } catch (_) {
        ref = null;
      }
    }

    String text;
    String? surahName;
    if (ref != null) {
      final surah = quran.byNumber[ref.surah];
      if (surah == null) return null;
      final buffer = StringBuffer();
      for (var n = ref.fromAyah; n <= ref.toAyah; n++) {
        if (n < 1 || n > surah.verses.length) break;
        if (buffer.isNotEmpty) buffer.write(' ');
        buffer.write(surah.verse(n).text);
      }
      text = buffer.toString();
      surahName = surah.arabicName;
    } else {
      text = (raw['text'] as String?)?.trim() ?? '';
    }
    if (text.isEmpty) return null;

    return ZikrItem(
      id: id,
      text: text,
      count: count <= 0 ? 1 : count,
      source: LocalizedText.tryParse(raw['source']),
      virtue: LocalizedText.tryParse(raw['virtue']),
      quranRef: ref,
      surahName: surahName,
    );
  }

  // ------------------------------------------------------------ progress ---

  /// "categoryId:itemId" -> repetitions completed so far.
  Map<String, int> loadProgress() {
    final json = _store.getJsonObject(LocalStore.keyAzkarProgress);
    if (json == null) return <String, int>{};
    final out = <String, int>{};
    for (final entry in json.entries) {
      final value = entry.value;
      if (value is int && value >= 0) out[entry.key] = value;
    }
    return out;
  }

  Future<void> saveProgress(Map<String, int> progress) =>
      _store.setJson(LocalStore.keyAzkarProgress, progress);

  /// Stable storage key for one dhikr inside a category.
  static String progressKey(String categoryId, String itemId) =>
      '$categoryId:$itemId';
}
