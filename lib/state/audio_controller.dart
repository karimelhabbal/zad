import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart' as ap;
// `ChangeNotifier` comes through `widgets.dart`, which re-exports it from
// `foundation.dart`; importing both would be an `unnecessary_import`.
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../data/models/reciter.dart';
import '../data/repositories/recitation_cache.dart';

/// Playback lifecycle exposed to the UI.
///
/// [loading] covers the whole "check the stream, then prepare it" window — for
/// a long surah this is the same period the OS spends buffering, so the UI
/// shows a spinner rather than pretending to be playing.
enum RecitationStatus { idle, loading, playing, paused, completed, error }

/// What the user asked to hear.
///
/// The CDN serves two different file shapes, and which one is loaded changes
/// both the URL and the behaviour at the end of a track: a [surah] is one
/// continuous file that simply ends, whereas an [ayah] is a few seconds of
/// audio that hands over to the next ayah of the same surah.
enum RecitationScope { surah, ayah }

/// Result of the pre-flight check on a stream URL.
enum AudioProbe { ok, missing, forbidden, offline }

/// Checks that a stream URL is actually fetchable before handing it to the
/// platform player.
///
/// This matters because `audioplayers` reports a dead URL by simply never
/// emitting its `prepared` event, so the failure only surfaces as a thrown
/// exception after [ap.AudioPlayer.preparationTimeout] — 30 seconds of a
/// spinner that looks like a hang. Probing first turns that into an immediate,
/// accurately-classified error.
typedef AudioProbeFn = Future<AudioProbe> Function(String url);

/// The slice of the platform player that Zad actually uses.
///
/// Declaring it as an interface keeps [AudioController] testable without a
/// platform channel, and documents exactly which platform calls exist.
abstract class RecitationPlayer {
  Stream<ap.PlayerState> get onStateChanged;
  Stream<Duration> get onPosition;
  Stream<Duration> get onDuration;
  Stream<void> get onComplete;
  Stream<String> get onLog;

  Future<void> playUrl(String url);

  /// Plays a recording that is already on disk.
  ///
  /// Used by the download fallback: some platform media stacks cannot open a
  /// remote URL (see [RecitationCache]), but every one of them plays a local
  /// file.
  Future<void> playFile(String path);

  Future<void> resume();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> setPlaybackRate(double rate);
  Future<void> release();
  Future<void> dispose();
}

/// [RecitationPlayer] backed by `package:audioplayers`.
class AudioPlayersRecitationPlayer implements RecitationPlayer {
  AudioPlayersRecitationPlayer() {
    // `ReleaseMode.stop` keeps the decoded buffer when playback ends so the
    // user can replay without re-downloading, and never loops a whole surah.
    unawaited(_player.setReleaseMode(ap.ReleaseMode.stop));
    unawaited(_player.setPlayerMode(ap.PlayerMode.mediaPlayer));
  }

  final ap.AudioPlayer _player = ap.AudioPlayer();

  @override
  Stream<ap.PlayerState> get onStateChanged => _player.onPlayerStateChanged;

  @override
  Stream<Duration> get onPosition => _player.onPositionChanged;

  @override
  Stream<Duration> get onDuration => _player.onDurationChanged;

  @override
  Stream<void> get onComplete => _player.onPlayerComplete;

  @override
  Stream<String> get onLog => _player.onLog;

  @override
  Future<void> playUrl(String url) => _player.play(ap.UrlSource(url));

  @override
  Future<void> playFile(String path) => _player.play(ap.DeviceFileSource(path));

  @override
  Future<void> resume() => _player.resume();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setPlaybackRate(double rate) => _player.setPlaybackRate(rate);

  @override
  Future<void> release() => _player.release();

  @override
  Future<void> dispose() => _player.dispose();
}

