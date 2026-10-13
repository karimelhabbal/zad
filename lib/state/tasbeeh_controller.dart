import 'package:flutter/foundation.dart';

import '../data/models/azkar_models.dart';
import '../data/repositories/azkar_repository.dart';
import '../data/repositories/tasbeeh_repository.dart';

/// Built-in adhkar available in the tasbeeh without any user setup.
class BuiltInDhikr {
  const BuiltInDhikr({
    required this.id,
    required this.text,
    required this.target,
    this.label,
    this.source,
  });

  final String id;
  final String text;
  final int target;
  final String? label;
  final LocalizedText? source;

  ActiveDhikr toActive() => ActiveDhikr(
    id: id,
    text: text,
    target: target,
    isCustom: false,
    label: label,
  );
}

/// Owns the digital tasbeeh: built-in and user-created adhkar, per-entry
/// counters, daily statistics and full CRUD for custom entries.
class TasbeehController extends ChangeNotifier {
  TasbeehController(this._repository);

  final TasbeehRepository _repository;

  static const List<int> presetTargets = <int>[33, 100];

  List<BuiltInDhikr> _builtIn = const <BuiltInDhikr>[];
  List<BuiltInDhikr> get builtIn => _builtIn;

  List<CustomDhikr> _custom = <CustomDhikr>[];
  List<CustomDhikr> get custom => List.unmodifiable(_custom);

  Map<String, int> _counters = <String, int>{};

  /// User-chosen counting goals for built-in adhkar (33 / 100 / unlimited).
  Map<String, int> _targets = <String, int>{};

  TasbeehStats _stats = const TasbeehStats(today: 0, total: 0, dayKey: '');

  String? _activeId;

  bool _initialised = false;
  bool get isInitialised => _initialised;

  int get totalToday => _stats.today;

  int get totalAllTime => _stats.total;

  /// Loads built-in adhkar from the bundled adhkar asset plus the persisted
  /// user data.
  Future<void> initialise(List<ZikrCategory> categories) async {
    _builtIn = _extractBuiltIn(categories);
    _custom = _repository.loadCustom();
    _counters = _repository.loadCounters();
    _targets = _repository.loadTargetOverrides();
    _stats = _repository.loadStats().rollTo(_todayKey());
    final storedActive = _repository.loadActiveId();
    _activeId = _isKnownId(storedActive) ? storedActive : null;
    _activeId ??= _defaultActiveId();
    _initialised = true;
    notifyListeners();
    await _repository.saveStats(_stats);
  }

  /// Re-reads persisted data (used after a full data reset).
  Future<void> reloadPersisted() async {
    _custom = _repository.loadCustom();
    _counters = _repository.loadCounters();
    _targets = _repository.loadTargetOverrides();
    _stats = _repository.loadStats().rollTo(_todayKey());
    _activeId = _defaultActiveId();
    notifyListeners();
  }

  static List<BuiltInDhikr> _extractBuiltIn(List<ZikrCategory> categories) {
    for (final category in categories) {
      if (category.id == 'tasbeeh') {
        return category.items
            .map(
              (item) => BuiltInDhikr(
                id: item.id,
                text: item.text,
                target: item.count,
                label: item.text.length <= 40 ? item.text : null,
                source: item.source,
              ),
            )
            .toList(growable: false);
      }
    }
    return const <BuiltInDhikr>[];
  }

  String _defaultActiveId() {
    if (_builtIn.isNotEmpty) return 'builtin:${_builtIn.first.id}';
    if (_custom.isNotEmpty) return 'custom:${_custom.first.id}';
    return '';
  }

  bool _isKnownId(String? id) {
    if (id == null || id.isEmpty) return false;
    return _allActive.any((d) => d.storageId == id);
  }

  // ------------------------------------------------------------- selection --

  List<ActiveDhikr> get _allActive => <ActiveDhikr>[
    ..._builtIn.map((e) => e.toActive()),
    ..._custom.map(
      (e) => ActiveDhikr(
        id: e.id,
        text: e.text,
        target: e.target,
        isCustom: true,
      ),
    ),
  ];

  List<ActiveDhikr> get allDhikr => _allActive;

  ActiveDhikr? get active {
    final id = _activeId;
    if (id == null) return null;
    for (final item in _allActive) {
      if (item.storageId == id) return item;
    }
    return _allActive.isEmpty ? null : _allActive.first;
  }

  Future<void> selectDhikr(String storageId) async {
    if (!_isKnownId(storageId)) return;
    _activeId = storageId;
    notifyListeners();
    await _repository.saveActiveId(storageId);
  }

  // ------------------------------------------------------------- counting ---

  int countFor(ActiveDhikr dhikr) => _counters[dhikr.storageId] ?? 0;

  int countForStorageId(String storageId) => _counters[storageId] ?? 0;

  /// The counting goal for [dhikr]: the user's override when set, otherwise the
  /// documented count. `0` means unlimited (the "∞" option).
  int targetFor(ActiveDhikr dhikr) {
    if (dhikr.isCustom) {
      return customById(dhikr.id)?.target ?? dhikr.target;
    }
    return _targets[dhikr.storageId] ?? dhikr.target;
  }

