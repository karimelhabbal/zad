import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Downloads and caches the authentic 604-page Madinah Mushaf page images.
///
/// The page assets are **not** fabricated or simulated with text: the app
/// fetches photographs of the printed Madinah Mushaf pages and stores them on
/// the device, so subsequent reads work offline.
///
/// **Primary source** — the Electronic Mushaf project at King Saud University
/// (`quran.ksu.edu.sa`), which describes itself as «نسخة حقيقية مصوّرة من صفحات
/// مصحف المدينة المنورة» — a real photographic copy of the Madinah Mushaf
/// pages. 622×917 PNG, ~135 KB per page, roughly 82 MB for the full set.
///
/// This replaced a text-rendered page set that merely *looked* like a Mushaf:
/// it was a different aspect ratio (1024×1656, 0.62 against the printed page's
/// 0.68), it left most of each page blank below the last line, and it was not
/// the printed page the app claimed to show. Anyone who had already downloaded
/// pages would have kept the old images, so the cache is now **edition-scoped**
/// and old pages are never served again (see [edition]).
///
/// **Fallback source** — the previous jsDelivr mirror, kept so that a page is
/// still readable if the university host is unreachable.
class MushafRepository {
  MushafRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const int totalPages = 604;

  /// Identifies the edition currently being cached.
  ///
  /// Pages are stored under a directory named after this value, so changing the
  /// source cannot silently keep serving the old edition's files. Bump it
  /// whenever the primary source changes.
  static const String edition = 'madani_ksu';

  static const String primarySourceLabel =
      'Madinah Mushaf — Electronic Mushaf, King Saud University (photographed '
      'print)';

  static const String fallbackSourceLabel =
      'Madinah Mushaf (Hafs) — jsDelivr mirror (rendered page)';

  static const String primarySourceUrl = 'https://quran.ksu.edu.sa/';
  static const String fallbackSourceUrl =
      'https://github.com/Kader4658/Quran_Pages';

  /// The photographed printed page. Note the unpadded number: this host serves
  /// `1.png`, not `001.png`.
  static String primaryUrl(int page) =>
      'https://quran.ksu.edu.sa/png_big/$page.png';

  static String fallbackUrl(int page) =>
      'https://cdn.jsdelivr.net/gh/Kader4658/Quran_Pages@main/'
      'page${_pad(page)}.png';

  static String _pad(int page) => page.toString().padLeft(3, '0');

  static String _fileName(int page) => '${_pad(page)}.png';

  Directory? _rootDir;
  Directory? _editionDir;

  /// `<app support>/mushaf` — holds one directory per cached edition.
  Future<Directory> _root() async {
    final existing = _rootDir;
    if (existing != null) return existing;
    final docs = await getApplicationSupportDirectory();
    final dir = Directory('${docs.path}${Platform.pathSeparator}mushaf');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    _rootDir = dir;
    return dir;
  }

  /// `<app support>/mushaf/<edition>` — where this edition's pages live.
  Future<Directory> _directory() async {
    final existing = _editionDir;
    if (existing != null) return existing;
    final root = await _root();
    final dir = Directory('${root.path}${Platform.pathSeparator}$edition');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    _editionDir = dir;
    return dir;
  }

  /// The cached file for [page] if this edition has already downloaded it.
  Future<File?> cachedPage(int page) async {
    if (page < 1 || page > totalPages) return null;
    final dir = await _directory();
    final file = File('${dir.path}${Platform.pathSeparator}${_fileName(page)}');
    if (file.existsSync() && file.lengthSync() > 1024) return file;
    return null;
  }

  /// Returns the page image, downloading and caching it when necessary.
  ///
  /// Throws [MushafDownloadException] when neither source could be reached.
  Future<File> ensurePage(int page, {bool forceRefresh = false}) async {
    if (page < 1 || page > totalPages) {
      throw MushafDownloadException('Page $page is out of range (1-$totalPages)');
    }
    if (!forceRefresh) {
      final cached = await cachedPage(page);
      if (cached != null) return cached;
    }
    final dir = await _directory();
    final target = File('${dir.path}${Platform.pathSeparator}${_fileName(page)}');

    final sources = <Uri>[Uri.parse(primaryUrl(page)), Uri.parse(fallbackUrl(page))];
    Object? lastError;
    for (final uri in sources) {
      try {
        final response = await _client
            .get(uri)
            .timeout(const Duration(seconds: 30));
        if (response.statusCode == 200 && response.bodyBytes.length > 1024) {
          await target.writeAsBytes(response.bodyBytes, flush: true);
          return target;
        }
        lastError = MushafDownloadException(
          'HTTP ${response.statusCode} for ${uri.host}',
        );
      } on TimeoutException catch (e) {
        lastError = e;
      } on SocketException catch (e) {
        lastError = e;
      } catch (e) {
        lastError = e;
      }
    }
    throw MushafDownloadException('$lastError');
  }

  /// Number of pages of the current edition already available offline.
  Future<int> downloadedCount() async {
    final dir = await _directory();
    if (!dir.existsSync()) return 0;
    var count = 0;
    for (final entity in dir.listSync()) {
      if (entity is File && entity.lengthSync() > 1024) count++;
    }
    return count;
  }

  /// Downloads every page, reporting progress through [onProgress].
  ///
  /// Pages already cached are skipped. [shouldCancel] allows the caller to
  /// abort the batch (for example when the screen is disposed).
  Future<int> downloadAll({
    void Function(int done, int total)? onProgress,
    bool Function()? shouldCancel,
    int concurrency = 6,
  }) async {
    final pending = <int>[];
    for (var page = 1; page <= totalPages; page++) {
      final cached = await cachedPage(page);
      if (cached == null) pending.add(page);
    }
    final alreadyDone = totalPages - pending.length;
    onProgress?.call(alreadyDone, totalPages);

    var completed = alreadyDone;
    var index = 0;
    var failures = 0;

    Future<void> worker() async {
      while (true) {
        if (shouldCancel?.call() ?? false) return;
        final current = index;
        if (current >= pending.length) return;
        index = current + 1;
        try {
          await ensurePage(pending[current]);
        } catch (_) {
          failures++;
        }
        completed++;
        onProgress?.call(completed, totalPages);
      }
    }

    await Future.wait<void>(
      List<Future<void>>.generate(concurrency.clamp(1, 12), (_) => worker()),
    );
    return failures;
  }

  /// Removes every downloaded page, including editions cached by earlier
  /// builds. Never touches user data outside the cache.
  Future<void> clearCache() async {
    final root = await _root();
    if (!root.existsSync()) return;
    for (final entity in root.listSync(recursive: true)) {
      try {
        if (entity is File) entity.deleteSync();
      } catch (_) {
        // Ignore a file locked by an active image provider.
      }
    }
  }

  /// Approximate on-disk size of the cache in bytes, across every edition.
  Future<int> cacheSizeBytes() async {
    final root = await _root();
    if (!root.existsSync()) return 0;
    var bytes = 0;
    for (final entity in root.listSync(recursive: true)) {
      if (entity is File) bytes += entity.lengthSync();
    }
    return bytes;
  }

  void dispose() => _client.close();
}

class MushafDownloadException implements Exception {
  MushafDownloadException(this.message);

  final String message;

  @override
  String toString() => 'MushafDownloadException: $message';
}