/// Default [AudioProbeFn]: a one-byte Range request against the CDN.
///
/// A 206 also proves the server honours Range requests, which is exactly what
/// makes the scrubber's seeking work — so this check doubles as a capability
/// test rather than a bare liveness ping.
Future<AudioProbe> probeAudioUrl(String url) async {
  final client = http.Client();
  try {
    final request = http.Request('GET', Uri.parse(url));
    request.headers['Range'] = 'bytes=0-0';
    final response = await client
        .send(request)
        .timeout(const Duration(seconds: 10));
    // Cancel the body immediately rather than draining it. If the CDN ever
    // ignored the Range header it would otherwise stream the whole surah —
    // up to ~116 MB for Al-Baqarah — just to confirm the file exists.
    unawaited(response.stream.listen((_) {}).cancel());
    switch (response.statusCode) {
      case 200:
      case 206:
        return AudioProbe.ok;
      case 403:
        return AudioProbe.forbidden;
      default:
        return AudioProbe.missing;
    }
  } catch (_) {
    return AudioProbe.offline;
  } finally {
    client.close();
  }
}

/// Owns Qur'an recitation playback for the whole app.
///
/// **Playback granularity.** Two shapes, both from the same CDN and edition:
/// a whole *surah* as one file (`audio-surah/128/{reciter}/{surah}.mp3`), or a
/// single *ayah* (`audio/128/{reciter}/{globalAyah}.mp3`). The surah file gives
/// a real duration and a working scrubber in one request; the ayah files are
/// what let the listener start exactly where they want. [RecitationScope]
/// records which one is loaded, and an ayah hands over to the next ayah of the
/// same surah when it ends.
///
/// **Remote sources.** The stream is handed to the platform player first. When
/// that player cannot open the URL the recording is fetched by Dart into
/// [RecitationCache] and played from disk instead — see `_startPlayback`.
class AudioController extends ChangeNotifier with WidgetsBindingObserver {
  AudioController({
    RecitationPlayer Function()? playerFactory,
    AudioProbeFn? probe,
    RecitationCache? cache,
  }) : _player = (playerFactory ?? AudioPlayersRecitationPlayer.new)(),
       _probe = probe ?? probeAudioUrl,
       _cache = cache ?? HttpRecitationCache() {
    _bind();
    WidgetsBinding.instance.addObserver(this);
  }

  late final RecitationPlayer _player;
  final AudioProbeFn _probe;

  /// Where a recording is stored when the platform player cannot stream it.
  final RecitationCache _cache;