  /// Sets the counting goal for [dhikr]. Pass `0` for unlimited.
  ///
  /// Custom adhkar keep the goal on the entry itself; built-in adhkar store an
  /// override so their documented count in the asset is never altered.
  Future<void> setTargetFor(ActiveDhikr dhikr, int target) async {
    final safe = target < 0 ? 0 : target;
    if (dhikr.isCustom) {
      await updateCustom(
        id: dhikr.id,
        text: customById(dhikr.id)?.text ?? dhikr.text,
        target: safe == 0 ? 1 : safe,
      );
      return;
    }
    _targets = <String, int>{..._targets, dhikr.storageId: safe};
    notifyListeners();
    await _repository.saveTargetOverrides(_targets);
  }

  int get activeCount {
    final dhikr = active;
    return dhikr == null ? 0 : countFor(dhikr);
  }

  int get activeTarget {
    final dhikr = active;
    return dhikr == null ? 0 : targetFor(dhikr);
  }

  /// Completed rounds for the active dhikr.
  int get activeLaps {
    final target = activeTarget;
    if (target <= 0) return 0;
    return activeCount ~/ target;
  }

  double get activeProgress {
    final target = activeTarget;
    if (target <= 0) return 0;
    return (activeCount / target).clamp(0.0, 1.0);
  }

  /// Increments the active dhikr. Returns `true` when the target is reached.
  Future<bool> increment() async {
    final dhikr = active;
    if (dhikr == null) return false;
    final target = targetFor(dhikr);
    final next = (countFor(dhikr) + 1).clamp(0, 1 << 31);
    _counters = <String, int>{..._counters, dhikr.storageId: next};
    _stats = _stats.rollTo(_todayKey()).increment();
    notifyListeners();
    await _repository.saveCounters(_counters);
    await _repository.saveStats(_stats);
    return target > 0 && next % target == 0;
  }

  /// Resets **only** the active dhikr's counter, leaving every other entry
  /// untouched.
  Future<void> resetActiveCounter() async {
    final dhikr = active;
    if (dhikr == null) return;
    final removed = countFor(dhikr);
    final next = Map<String, int>.from(_counters)..remove(dhikr.storageId);
    _counters = next;
    _stats = _stats.rollTo(_todayKey()).withDelta(-removed);
    notifyListeners();
    await _repository.saveCounters(_counters);
    await _repository.saveStats(_stats);
  }

  /// Resets one specific entry by its storage id.
  Future<void> resetCounterFor(String storageId) async {
    if (!_counters.containsKey(storageId)) return;
    final removed = _counters[storageId] ?? 0;
    _counters = Map<String, int>.from(_counters)..remove(storageId);
    _stats = _stats.rollTo(_todayKey()).withDelta(-removed);
    notifyListeners();
    await _repository.saveCounters(_counters);
    await _repository.saveStats(_stats);
  }

  // ------------------------------------------------------------ custom CRUD --

  /// Validates dhikr input, returning an i18n key or `null` when valid.
  String? validate({required String text, required int? target}) =>
      _repository.validate(text: text, target: target);

  /// Creates a custom dhikr and makes it active. Returns the validation error
  /// key, or `null` on success.
  Future<String?> addCustom({required String text, required int? target}) async {
    final error = validate(text: text, target: target);
    if (error != null) return error;
    final created = _repository.create(text: text, target: target!);
    if (created == null) return 'tasbeeh.errorTarget';
    _custom = <CustomDhikr>[..._custom, created];
    _activeId = 'custom:${created.id}';
    notifyListeners();
    await _repository.saveCustom(_custom);
    await _repository.saveActiveId(_activeId!);
    return null;
  }

  /// Updates an existing custom dhikr. Its saved counter is preserved.
  Future<String?> updateCustom({
    required String id,
    required String text,
    required int? target,
  }) async {
    final error = validate(text: text, target: target);
    if (error != null) return error;
    final index = _custom.indexWhere((e) => e.id == id);
    if (index == -1) return 'tasbeeh.errorTarget';
    final updated = _custom[index].copyWith(text: text.trim(), target: target);
    _custom = <CustomDhikr>[..._custom]..[index] = updated;
    notifyListeners();
    await _repository.saveCustom(_custom);
    return null;
  }

  /// Deletes a custom dhikr together with its own counter only.
  Future<void> deleteCustom(String id) async {
    _custom = _custom.where((e) => e.id != id).toList(growable: false);
    final storageId = 'custom:$id';
    _counters = Map<String, int>.from(_counters)..remove(storageId);
    if (_activeId == storageId) {
      _activeId = _defaultActiveId();
      await _repository.saveActiveId(_activeId!);
    }
    notifyListeners();
    await _repository.saveCustom(_custom);
    await _repository.saveCounters(_counters);
  }

  CustomDhikr? customById(String id) {
    for (final item in _custom) {
      if (item.id == id) return item;
    }
    return null;
  }

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
}

/// Re-exported so the UI can format progress without importing the repository.
typedef TasbeehStatistics = TasbeehStats;

/// Kept so callers can reference the progress key helper without importing the
/// repository directly.
String azkarProgressKey(String categoryId, String itemId) =>
    AzkarRepository.progressKey(categoryId, itemId);
