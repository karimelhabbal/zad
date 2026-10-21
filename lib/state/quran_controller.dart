import 'package:flutter/foundation.dart';

import '../data/models/quran_models.dart';
import '../data/repositories/quran_repository.dart';
import '../data/search/quran_search.dart' as search;

enum LoadState { idle, loading, ready, error }

/// Owns the Quran dataset, the reading position and bookmarks.
///
/// The reading position is shared between the text reader and the Mushaf
/// reader, so switching display modes never loses the user's place.
class QuranController extends ChangeNotifier {
  QuranController(this._repository);

  final QuranRepository _repository;

  LoadState _state = LoadState.idle;
  LoadState get state => _state;

  String? _error;
  String? get error => _error;

  QuranData? _data;
  QuranData? get data => _data;

  List<Surah> get surahs => _data?.surahs ?? const <Surah>[];

  QuranMeta? get meta => _data?.meta;

  bool get isReady => _state == LoadState.ready && _data != null;

  ReadingPosition _position = ReadingPosition.initial();
  ReadingPosition get position => _position;

  List<QuranBookmark> _bookmarks = const <QuranBookmark>[];
  List<QuranBookmark> get bookmarks => _bookmarks;

  /// Distinct Mushaf pages opened today. Drives the home dashboard's daily
  /// figure, which is a real count rather than "the page I am on".
  Set<int> _pagesToday = <int>{};
  int get pagesToday => _pagesToday.length;

  Future<void> initialise() async {
    if (_state == LoadState.loading) return;
    _state = LoadState.loading;
    notifyListeners();
    try {
      _data = await _repository.load();
      _position = _repository.loadPosition();
      _bookmarks = _repository.loadBookmarks();
      _pagesToday = _repository.loadPagesToday();
      _state = LoadState.ready;
    } catch (e) {
      _error = e.toString();
      _state = LoadState.error;
    }
    notifyListeners();
  }

  /// Re-reads persisted values (used after a full data reset).
  void reloadPersisted() {
    _position = _repository.loadPosition();
    _bookmarks = _repository.loadBookmarks();
    _pagesToday = _repository.loadPagesToday();
    notifyListeners();
  }

  // ------------------------------------------------------------- position --

  /// Saves the reading position. [mode] records which reader produced it so the
  /// app can reopen the same mode, without disturbing the shared page/ayah.
  Future<void> savePosition({
    required int surah,
    required int ayah,
    required int page,
    required int juz,
    required QuranDisplayMode mode,
  }) async {
    final next = ReadingPosition(
      surah: surah,
      ayah: ayah,
      page: page,
      juz: juz,
      mode: mode,
      updatedAt: DateTime.now(),
    );
    _position = next;
    notifyListeners();
    await _repository.savePosition(next);
    // Record the visit for today's counter. Only notify when the day's set
    // actually grew, so paging back and forth does not repaint the dashboard.
    final pages = await _repository.recordPageRead(page);
    if (pages.length != _pagesToday.length) {
      _pagesToday = pages;
      notifyListeners();
    }
  }

  bool get hasReadingHistory => _position.updatedAt.millisecondsSinceEpoch > 0;

  /// The surah the user last read, when available.
  Surah? get lastSurah {
    final data = _data;
    if (data == null || !hasReadingHistory) return null;
    return data.byNumber[_position.surah];
  }

  // ------------------------------------------------------------ bookmarks --

  bool isBookmarked(int surah, int ayah) =>
      _bookmarks.any((b) => b.surah == surah && b.ayah == ayah);

  Future<void> toggleBookmark({
    required int surah,
    required int ayah,
    required int page,
    required int juz,
  }) async {
    final exists = isBookmarked(surah, ayah);
    if (exists) {
      _bookmarks = _bookmarks
          .where((b) => !(b.surah == surah && b.ayah == ayah))
          .toList(growable: false);
    } else {
      final created = QuranBookmark(
        id: '${surah}_${ayah}_${DateTime.now().microsecondsSinceEpoch}',
        surah: surah,
        ayah: ayah,
        page: page,
        juz: juz,
        createdAt: DateTime.now(),
      );
      _bookmarks = <QuranBookmark>[created, ..._bookmarks];
    }
    notifyListeners();
    await _repository.saveBookmarks(_bookmarks);
  }

  Future<void> removeBookmark(QuranBookmark bookmark) async {
    _bookmarks = _bookmarks
        .where((b) => b.id != bookmark.id)
        .toList(growable: false);
    notifyListeners();
    await _repository.saveBookmarks(_bookmarks);
  }

  Future<void> clearBookmarks() async {
    _bookmarks = const <QuranBookmark>[];
    notifyListeners();
    await _repository.saveBookmarks(_bookmarks);
  }

  // --------------------------------------------------------------- search --
  //
  // The matching rules live in `lib/data/search/quran_search.dart` as pure
  // functions so they can be tested against the real asset without the app.

  /// Surah names (Arabic + English), the English translation, and numeric
  /// surah / juz / page references. Diacritic-insensitive.
  List<Surah> searchSurahs(String query) {
    final data = _data;
    if (data == null) return const <Surah>[];
    return search.searchSurahs(data, query);
  }

  /// The actual ayah text across the whole Qur'an, in Mushaf order.
  List<(Surah, QuranVerse)> searchVerses(String query, {int limit = 60}) {
    final data = _data;
    if (data == null) return const <(Surah, QuranVerse)>[];
    return search.searchVerses(data, query, limit: limit);
  }

  /// Total ayahs matching [query], ignoring [searchVerses]'s cap.
  int countVerseMatches(String query) {
    final data = _data;
    if (data == null) return 0;
    return search.countVerseMatches(data, query);
  }

  /// Finds the first ayah of a juz so the reader can jump straight to it.
  (Surah, QuranVerse)? firstVerseOfJuz(int juz) {
    final data = _data;
    if (data == null) return null;
    for (final surah in data.surahs) {
      for (final verse in surah.verses) {
        if (verse.juz == juz) return (surah, verse);
      }
    }
    return null;
  }

  /// Finds a verse by its Mushaf page (first verse on that page).
  (Surah, QuranVerse)? firstVerseOfPage(int page) {
    final data = _data;
    if (data == null) return null;
    for (final surah in data.surahs) {
      for (final verse in surah.verses) {
        if (verse.page == page) return (surah, verse);
      }
    }
    return null;
  }
}
