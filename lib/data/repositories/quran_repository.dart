import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/quran_models.dart';
import 'local_store.dart';

/// Loads the bundled, verified Quran text and owns all Quran-related
/// persistence (last reading position + bookmarks).
class QuranRepository {
  QuranRepository(this._store);

  final LocalStore _store;

  static const String assetPath = 'assets/data/quran.json';

  QuranData? _cached;

  /// Loads (and caches) the Quran dataset from the bundled asset.
  Future<QuranData> load() async {
    final cached = _cached;
    if (cached != null) return cached;
    final raw = await rootBundle.loadString(assetPath);
    final data = QuranData.fromJsonString(raw);
    _cached = data;
    return data;
  }

  /// Synchronous accessor used after [load] has completed at startup.
  QuranData? get dataOrNull => _cached;

  // ------------------------------------------------------- reading position

  ReadingPosition loadPosition() =>
      ReadingPosition.tryParse(_store.getString(LocalStore.keyReadingPosition)) ??
      ReadingPosition.initial();

  Future<void> savePosition(ReadingPosition position) =>
      _store.setString(
        LocalStore.keyReadingPosition,
        jsonEncode(position.toJson()),
      );

  // ------------------------------------------------------------- bookmarks

  List<QuranBookmark> loadBookmarks() {
    final raw = _store.getJsonList(LocalStore.keyBookmarks);
    if (raw == null) return const <QuranBookmark>[];
    final out = <QuranBookmark>[];
    for (final entry in raw) {
      if (entry is! Map<String, dynamic>) continue;
      final parsed = QuranBookmark.tryParse(entry);
      if (parsed != null) out.add(parsed);
    }
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }

  Future<void> saveBookmarks(List<QuranBookmark> bookmarks) => _store.setJson(
    LocalStore.keyBookmarks,
    bookmarks.map((b) => b.toJson()).toList(growable: false),
  );
}
