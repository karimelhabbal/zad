import 'package:flutter/foundation.dart';

import '../data/models/reciter.dart';
import '../data/repositories/recitation_cache.dart';

/// Owns the "audio downloads" screen: which surahs of the selected reciter are
/// already on disk, how much space they take, and the download / delete
/// actions themselves.
///
/// **Same folder as the player.** It is handed the very [RecitationCache] the
/// [AudioController] plays from, so a surah downloaded here is played from disk
/// the next time the user listens — offline, with no second copy on the device
/// and no separate "downloads" directory to keep in sync.
///
/// **Surah granularity.** Downloads mirror what the CDN serves as one file per
/// surah (`audio-surah/128/{reciter}/{surah}.mp3`). Ayah files are a few
/// hundred kilobytes each and there are 6236 of them, so they are streamed
/// instead of stored — downloading them one by one would be a worse experience
/// than the stream it replaces.
class AudioDownloadsController extends ChangeNotifier {
  AudioDownloadsController(this._cache);

  final RecitationCache _cache;

  /// Surahs in the Qur'an, in Mushaf order.
  static const int surahCount = 114;

  QuranReciter _reciter = QuranReciters.defaultReciter;
  QuranReciter get reciter => _reciter;

  bool _scanning = false;

  /// True while the cache is being read, so the list can show a spinner
  /// instead of 114 "not downloaded" rows that are about to change.
  bool get isScanning => _scanning;

  /// `url -> bytes on disk`. Absence means "not downloaded".
  final Map<String, int> _sizes = <String, int>{};

  /// `url -> fraction in 0..1`, or `null` while the total size is unknown.
  /// Presence means a download is running.
  final Map<String, double?> _progress = <String, double?>{};

  int _totalBytes = 0;
  int get totalBytes => _totalBytes;

  int get downloadedCount => _sizes.length;

  String _url(int surah) => _reciter.surahAudioUrl(surah);

  bool isDownloaded(int surah) => _sizes.containsKey(_url(surah));

  int? sizeOf(int surah) => _sizes[_url(surah)];

  bool isDownloading(int surah) => _progress.containsKey(_url(surah));

  double? progressOf(int surah) => _progress[_url(surah)];

  /// Reads the cache for [reciter] — switching reciter starts from a clean
  /// slate, because another voice is a different set of files.
  Future<void> refresh([QuranReciter? reciter]) async {
    if (reciter != null && reciter.id != _reciter.id) {
      _reciter = reciter;
      _sizes.clear();
      _progress.clear();
      _totalBytes = 0;
    }
    _scanning = true;
    notifyListeners();

    final sizes = <String, int>{};
    var total = 0;
    for (var surah = 1; surah <= surahCount; surah++) {
      final url = _url(surah);
      try {
        final bytes = await _cache.sizeOf(url);
        if (bytes != null) {
          sizes[url] = bytes;
          total += bytes;
        }
      } catch (_) {
        // An unreadable cache entry is reported as "not downloaded" rather
        // than failing the whole scan.
      }
    }

    _sizes
      ..clear()
      ..addAll(sizes);
    _totalBytes = total;
    _scanning = false;
    notifyListeners();
  }

  /// Downloads one surah. Returns `false` when the transfer failed — the caller
  /// shows the reason, this class does not own the strings.
  Future<bool> download(int surah) async {
    final url = _url(surah);
    if (_progress.containsKey(url) || _sizes.containsKey(url)) return true;

    // `null` fraction = "running, size not known yet"; the row shows an
    // indeterminate ring until the server reports a length.
    _progress[url] = null;
    notifyListeners();

    try {
      final file = await _cache.fetch(
        url,
        onProgress: (progress) {
          _progress[url] = progress.fraction;
          notifyListeners();
        },
      );
      _progress.remove(url);
      final bytes = await _cache.sizeOf(url) ?? file.lengthSync();
      _sizes[url] = bytes;
      _totalBytes += bytes;
      notifyListeners();
      return true;
    } catch (_) {
      _progress.remove(url);
      notifyListeners();
      return false;
    }
  }

  /// Deletes one surah from disk. Returns `false` when the file is still there
  /// afterwards — on some platforms the player holds it open.
  Future<bool> remove(int surah) async {
    final url = _url(surah);
    await _cache.remove(url);
    final remaining = await _cache.sizeOf(url);
    if (remaining != null) {
      // Locked by the player: report it rather than claiming success and
      // letting the row reappear on the next scan.
      _sizes[url] = remaining;
      notifyListeners();
      return false;
    }
    final bytes = _sizes.remove(url);
    if (bytes != null && _totalBytes >= bytes) {
      _totalBytes -= bytes;
    } else if (bytes != null) {
      _totalBytes = 0;
    }
    notifyListeners();
    return true;
  }

  /// Deletes every downloaded recording, for every reciter — the cache is a
  /// single folder, so "delete all" cannot mean "delete this reciter only".
  Future<void> clearAll() async {
    await _cache.clear();
    _sizes.clear();
    _progress.clear();
    _totalBytes = 0;
    notifyListeners();
  }
}
