import 'package:flutter/material.dart';

import '../../data/models/quran_models.dart';
import '../azkar/azkar_reader_screen.dart';
import '../prayer/prayer_times_screen.dart';
import '../qibla/qibla_screen.dart';
import '../quran/bookmarks_screen.dart';
import '../quran/mushaf_reader_screen.dart';
import '../quran/quran_reader_screen.dart';
import '../search/search_screen.dart';
import '../settings/settings_screen.dart';
import '../tasbeeh/dhikr_editor_screen.dart';

/// Centralised navigation entry points.
///
/// Keeping the routes in one place means every screen pushes the same,
/// fully-configured destination — there are no placeholder or dead-end routes.
class QuranNavigation {
  const QuranNavigation._();

  static Future<void> openReader(
    BuildContext context, {
    required int surah,
    required int ayah,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QuranReaderScreen(surahNumber: surah, ayahNumber: ayah),
      ),
    );
  }

  static Future<void> openMushaf(BuildContext context, {required int page}) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => MushafReaderScreen(page: page)),
    );
  }

  static Future<void> openBookmarks(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const BookmarksScreen()),
    );
  }

  /// Full-screen search over surah names and ayah text.
  static Future<void> openSearch(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SearchScreen()),
    );
  }

  static Future<void> openPrayerTimes(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PrayerTimesScreen()),
    );
  }

  static Future<void> openQibla(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const QiblaScreen()),
    );
  }

  static Future<void> openSettings(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );
  }

  static Future<void> openAzkarCategory(BuildContext context, String categoryId) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AzkarReaderScreen(categoryId: categoryId),
      ),
    );
  }

  static Future<void> openDhikrEditor(
    BuildContext context, {
    String? dhikrId,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DhikrEditorScreen(dhikrId: dhikrId),
      ),
    );
  }

  /// Shared helper for the reading-position aware entry point.
  static Future<void> openPosition(BuildContext context, ReadingPosition position) {
    return position.mode == QuranDisplayMode.mushaf
        ? openMushaf(context, page: position.page)
        : openReader(context, surah: position.surah, ayah: position.ayah);
  }
}