  /// The cache the player reads and writes.
  ///
  /// Exposed so the downloads manager operates on exactly the folder the
  /// player looks in. A second instance would still share the directory, but
  /// sharing the object keeps one lifetime and one HTTP client.
  RecitationCache get cache => _cache;
  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];

  /// How far the skip buttons jump.
  static const Duration skipStep = Duration(seconds: 10);

  /// Playback speeds offered in the UI, in order.
  static const List<double> speeds = <double>[0.75, 1.0, 1.25, 1.5, 2.0];

  RecitationStatus _status = RecitationStatus.idle;
  RecitationStatus get status => _status;

  int? _surahNumber;
  int? get surahNumber => _surahNumber;

  String _surahLabel = '';
  String get surahLabel => _surahLabel;

  /// Whether the loaded track is a whole surah or a single ayah.
  RecitationScope _scope = RecitationScope.surah;
  RecitationScope get scope => _scope;

  bool get isSurahScope => _scope == RecitationScope.surah;
  bool get isAyahScope => _scope == RecitationScope.ayah;

  /// 1-based ayah within [_surahNumber], or `null` when a whole surah is
  /// loaded.
  int? _ayahNumber;
  int? get ayahNumber => _ayahNumber;

  /// Ayahs in the loaded surah, so the queue knows where to stop.
  int? _ayahCount;
  int? get ayahCount => _ayahCount;

  /// Global ayah index (`1..6236`) of ayah 1 of the loaded surah — the base
  /// that turns "the next ayah" into a CDN file name.
  int? _firstAyahGlobal;
  int? get firstAyahGlobal => _firstAyahGlobal;

  /// Whether the end of an ayah continues with the next one.
  bool _continueThroughSurah = true;
  bool get continueThroughSurah => _continueThroughSurah;

  QuranReciter _reciter = QuranReciters.defaultReciter;
  QuranReciter get reciter => _reciter;

  Duration _position = Duration.zero;
  Duration get position => _position;

  Duration _duration = Duration.zero;
  Duration get duration => _duration;

  String? _error;
  String? get error => _error;

  /// Fraction (`0..1`) of a download fallback in flight, or `null` when no
  /// download is running.
  ///
  /// Long surahs are large — Al-Baqarah is ~116 MB — so the UI shows real
  /// progress instead of an indeterminate spinner that looks like a hang.
  double? _downloadProgress;
  double? get downloadProgress => _downloadProgress;

  /// True while the recording is being fetched to disk.
  bool get isDownloading => _downloadProgress != null;

  double _speed = 1.0;
  double get speed => _speed;

  /// The reciter that failed, so the UI can name it in the error message.
  QuranReciter? _failedReciter;
  QuranReciter? get failedReciter => _failedReciter;

  /// Bumped every time a load starts and every time the current one is
  /// abandoned (a stop, or the user cancelling a slow prepare).
  ///
  /// A load spans two awaits — the pre-flight probe and the platform prepare —
  /// and either can take seconds. Without a token, a load the user already
  /// cancelled would still call `play()` when it finally came back, and the
  /// recitation would start on its own with the button showing "play".
  int _loadToken = 0;

  /// The load that most recently handed a URL to the platform player, so a
  /// late-cancelled load can tell whether it still owns the player or whether
  /// a newer load has already taken it over.
  int _playerToken = -1;

  /// True when a surah is loaded and can be played, paused or seeked.
  bool get hasTrack => _surahNumber != null && _status != RecitationStatus.error;

  bool get isLoading => _status == RecitationStatus.loading;
  bool get isPlaying => _status == RecitationStatus.playing;
  bool get isPaused => _status == RecitationStatus.paused;
  bool get hasError => _status == RecitationStatus.error;

  /// True when the platform reported a duration, so a scrubber is meaningful.
  bool get canSeek => _duration > Duration.zero;

  /// True once playback has been started and can be resumed.
  bool get canResume =>
      _status == RecitationStatus.paused || _status == RecitationStatus.completed;

  /// 0..1 progress, or `null` when the duration is not known yet. The UI keeps
  /// the bar on screen either way — it just renders it as indeterminate.
  double? get progress {
    if (_duration <= Duration.zero) return null;
    final ratio = _position.inMilliseconds / _duration.inMilliseconds;
    return ratio.clamp(0.0, 1.0);
  }

  void _bind() {
    _subscriptions.add(
      _player.onStateChanged.listen((state) {
        switch (state) {
          case ap.PlayerState.playing:
            _status = RecitationStatus.playing;
            _error = null;
          case ap.PlayerState.paused:
            // A pause that arrives before we ever started is the tail of a
            // stop(); keep the terminal state in that case. Never downgrade an
            // error either — `_fail` stops the player, and that stop emits a
            // `paused` event which would otherwise wipe the error the user is
            // meant to be reading. An `idle` status means the track was
            // dismissed, so a late event must not resurrect it.
            if (_status != RecitationStatus.loading &&
                _status != RecitationStatus.error &&
                _status != RecitationStatus.idle) {
              _status = RecitationStatus.paused;
            }
          case ap.PlayerState.stopped:
            if (_status != RecitationStatus.loading &&
                _status != RecitationStatus.completed &&
                _status != RecitationStatus.error &&
                _status != RecitationStatus.idle) {
              _status = RecitationStatus.paused;
            }
            _position = Duration.zero;
          case ap.PlayerState.completed:
            _position = _duration;
            // An ayah with a successor is handed over to `_advanceAyah`, which
            // owns the transition; flipping to `completed` here would flash
            // "finished" between two consecutive ayahs.
            if (!_autoAdvance) _status = RecitationStatus.completed;
          case ap.PlayerState.disposed:
            break;
        }
        notifyListeners();
      }),
    );
    _subscriptions.add(
      _player.onPosition.listen((value) {
        _position = value;
        notifyListeners();
      }),
    );
    _subscriptions.add(
      _player.onDuration.listen((value) {
        _duration = value;
        notifyListeners();
      }),
    );
    _subscriptions.add(
      _player.onComplete.listen((_) {
        _position = _duration;
        if (_autoAdvance) {
          // Fire and forget: the advance is a whole load (probe + prepare) and
          // the stream listener must stay responsive to the platform.
          unawaited(_advanceAyah());
          return;
        }
        _status = RecitationStatus.completed;
        notifyListeners();
      }),
    );
    // The platform only reports failures through thrown exceptions and this log
    // channel, so keep the most recent message as diagnostic detail.
    _subscriptions.add(
      _player.onLog.listen((message) {
        _lastLog = message;
      }),
    );
  }

  String? _lastLog;

  /// Most recent message from the platform player — diagnostic detail shown
  /// alongside an error so a failed stream is not a silent dead button.
  String? get lastLog => _lastLog;

  // ------------------------------------------------------------ commands ---

  /// True when the track that just ended is an ayah that has a successor in
  /// the same surah and the user asked to continue through the surah.
  bool get _autoAdvance {
    final ayah = _ayahNumber;
    final count = _ayahCount;
    return _scope == RecitationScope.ayah &&
        _continueThroughSurah &&
        ayah != null &&
        count != null &&
        ayah < count;
  }

  /// Starts (or restarts) the given surah with the given reciter.
  ///
  /// Changing the reciter while the same surah is loaded reloads it from the
  /// new edition — that is the whole point of the picker, so it must never be
  /// treated as a no-op.
  Future<void> playSurah({
    required int surahNumber,
    required String surahLabel,
    required QuranReciter reciter,
  }) => _load(
    url: reciter.surahAudioUrl(surahNumber),
    scope: RecitationScope.surah,
    surahNumber: surahNumber,
    surahLabel: surahLabel,
    reciter: reciter,
  );

  /// Starts one ayah, then continues through the rest of the surah unless
  /// [continueThroughSurah] is `false`.
  ///
  /// [ayahNumber] is the ayah's position *inside its surah* (what the reader
  /// shows). [firstAyahGlobal] is the global index of that surah's first ayah
  /// — `QuranData.firstAyahGlobalNumber` — because that is the numbering the
  /// CDN file name uses. Passing the base, rather than a pre-computed index,
  /// lets the controller walk to the following ayahs without holding a copy of
  /// the Qur'an.
  Future<void> playAyah({
    required int surahNumber,
    required String surahLabel,
    required int ayahNumber,
    required int ayahCount,
    required int firstAyahGlobal,
    required QuranReciter reciter,
    bool continueThroughSurah = true,
  }) {
    final ayah = ayahNumber.clamp(1, ayahCount < 1 ? 1 : ayahCount);
    return _load(
      url: reciter.ayahAudioUrl(firstAyahGlobal + ayah - 1),
      scope: RecitationScope.ayah,
      surahNumber: surahNumber,
      surahLabel: surahLabel,
      reciter: reciter,
      ayahNumber: ayah,
      ayahCount: ayahCount,
      firstAyahGlobal: firstAyahGlobal,
      continueThroughSurah: continueThroughSurah,
    );
  }

  /// The single load path shared by [playSurah] and [playAyah].
  ///
  /// "Same track" is keyed on the scope, the surah, the ayah *and* the
  /// reciter, so switching from a surah to an ayah of that same surah is a
  /// real load rather than being mistaken for a resume.
  Future<void> _load({
    required String url,
    required RecitationScope scope,
    required int surahNumber,
    required String surahLabel,
    required QuranReciter reciter,
    int? ayahNumber,
    int? ayahCount,
    int? firstAyahGlobal,
    bool continueThroughSurah = true,
  }) async {
    final sameTrack =
        _scope == scope &&
        _surahNumber == surahNumber &&
        _ayahNumber == ayahNumber &&
        _reciter.id == reciter.id;

    if (sameTrack && _status == RecitationStatus.paused) {
      await resume();
      return;
    }
    if (sameTrack && _status == RecitationStatus.playing) return;

    // This load owns the player from here on; anything the user does that
    // abandons it (stop, or a new load) invalidates the token.
    final token = ++_loadToken;

    // Tear the previous stream down first. Letting `play()` swap the source on
    // a live player races the old prepare against the new one, which is what
    // makes reciter switches intermittently fail.
    if (_surahNumber != null) {
      await _quietly(_player.stop);
    }

    _scope = scope;
    _surahNumber = surahNumber;
    _surahLabel = surahLabel;
    _reciter = reciter;
    _ayahNumber = ayahNumber;
    _ayahCount = ayahCount;
    _firstAyahGlobal = firstAyahGlobal;
    _continueThroughSurah = continueThroughSurah;
    _position = Duration.zero;
    _duration = Duration.zero;
    _error = null;
    _failedReciter = null;
    _status = RecitationStatus.loading;
    notifyListeners();

    // Pre-flight, so an edition the CDN genuinely does not serve fails in ~1s
    // with an accurate message instead of hanging on the player's 30s prepare
    // timeout.
    //
    // **Only a definitive answer may block playback.** The probe is a plain
    // HTTP request made from the Dart side, whereas the audio itself is played
    // by the platform stack (Android `MediaPlayer`, an HTML `<audio>` element,
    // Media Foundation). Those two disagree in practice — a browser refuses a
    // cross-origin Range request to a CDN that sends no
    // `Access-Control-Allow-Origin` even though `<audio>` plays the very same
    // URL happily, and a captive portal or carrier proxy can answer anything at
    // all. Treating an inconclusive probe as "do not play" is what reduces the
    // play button to a button that does nothing, so here the player gets the
    // final word and the probe is only used to *explain* a failure.
    final probe = await _probe(url);
    if (probe == AudioProbe.missing || probe == AudioProbe.forbidden) {
      await _fail(const _ProbeFailure('unavailable'), reciter: reciter);
      return;
    }
    // The user may have moved on — or cancelled — while the probe was in
    // flight.
    if (token != _loadToken) return;

    _playerToken = token;
    final started = await _startPlayback(
      url,
      probe: probe,
      reciter: reciter,
      token: token,
    );
    if (!started) return;

    if (token != _loadToken) {
      // Cancelled while the platform was preparing. Only tear the player down
      // if this load is still the one that owns it — a newer load may already
      // be streaming.
      if (_playerToken == token) await _quietly(_player.stop);
      return;
    }
    if (_status == RecitationStatus.loading) {
      _status = RecitationStatus.playing;
      notifyListeners();
    }
  }

  /// Plays the next ayah of the loaded surah, or finishes when it is the last.
  Future<void> _advanceAyah() async {
    final current = _ayahNumber;
    final count = _ayahCount;
    final first = _firstAyahGlobal;
    final surah = _surahNumber;
    if (current == null ||
        count == null ||
        first == null ||
        surah == null ||
        current >= count) {
      _status = RecitationStatus.completed;
      notifyListeners();
      return;
    }
    final next = current + 1;
    await _load(
      url: _reciter.ayahAudioUrl(first + next - 1),
      scope: RecitationScope.ayah,
      surahNumber: surah,
      surahLabel: _surahLabel,
      reciter: _reciter,
      ayahNumber: next,
      ayahCount: count,
      firstAyahGlobal: first,
      continueThroughSurah: _continueThroughSurah,
    );
  }

  /// Starts [url], falling back to a local copy when the platform cannot open
  /// the remote stream. Returns `false` when the load failed.
  Future<bool> _startPlayback(
    String url, {
    required AudioProbe probe,
    required QuranReciter reciter,
    required int token,
  }) async {
    // A recording that is already on disk is always preferable: it starts
    // instantly, seeks reliably and works offline. A cache that cannot be read
    // must never block playback, so a failure here just means "not cached".
    File? cached;
    try {
      cached = await _cache.lookup(url);
    } catch (_) {
      cached = null;
    }
    if (token != _loadToken) return false;
    if (cached != null) {
      try {
        await _player.playFile(cached.path);
        return true;
      } catch (_) {
        // A corrupt cache entry must never be fatal — fall through to the
        // stream and let the download path replace it.
      }
      if (token != _loadToken) return false;
    }

    try {
      await _player.playUrl(url);
      return true;
    } catch (streamError) {
      if (token != _loadToken) return false;
      // The platform media stack refused the remote URL. That is a platform
      // limitation rather than a dead recording: `audioplayers` on Windows
      // hands the URL to Media Foundation's `IMFSourceResolver`, which resolves
      // it through WinINet and fails with `ERROR_INTERNET_NAME_NOT_RESOLVED`
      // (0x80072EE7) even while an ordinary HTTP request from Dart reaches the
      // very same URL. Fetching the bytes ourselves and playing the local file
      // sidesteps the OS media stack completely.
      return _playDownloaded(
        url,
        streamError,
        probe: probe,
        reciter: reciter,
        token: token,
      );
    }
  }

  /// Downloads [url] to disk and plays it. Returns `false` on failure.
  Future<bool> _playDownloaded(
    String url,
    Object streamError, {
    required AudioProbe probe,
    required QuranReciter reciter,
    required int token,
  }) async {
    _downloadProgress = 0;
    notifyListeners();

    final File file;
    try {
      file = await _cache.fetch(
        url,
        onProgress: (progress) {
          if (token != _loadToken) return;
          _downloadProgress = progress.fraction;
          notifyListeners();
        },
      );
    } catch (downloadError) {
      _downloadProgress = null;
      // The probe is authoritative when it could not reach the CDN either — the
      // cause is then unambiguously the network. Otherwise report whichever
      // failure is more specific: a real download error beats the platform's
      // own message, which only ever says the OS media stack refused the source.
      await _fail(
        probe == AudioProbe.offline
            ? const _ProbeFailure('network')
            : (downloadError is RecitationDownloadException
                  ? downloadError
                  : streamError),
        reciter: reciter,
      );
      return false;
    }

    // A cancelled load already cleared the flag through [stop].
    if (token != _loadToken) return false;
    _downloadProgress = null;
    _playerToken = token;

    try {
      await _player.playFile(file.path);
      return true;
    } catch (e) {
      // The file is on disk but the device still refused it — a codec or audio
      // device problem, not a network one.
      await _fail(e, reciter: reciter);
      return false;
    }
  }

  /// Turns "continue with the next ayah" on or off without restarting the ayah
  /// that is playing right now — the switch in the listen sheet must take
  /// effect at the *end* of the current ayah, not by reloading it.
  void setContinueThroughSurah(bool value) {
    if (_continueThroughSurah == value) return;
    _continueThroughSurah = value;
    notifyListeners();
  }

  /// Re-loads whatever is currently loaded with a different reciter.
  ///
  /// Used by the reciter picker: with a track loaded, changing the voice must
  /// be audible immediately, and it must keep the *exact* track — a listener
  /// who picked ayah 255 of Al-Baqarah should hear that ayah from the new
  /// reciter, not the surah from the beginning.
  Future<void> reloadWith(QuranReciter reciter) async {
    final surah = _surahNumber;
    if (surah == null) return;
    final ayah = _ayahNumber;
    final count = _ayahCount;
    final first = _firstAyahGlobal;
    if (_scope == RecitationScope.ayah &&
        ayah != null &&
        count != null &&
        first != null) {
      await playAyah(
        surahNumber: surah,
        surahLabel: _surahLabel,
        ayahNumber: ayah,
        ayahCount: count,
        firstAyahGlobal: first,
        reciter: reciter,
        continueThroughSurah: _continueThroughSurah,
      );
      return;
    }
    await playSurah(
      surahNumber: surah,
      surahLabel: _surahLabel,
      reciter: reciter,
    );
  }

  /// Retries whatever failed, keeping the reciter that was selected and the
  /// exact track (surah or ayah) that failed.
  Future<void> retry() async {
    final surah = _surahNumber;
    if (surah == null) return;
    final reciter = _failedReciter ?? _reciter;
    final ayah = _ayahNumber;
    final count = _ayahCount;
    final first = _firstAyahGlobal;
    if (_scope == RecitationScope.ayah &&
        ayah != null &&
        count != null &&
        first != null) {
      await playAyah(
        surahNumber: surah,
        surahLabel: _surahLabel,
        ayahNumber: ayah,
        ayahCount: count,
        firstAyahGlobal: first,
        reciter: reciter,
        continueThroughSurah: _continueThroughSurah,
      );
      return;
    }
    await playSurah(
      surahNumber: surah,
      surahLabel: _surahLabel,
      reciter: reciter,
    );
  }

  Future<void> resume() async {
    if (_surahNumber == null) return;
    if (_status == RecitationStatus.completed) {
      // Replay from the beginning after a completed surah.
      await seek(Duration.zero);
    }
    try {
      await _player.resume();
      _status = RecitationStatus.playing;
      _error = null;
    } catch (e) {
      await _fail(e);
    }
    notifyListeners();
  }

  Future<void> pause() async {
    if (_status != RecitationStatus.playing) return;
    try {
      await _player.pause();
      _status = RecitationStatus.paused;
    } catch (e) {
      await _fail(e);
    }
    notifyListeners();
  }

  Future<void> toggle() async {
    switch (_status) {
      case RecitationStatus.playing:
        await pause();
      case RecitationStatus.loading:
        // Cancel a slow prepare by stopping; the user can press play again.
        await stop();
      case RecitationStatus.paused:
      case RecitationStatus.completed:
        await resume();
      case RecitationStatus.idle:
      case RecitationStatus.error:
        break;
    }
  }

  Future<void> stop() async {
    // Abandon any load that is still in flight: a prepare that lands after the
    // user stopped must not start playing.
    _loadToken++;
    // A download fallback in flight is abandoned with it. The transfer itself
    // is not cancellable, but its progress must stop driving the UI.
    _downloadProgress = null;
    try {
      await _player.stop();
    } catch (e) {
      await _fail(e);
      return;
    }
    _status = _surahNumber == null
        ? RecitationStatus.idle
        : RecitationStatus.paused;
    _position = Duration.zero;
    notifyListeners();
  }

  /// Stops playback and forgets the loaded track, so the UI can go back to its
  /// "nothing is loaded" state.
  ///
  /// This is what the now-playing strip's close button does: [stop] keeps the
  /// track so it can be resumed, which would leave a player strip on screen
  /// forever after the first listen.
  Future<void> dismiss() async {
    _loadToken++;
    _downloadProgress = null;
    try {
      await _player.stop();
    } catch (_) {
      // The track is being discarded anyway; the reset below is the point.
    }
    _status = RecitationStatus.idle;
    _scope = RecitationScope.surah;
    _surahNumber = null;
    _surahLabel = '';
    _ayahNumber = null;
    _ayahCount = null;
    _firstAyahGlobal = null;
    _continueThroughSurah = true;
    _position = Duration.zero;
    _duration = Duration.zero;
    _error = null;
    _failedReciter = null;
    notifyListeners();
  }

  Future<void> seek(Duration position) async {
    if (!canSeek) return;
    final target = Duration(
      milliseconds: position.inMilliseconds.clamp(0, _duration.inMilliseconds),
    );
    try {
      await _player.seek(target);
      _position = target;
      if (_status == RecitationStatus.completed) {
        _status = RecitationStatus.paused;
      }
    } catch (e) {
      await _fail(e);
      return;
    }
    notifyListeners();
  }

  /// Jumps [delta] from the current position, clamped to the track. This is
  /// what the ±10s buttons call.
  Future<void> seekBy(Duration delta) =>
      seek(_position + delta);

  /// Sets the playback speed, clamped to [speeds].
  Future<void> setSpeed(double speed) async {
    final allowed = speeds.reduce(
      (a, b) => (a - speed).abs() <= (b - speed).abs() ? a : b,
    );
    try {
      await _player.setPlaybackRate(allowed);
    } catch (e) {
      await _fail(e);
      return;
    }
    _speed = allowed;
    notifyListeners();
  }

  /// Steps to the next offered speed, wrapping at the end.
  Future<void> cycleSpeed() {
    final index = speeds.indexOf(_speed);
    return setSpeed(speeds[(index + 1) % speeds.length]);
  }

  /// Marker type so a failed pre-flight probe reuses the same classification
  /// path as a thrown platform error.
  Future<void> _fail(Object error, {QuranReciter? reciter}) async {
    _error = _describe(error);
    _failedReciter = reciter ?? _failedReciter ?? _reciter;
    _status = RecitationStatus.error;
    _downloadProgress = null;
    // Drop the broken stream so a retry starts from a clean player.
    //
    // `stop()` alone is not enough on Windows: `audioplayers_windows` remembers
    // the last URL it was handed and short-circuits a repeat of that same URL to
    // a bare "prepared" event without loading anything, so retrying a failed
    // stream would report success and then play silence. `release()` clears the
    // cached URL and forces a real re-resolve.
    await _quietly(_player.stop);
    await _quietly(_player.release);
    notifyListeners();
  }

  static String _describe(Object error) {
    if (error is _ProbeFailure) return error.reason;
    // Failing to fetch the file ourselves is a download problem whatever the
    // platform player said about the stream.
    if (error is RecitationDownloadException) return 'download';
    final text = error.toString();
    // `audioplayers` surfaces a dead URL as "Stream closed before it got
    // prepared" or a prepare timeout — neither mentions the HTTP status, so
    // both are reported as an unavailable recording.
    if (text.contains('Stream closed before it got prepared')) {
      return 'unavailable';
    }
    if (text.contains('TimeoutException') ||
        text.contains('preparation') ||
        text.contains('timed out')) {
      return 'timeout';
    }
    if (text.contains('404') || text.contains('Not Found')) return 'unavailable';
    if (text.contains('403') || text.contains('Forbidden')) return 'unavailable';
    if (text.contains('SocketException') ||
        text.contains('Connection') ||
        text.contains('UnknownHost') ||
        text.contains('Failed host lookup') ||
        text.contains('WindowsAudioError') ||
        text.contains('80072EE7')) {
      return 'network';
    }
    return 'playback';
  }

  // ------------------------------------------------------------ lifecycle --

  /// Audio is paused (not torn down) when the app leaves the foreground: the
  /// screen lock must never leave a recitation playing unexpectedly, and the
  /// app deliberately ships no background audio service.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        unawaited(pause());
      case AppLifecycleState.inactive:
      case AppLifecycleState.resumed:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    // Free the decoder before the widget tree goes away.
    unawaited(_quietly(_player.release));
    unawaited(_quietly(_player.dispose));
    super.dispose();
  }

  /// Runs a platform call whose failure is irrelevant (teardown paths).
  static Future<void> _quietly(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // The player is already going away; there is nothing to report.
    }
  }
}

/// Carries an already-classified reason out of the pre-flight probe.
class _ProbeFailure implements Exception {
  const _ProbeFailure(this.reason);
  final String reason;

  @override
  String toString() => 'ProbeFailure($reason)';
}
