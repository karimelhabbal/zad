import 'dart:async';

import 'package:qcf_quran_plus/qcf_quran_plus.dart';
// The package renders nothing until its page repository has been loaded, but it
// does not re-export the repository from its public barrel file. Importing the
// source file directly is the only way to drive the load page-by-page; the
// alternative public entry point (`QcfFontLoader.setupFontsAtStartup`) loads
// and registers all 604 pages × 5 font variants before the first frame, which
// costs tens of seconds of startup and hundreds of megabytes of memory.
// ignore: implementation_imports
import 'package:qcf_quran_plus/src/widgets/quran_page/quran_repository.dart';

/// Loads everything the Mushaf reader needs to draw a page as text.
///
/// Two separate things have to be ready before a page can be shown:
///
/// * **Page data** — the parsed line/word layout of all 604 pages. It is built
///   once, off the main isolate, and lives for the whole app session.
/// * **Page font** — the QCF font for one specific page. Each page has its own
///   font, so only the pages the reader is about to see are loaded, plus a
///   small ring around them.
///
/// Everything here is bundled in the app: no network request is made, ever.
class MushafFontService {
  const MushafFontService._();

  /// The Madinah Mushaf has 604 pages in this edition.
  static const int totalPages = 604;

  static Future<void>? _dataLoad;

  /// Whether the page layout data is in memory and the reader can be built.
  static bool get isDataReady => QuranRepository.instance.isReady;

  /// Loads the page layout data once per session.
  static Future<void> ensureData() {
    if (QuranRepository.instance.isReady) return Future<void>.value();
    return _dataLoad ??= QuranRepository.instance.ensureLoaded(totalPages);
  }

  /// Makes [page] drawable: page data plus that page's QCF font.
  static Future<void> ensurePage(int page) async {
    final target = page.clamp(1, totalPages);
    await ensureData();
    await QcfFontLoader.ensureFontLoaded(target);
  }

  /// Warms the pages the reader is most likely to swipe to next.
  ///
  /// Fire-and-forget on purpose: a failed preload must never surface as an
  /// error, because the page itself will retry the load when it is shown.
  static void preloadAround(int page, {int radius = 3}) {
    unawaited(
      ensureData().then((_) async {
        try {
          await QcfFontLoader.preloadPages(
            page.clamp(1, totalPages),
            radius: radius,
          );
        } catch (_) {
          // Preloading is an optimisation; ignore and let the page load lazily.
        }
      }),
    );
  }

  /// Whether the font for [page] is already registered with the engine.
  static bool isPageReady(int page) => QcfFontLoader.isFontLoaded(page);
}
