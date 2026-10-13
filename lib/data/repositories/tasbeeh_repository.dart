import 'dart:math';

import '../models/azkar_models.dart';
import 'local_store.dart';

/// Persistence for the digital tasbeeh: user-created adhkar, per-dhikr
/// counters, the active selection and daily statistics.
///
/// Every counter is stored under its own key inside a single map, so editing or
/// deleting one entry can never reset an unrelated counter.
class TasbeehRepository {
  TasbeehRepository(this._store);

  final LocalStore _store;

  final Random _random = Random();

  // -------------------------------------------------------- custom adhkar ---

  List<CustomDhikr> loadCustom() {
    final raw = _store.getJsonList(LocalStore.keyCustomDhikr);
    if (raw == null) return <CustomDhikr>[];
    final out = <CustomDhikr>[];
    for (final entry in raw) {
      final parsed = CustomDhikr.tryParse(entry);
      if (parsed != null) out.add(parsed);
    }
    out.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return out;
  }

  Future<void> saveCustom(List<CustomDhikr> items) => _store.setJson(
    LocalStore.keyCustomDhikr,
    items.map((e) => e.toJson()).toList(growable: false),
  );

  /// Creates a validated entry. Returns `null` when the input is invalid.
  CustomDhikr? create({required String text, required int target}) {
    final validation = validate(text: text, target: target);
    if (validation != null) return null;
    return CustomDhikr(
      id: _newId(),
      text: text.trim(),
      target: target,
      createdAt: DateTime.now(),
    );
  }

  /// Validates dhikr input. Returns an i18n key on failure, `null` when valid.
  String? validate({required String text, required int? target}) {
    if (text.trim().isEmpty) return 'tasbeeh.errorEmptyText';
    if (target == null || target <= 0) return 'tasbeeh.errorTarget';
    if (target > 100000) return 'tasbeeh.errorTargetTooLarge';
    return null;
  }

  String _newId() {
    final stamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final salt = _random.nextInt(1 << 20).toRadixString(36);
    return 'dh_${stamp}_$salt';
  }

  // ------------------------------------------------------------- counters ---

  Map<String, int> loadCounters() {
    final json = _store.getJsonObject(LocalStore.keyTasbeehCounters);
    if (json == null) return <String, int>{};
    final out = <String, int>{};
    for (final entry in json.entries) {
      final value = entry.value;
      if (value is int && value >= 0) out[entry.key] = value;
    }
    return out;
  }

  Future<void> saveCounters(Map<String, int> counters) =>
      _store.setJson(LocalStore.keyTasbeehCounters, counters);

  // --------------------------------------------------------------- active ---

  String? loadActiveId() => _store.getString(LocalStore.keyActiveDhikr);

  Future<void> saveActiveId(String id) =>
      _store.setString(LocalStore.keyActiveDhikr, id);

  // -------------------------------------------------------------- targets ---

  /// Per-dhikr target overrides chosen by the user (33 / 100 / unlimited).
  ///
  /// Built-in adhkar keep their documented count in the asset; an override here
  /// only changes the counting goal the user is working towards. Custom adhkar
  /// store their target on the entry itself.
  Map<String, int> loadTargetOverrides() {
    final json = _store.getJsonObject(LocalStore.keyTasbeehTargets);
    if (json == null) return <String, int>{};
    final out = <String, int>{};
    for (final entry in json.entries) {
      final value = entry.value;
      if (value is int && value >= 0) out[entry.key] = value;
    }
    return out;
  }

  Future<void> saveTargetOverrides(Map<String, int> targets) =>
      _store.setJson(LocalStore.keyTasbeehTargets, targets);

  // ---------------------------------------------------------------- stats ---

  TasbeehStats loadStats() {
    final json = _store.getJsonObject(LocalStore.keyTasbeehStats);
    final today = _todayKey();
    if (json == null) {
      return TasbeehStats(today: 0, total: 0, dayKey: today);
    }
    final storedDay = json['dayKey'] as String? ?? today;
    final total = (json['total'] as int?) ?? 0;
    final dayTotal = storedDay == today ? ((json['today'] as int?) ?? 0) : 0;
    return TasbeehStats(today: dayTotal, total: total, dayKey: today);
  }

  Future<void> saveStats(TasbeehStats stats) => _store.setJson(
    LocalStore.keyTasbeehStats,
    <String, dynamic>{
      'dayKey': stats.dayKey,
      'today': stats.today,
      'total': stats.total,
    },
  );

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
}

class TasbeehStats {
  const TasbeehStats({
    required this.today,
    required this.total,
    required this.dayKey,
  });

  final int today;
  final int total;
  final String dayKey;

  /// Rolls the daily counter over when the calendar day changes.
  TasbeehStats rollTo(String dayKey) => dayKey == this.dayKey
      ? this
      : TasbeehStats(today: 0, total: total, dayKey: dayKey);

  TasbeehStats increment() => TasbeehStats(
    today: today + 1,
    total: total + 1,
    dayKey: dayKey,
  );

  TasbeehStats withDelta(int delta) => TasbeehStats(
    today: (today + delta).clamp(0, 1 << 31),
    total: (total + delta).clamp(0, 1 << 31),
    dayKey: dayKey,
  );
}
