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

  // ------------------------------------------------------- pages read today

  /// Distinct Mushaf pages the reader opened **today**.
  ///
  /// This exists because the home dashboard used to label the current page as
  /// "pages today" — on page 300 it claimed 300 pages had been read that day.
  /// The real figure is a set of pages actually visited, reset when the date
  /// changes, so the number on the dashboard can be trusted.
  Set<int> loadPagesToday() {
    final raw = _store.getJsonObject(LocalStore.keyPagesToday);
    final today = _dayKey(DateTime.now());
    if (raw == null || raw['d'] != today) return <int>{};
    final stored = raw['p'];
    if (stored is! List) return <int>{};
    return <int>{
      for (final value in stored)
        if (value is int) value,
    };
  }

  /// Adds [page] to today's set and persists it. Returns the updated set.
  Future<Set<int>> recordPageRead(int page) async {
    final pages = loadPagesToday();
    if (!pages.add(page.clamp(1, 604))) return pages;
    final sorted = pages.toList(growable: false)..sort();
    await _store.setJson(LocalStore.keyPagesToday, <String, Object>{
      'd': _dayKey(DateTime.now()),
      'p': sorted,
    });
    return pages;
  }

  /// Local calendar day key — deliberately not UTC, so "today" rolls over at
  /// the user's midnight rather than at midnight UTC.
  static String _dayKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

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
