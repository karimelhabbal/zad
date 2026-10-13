import 'package:flutter/foundation.dart';

import '../core/utils/arabic_text.dart';
import '../data/models/azkar_models.dart';
import '../data/models/quran_models.dart';
import '../data/repositories/azkar_repository.dart';
import 'quran_controller.dart';

/// Owns the adhkar content and the user's reading progress through each wird.
///
/// Progress is stored per dhikr as a repetition count, so a dhikr with a
/// required count of 33 is only "completed" once it has been counted 33 times,
/// and the counter survives app restarts.
class AzkarController extends ChangeNotifier {
  AzkarController(this._repository);

  final AzkarRepository _repository;

  LoadState _state = LoadState.idle;
  LoadState get state => _state;

  String? _error;
  String? get error => _error;

  List<ZikrCategory> _categories = const <ZikrCategory>[];
  List<ZikrCategory> get categories => _categories;

  Map<String, int> _progress = <String, int>{};

  bool get isReady => _state == LoadState.ready;

  Future<void> initialise(QuranData quran) async {
    if (_state == LoadState.loading || _state == LoadState.ready) return;
    _state = LoadState.loading;
    notifyListeners();
    try {
      _categories = await _repository.load(quran);
      _progress = _repository.loadProgress();
      _state = LoadState.ready;
    } catch (e) {
      _error = e.toString();
      _state = LoadState.error;
    }
    notifyListeners();
  }

  /// Re-reads persisted progress (used after a full data reset).
  void reloadPersisted() {
    _progress = _repository.loadProgress();
    notifyListeners();
  }

  ZikrCategory? categoryById(String id) {
    for (final category in _categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  // -------------------------------------------------------------- progress --

  int repetitionsOf(String categoryId, ZikrItem item) =>
      _progress[AzkarRepository.progressKey(categoryId, item.id)] ?? 0;

  bool isCompleted(String categoryId, ZikrItem item) =>
      repetitionsOf(categoryId, item) >= item.count;

  int completedCount(ZikrCategory category) =>
      category.items.where((item) => isCompleted(category.id, item)).length;

  double categoryProgress(ZikrCategory category) {
    if (category.items.isEmpty) return 0;
    return completedCount(category) / category.items.length;
  }

  /// Total completed adhkar across every category.
  int get totalCompleted => _categories.fold<int>(
    0,
    (sum, category) => sum + completedCount(category),
  );

  int get totalItems => _categories.fold<int>(
    0,
    (sum, category) => sum + category.items.length,
  );

  /// The next dhikr the user has not finished, used by "continue reading".
  (ZikrCategory, int)? nextUnfinishedIn(ZikrCategory category) {
    for (var i = 0; i < category.items.length; i++) {
      if (!isCompleted(category.id, category.items[i])) return (category, i);
    }
    return null;
  }

  /// The first category with unfinished adhkar.
  (ZikrCategory, int)? get firstUnfinished {
    for (final category in _categories) {
      final next = nextUnfinishedIn(category);
      if (next != null) return next;
    }
    return null;
  }

  // ------------------------------------------------------------- mutations --

  /// Advances one repetition of [item]. Returns `true` when the dhikr has just
  /// reached its required count.
  Future<bool> countOnce(String categoryId, ZikrItem item) async {
    final key = AzkarRepository.progressKey(categoryId, item.id);
    final current = _progress[key] ?? 0;
    if (current >= item.count) return false;
    final next = current + 1;
    _progress = <String, int>{..._progress, key: next};
    notifyListeners();
    await _repository.saveProgress(_progress);
    return next >= item.count;
  }

  /// Sets an explicit repetition count (used by the reader's +/- controls).
  Future<void> setRepetitions(
    String categoryId,
    ZikrItem item,
    int value,
  ) async {
    final clamped = value.clamp(0, item.count);
    final key = AzkarRepository.progressKey(categoryId, item.id);
    _progress = <String, int>{..._progress, key: clamped};
    notifyListeners();
    await _repository.saveProgress(_progress);
  }

  /// Marks a dhikr complete in one tap (for count == 1 items).
  Future<void> markCompleted(String categoryId, ZikrItem item) =>
      setRepetitions(categoryId, item, item.count);

  /// Clears progress for a single category only — other categories keep their
  /// progress.
  Future<void> resetCategory(String categoryId) async {
    final prefix = '$categoryId:';
    final next = Map<String, int>.from(_progress)
      ..removeWhere((key, _) => key.startsWith(prefix));
    _progress = next;
    notifyListeners();
    await _repository.saveProgress(_progress);
  }

  /// Clears all adhkar progress.
  Future<void> resetAll() async {
    _progress = <String, int>{};
    notifyListeners();
    await _repository.saveProgress(_progress);
  }

  /// Searches dhikr text and sources within a category.
  ///
  /// Uses the same diacritic- and dagger-alef-insensitive matching as the
  /// Qur'an search, so typing an unvocalised word still matches the fully
  /// vocalised text.
  List<ZikrItem> search(ZikrCategory category, String query) {
    final q = query.trim();
    if (arabicForms(q).isEmpty) return category.items;
    return category.items.where((item) {
      if (arabicMatches(item.text, q)) return true;
      final source = item.source;
      if (source != null &&
          (arabicMatches(source.ar, q) ||
              source.en.toLowerCase().contains(q.toLowerCase()))) {
        return true;
      }
      return false;
    }).toList(growable: false);
  }
}
