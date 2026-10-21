import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Progress of an in-flight recitation download.
class RecitationDownload {
  const RecitationDownload({required this.received, required this.total});

  /// Bytes written so far.
  final int received;

  /// `Content-Length` reported by the server, or `null` when it sent none.
  final int? total;

  /// Fraction complete in `0..1`, or `null` when the total size is unknown.
  double? get fraction {
    final expected = total;
    if (expected == null || expected <= 0) return null;
    return (received / expected).clamp(0.0, 1.0);
  }
}

/// Supplies a recitation recording as a file on disk, downloading it once.
///
/// Declared as an interface so [AudioController] stays testable without
/// touching the network or the filesystem.
///
/// **Why this exists.** The platform players do not all agree on how to open a
/// *remote* URL. `audioplayers` on Windows hands the URL to Media Foundation's
/// `IMFSourceResolver::CreateObjectFromURL`, which resolves it through WinINet
/// and can fail — the reported `0x80072EE7`
/// (`ERROR_INTERNET_NAME_NOT_RESOLVED`) is the common one — while an ordinary
/// HTTP request from Dart to the very same URL succeeds. Fetching the bytes
/// ourselves and playing a local file sidesteps the OS media stack entirely.
abstract class RecitationCache {
  /// The local copy of [url] if a complete download is already on disk.
  Future<File?> lookup(String url);

  /// The local copy of [url], downloading it when it is not cached yet.
  ///
  /// Throws [RecitationDownloadException] when the file cannot be obtained.
  Future<File> fetch(
    String url, {
    void Function(RecitationDownload progress)? onProgress,
  });

  /// On-disk size of the local copy of [url], or `null` when it is not cached.
  ///
  /// The downloads manager needs per-recording sizes to show "downloaded" and
  /// to report how much space a reciter occupies; [sizeBytes] alone cannot
  /// answer either question.
  Future<int?> sizeOf(String url);

  /// Deletes the local copy of [url], if there is one.
  ///
  /// Used by the downloads manager. A file the player currently has open
  /// cannot be deleted on every platform, so a failure here is swallowed —
  /// the entry simply stays on disk and the list re-reads its real size.
  Future<void> remove(String url);

  /// Removes every cached recording.
  Future<void> clear();

  /// Approximate on-disk size of the cache, in bytes.
  Future<int> sizeBytes();
}

/// Disk-backed [RecitationCache].
class HttpRecitationCache implements RecitationCache {
  HttpRecitationCache({http.Client? client, this.maxBytes = defaultMaxBytes})
    : _client = client ?? http.Client();

  final http.Client _client;

  /// Upper bound on the cache, in bytes.
  ///
  /// Recitation files are large — a 128 kbps surah runs from ~1.3 MB
  /// (Al-Fatiha) to ~116 MB (Al-Baqarah) — so the cache is capped and the
  /// oldest recordings are evicted rather than letting it grow without limit.
  final int maxBytes;

  static const int defaultMaxBytes = 320 * 1024 * 1024;

  /// A download shorter than this is treated as a failure rather than a valid
  /// recording, so a truncated transfer can never be cached and replayed.
  static const int _minimumValidBytes = 8 * 1024;

  Directory? _dir;

  /// `<app support>/recitation`.
  Future<Directory> _directory() async {
    final existing = _dir;
    if (existing != null) return existing;
    final docs = await getApplicationSupportDirectory();
    final dir = Directory('${docs.path}${Platform.pathSeparator}recitation');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    _dir = dir;
    return dir;
  }

  /// Stable, filesystem-safe name derived from [url].
  ///
  /// The **last four** path segments are kept, e.g.
  /// `audio-surah__128__ar.alafasy__1.mp3`, so the name stays recognisable on
  /// disk instead of being an opaque hash.
  ///
  /// Four, not two: the two file shapes differ only in that leading segment —
  /// `audio/128/ar.alafasy/1.mp3` is ayah 1 and
  /// `audio-surah/128/ar.alafasy/1.mp3` is the whole of Al-Fatiha. A two-segment
  /// tail collapses both to `ar.alafasy__1.mp3`, which would make the player
  /// serve a cached surah file for a single ayah (and vice versa) and make the
  /// downloads list report the wrong size.
  static String fileNameFor(String url) {
    final segments = Uri.parse(url).pathSegments;
    final tail = segments.length >= 4
        ? segments.sublist(segments.length - 4).join('__')
        : segments.join('__');
    final safe = tail.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return safe.isEmpty ? 'recitation.mp3' : safe;
  }

  Future<File> _fileFor(String url) async {
    final dir = await _directory();
    return File('${dir.path}${Platform.pathSeparator}${fileNameFor(url)}');
  }

  @override
  Future<File?> lookup(String url) async {
    final file = await _fileFor(url);
    if (file.existsSync() && file.lengthSync() >= _minimumValidBytes) {
      return file;
    }
    return null;
  }

  @override
  Future<File> fetch(
    String url, {
    void Function(RecitationDownload progress)? onProgress,
  }) async {
    final cached = await lookup(url);
    if (cached != null) return cached;

    final target = await _fileFor(url);
    // Download into a sibling `.part` file and rename only once the transfer
    // finished, so a half-written file can never be mistaken for a complete
    // recording on the next lookup.
    final partial = File('${target.path}.part');

    try {
      final response = await _client.send(http.Request('GET', Uri.parse(url)));
      if (response.statusCode != 200) {
        throw RecitationDownloadException(
          'HTTP ${response.statusCode} for ${Uri.parse(url).host}',
        );
      }

      final total = response.contentLength;
      var received = 0;
      final sink = partial.openWrite();
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          onProgress?.call(
            RecitationDownload(received: received, total: total),
          );
        }
      } finally {
        await sink.flush();
        await sink.close();
      }

      if (received < _minimumValidBytes) {
        throw RecitationDownloadException(
          'Truncated download ($received bytes) for $url',
        );
      }

      if (target.existsSync()) target.deleteSync();
      final saved = await partial.rename(target.path);
      await _evictOldest();
      return saved;
    } on RecitationDownloadException {
      rethrow;
    } catch (e) {
      throw RecitationDownloadException('$e');
    } finally {
      // A successful rename has already moved the file away, so this only
      // cleans up after a failure.
      if (partial.existsSync()) {
        try {
          partial.deleteSync();
        } catch (_) {
          // Nothing useful to do — the OS still holds the handle.
        }
      }
    }
  }

  /// Deletes the least recently written recordings until the cache fits in
  /// [maxBytes].
  Future<void> _evictOldest() async {
    final dir = await _directory();
    final files = <File>[];
    var total = 0;
    for (final entity in dir.listSync()) {
      if (entity is! File || entity.path.endsWith('.part')) continue;
      files.add(entity);
      total += entity.lengthSync();
    }
    if (total <= maxBytes) return;

    files.sort(
      (a, b) => a.statSync().modified.compareTo(b.statSync().modified),
    );
    for (final file in files) {
      if (total <= maxBytes) break;
      try {
        final size = file.lengthSync();
        file.deleteSync();
        total -= size;
      } catch (_) {
        // A file the player currently has open cannot be evicted; skip it.
      }
    }
  }

  @override
  Future<int?> sizeOf(String url) async {
    final file = await _fileFor(url);
    if (!file.existsSync()) return null;
    final length = file.lengthSync();
    return length >= _minimumValidBytes ? length : null;
  }

  @override
  Future<void> remove(String url) async {
    final file = await _fileFor(url);
    try {
      if (file.existsSync()) file.deleteSync();
    } catch (_) {
      // Locked by the player — the list re-reads the real size afterwards.
    }
  }

  @override
  Future<void> clear() async {
    final dir = await _directory();
    if (!dir.existsSync()) return;
    for (final entity in dir.listSync()) {
      try {
        if (entity is File) entity.deleteSync();
      } catch (_) {
        // Ignore a file locked by the player.
      }
    }
  }

  @override
  Future<int> sizeBytes() async {
    final dir = await _directory();
    if (!dir.existsSync()) return 0;
    var bytes = 0;
    for (final entity in dir.listSync()) {
      if (entity is File) bytes += entity.lengthSync();
    }
    return bytes;
  }

  void dispose() => _client.close();
}

/// Raised when a recording could not be fetched to disk.
class RecitationDownloadException implements Exception {
  RecitationDownloadException(this.message);

  final String message;

  @override
  String toString() => 'RecitationDownloadException: $message';
}
