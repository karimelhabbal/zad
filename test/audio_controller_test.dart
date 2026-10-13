import 'dart:async';

import 'package:audioplayers/audioplayers.dart' as ap;
// `flutter_test` does not re-export the lifecycle enum, and the `lifecycle`
// group below drives it directly.
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/data/models/reciter.dart';
import 'package:zad/state/audio_controller.dart';

/// [AudioController]'s state machine, driven through a fake platform player so
/// no platform channel (and no real network) is involved.
///
/// The controller is the only thing standing between the UI and a stream that
/// can be slow, missing or dead, so every branch it exposes is pinned here.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakePlayer player;
  late AudioController controller;

  const reciter = QuranReciter(
    id: 'ar.alafasy',
    arabicName: 'مشاري راشد العفاسي',
    englishName: 'Mishary Rashid Alafasy',
  );

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() {
    player = _FakePlayer();
    controller = AudioController(
      playerFactory: () => player,
      // The pre-flight probe is a real HTTP request; stub it as reachable so
      // these tests never touch the network.
      probe: (_) async => AudioProbe.ok,
    );
  });

  tearDown(() => controller.dispose());

  group('initial state', () {
    test('starts idle with no track and no progress', () {
      expect(controller.status, RecitationStatus.idle);
      expect(controller.surahNumber, isNull);
      expect(controller.hasTrack, isFalse);
      expect(controller.isPlaying, isFalse);
      expect(controller.isLoading, isFalse);
      expect(controller.canSeek, isFalse);
      expect(controller.progress, isNull);
      expect(controller.position, Duration.zero);
      expect(controller.duration, Duration.zero);
      expect(controller.error, isNull);
    });
  });

  group('playSurah', () {
    test('streams exactly the requested surah from the CDN', () async {
      await controller.playSurah(
        surahNumber: 18,
        surahLabel: 'الكهف',
        reciter: reciter,
      );
      expect(player.playedUrls, <String>[
        'https://cdn.islamic.network/quran/audio-surah/128/ar.alafasy/18.mp3',
      ]);
      expect(controller.surahNumber, 18);
      expect(controller.surahLabel, 'الكهف');
      expect(controller.reciter.id, 'ar.alafasy');
      expect(controller.status, RecitationStatus.playing);
      expect(controller.isPlaying, isTrue);
      expect(controller.hasTrack, isTrue);
    });

    test('goes through loading while the stream is being prepared', () async {
      final states = <RecitationStatus>[];
      controller.addListener(() => states.add(controller.status));

      final pending = controller.playSurah(
        surahNumber: 1,
        surahLabel: 'الفاتحة',
        reciter: reciter,
      );
      // The fake has not resolved yet, so the UI is showing the spinner.
      expect(controller.status, RecitationStatus.loading);
      expect(controller.isLoading, isTrue);
      await pending;
      await settle();

      expect(states.first, RecitationStatus.loading);
      expect(controller.status, RecitationStatus.playing);
    });

    test('re-selecting the same surah while playing is a no-op', () async {
      await controller.playSurah(
        surahNumber: 1,
        surahLabel: 'الفاتحة',
        reciter: reciter,
      );
      await controller.playSurah(
        surahNumber: 1,
        surahLabel: 'الفاتحة',
        reciter: reciter,
      );
      expect(player.playedUrls.length, 1);
      expect(player.resumeCount, 0);
    });

    test('re-selecting the same surah while paused resumes it', () async {
      await controller.playSurah(
        surahNumber: 1,
        surahLabel: 'الفاتحة',
        reciter: reciter,
      );
      await controller.pause();
      expect(controller.isPaused, isTrue);

      await controller.playSurah(
        surahNumber: 1,
        surahLabel: 'الفاتحة',
        reciter: reciter,
      );
      expect(player.playedUrls.length, 1, reason: 'no re-download');
      expect(player.resumeCount, 1);
      expect(controller.isPlaying, isTrue);
    });

    test('a different surah starts a fresh stream', () async {
      await controller.playSurah(
        surahNumber: 1,
        surahLabel: 'الفاتحة',
        reciter: reciter,
      );
      await controller.playSurah(
        surahNumber: 2,
        surahLabel: 'البقرة',
        reciter: reciter,
      );
      expect(player.playedUrls.length, 2);
      expect(controller.surahNumber, 2);
      expect(controller.position, Duration.zero);
      expect(controller.duration, Duration.zero);
    });

    test('changing reciter re-streams the same surah', () async {
      await controller.playSurah(
        surahNumber: 1,
        surahLabel: 'الفاتحة',
        reciter: reciter,
      );
      const other = QuranReciter(
        id: 'ar.saudalshuraim',
        arabicName: 'سعود الشريم',
        englishName: 'Saud ash-Shuraim',
      );
      await controller.playSurah(
        surahNumber: 1,
        surahLabel: 'الفاتحة',
        reciter: other,
      );
      expect(player.playedUrls.last, contains('ar.saudalshuraim'));
      expect(controller.reciter.id, 'ar.saudalshuraim');
    });

    // The user-facing bug this pins: picking a new reciter while the surah sat
    // paused used to resume the *old* recording, so the choice appeared to do
    // nothing at all.
    test('changing reciter while paused re-streams instead of resuming',
        () async {
      await controller.playSurah(
        surahNumber: 1,
        surahLabel: 'الفاتحة',
        reciter: reciter,
      );
      await controller.pause();
      expect(controller.isPaused, isTrue);
      final playedBefore = player.playedUrls.length;
      final resumesBefore = player.resumeCount;

      const other = QuranReciter(
        id: 'ar.abdullahalmatrood',
        arabicName: 'عبد الله المطرود',
        englishName: 'Abdullah al-Matrood',
      );
      await controller.playSurah(
        surahNumber: 1,
        surahLabel: 'الفاتحة',
        reciter: other,
      );

      expect(player.playedUrls.length, playedBefore + 1,
          reason: 'the new edition must actually be fetched');
      expect(player.playedUrls.last,
          contains('ar.abdullahalmatrood/1.mp3'));
      expect(player.resumeCount, resumesBefore,
          reason: 'resuming would replay the previous reciter');
      expect(controller.reciter.id, 'ar.abdullahalmatrood');
      expect(controller.isPlaying, isTrue);
    });

    test('switching source tears the old stream down first', () async {
      await controller.playSurah(
        surahNumber: 1,
        surahLabel: 'الفاتحة',
        reciter: reciter,
      );
      final stopsBefore = player.stopCount;
      await controller.playSurah(
        surahNumber: 2,
        surahLabel: 'البقرة',
        reciter: reciter,
      );
      expect(player.stopCount, greaterThan(stopsBefore),
          reason: 'avoids racing the old prepare against the new one');
    });
  });

  group('transport', () {
    setUp(() async {
      await controller.playSurah(
        surahNumber: 1,
        surahLabel: 'الفاتحة',
        reciter: reciter,
      );
      player.emitDuration(const Duration(minutes: 2));
      await settle();
    });

    test('pause then resume keeps the track', () async {
      await controller.pause();
      expect(controller.isPaused, isTrue);
      expect(controller.isPlaying, isFalse);
      expect(player.pauseCount, 1);

      await controller.resume();
      expect(controller.isPlaying, isTrue);
      expect(player.resumeCount, 1);
    });

    test('pause is a no-op when nothing is playing', () async {
      await controller.pause();
      await controller.pause();
      expect(player.pauseCount, 1);
    });

    test('toggle flips between playing and paused', () async {
      await controller.toggle();
      expect(controller.isPaused, isTrue);
      await controller.toggle();
      expect(controller.isPlaying, isTrue);
    });

    test('stop returns the position to the start but keeps the surah', () async {
      player.emitPosition(const Duration(seconds: 30));
      await settle();
      expect(controller.position, const Duration(seconds: 30));

      await controller.stop();
      expect(player.stopCount, 1);
      expect(controller.position, Duration.zero);
      expect(controller.surahNumber, 1, reason: 'the surah stays selected');
      expect(controller.isPlaying, isFalse);
    });

    test('duration and progress come from the platform', () async {
      expect(controller.canSeek, isTrue);
      expect(controller.duration, const Duration(minutes: 2));

      player.emitPosition(const Duration(seconds: 30));
      await settle();
      expect(controller.position, const Duration(seconds: 30));
      expect(controller.progress, closeTo(0.25, 0.001));
    });

    test('progress is null until a duration is known', () async {
      final fresh = AudioController(
        playerFactory: () => _FakePlayer(),
        probe: (_) async => AudioProbe.ok,
      );
      addTearDown(fresh.dispose);
      await fresh.playSurah(
        surahNumber: 1,
        surahLabel: 'الفاتحة',
        reciter: reciter,
      );
      expect(fresh.canSeek, isFalse);
      expect(fresh.progress, isNull);
    });

    test('seek forwards the position and clamps it to the duration', () async {
      await controller.seek(const Duration(seconds: 45));
      expect(player.seeks.last, const Duration(seconds: 45));
      expect(controller.position, const Duration(seconds: 45));

      // Beyond the end — the platform must never be asked to over-seek.
      await controller.seek(const Duration(minutes: 9));
      expect(player.seeks.last, const Duration(minutes: 2));
      expect(controller.position, const Duration(minutes: 2));

      await controller.seek(const Duration(seconds: -5));
      expect(player.seeks.last, Duration.zero);
    });

    test('seek is ignored when no duration is available', () async {
      final fresh = AudioController(
        playerFactory: () => _FakePlayer(),
        probe: (_) async => AudioProbe.ok,
      );
      addTearDown(fresh.dispose);
      await fresh.seek(const Duration(seconds: 10));
      expect((fresh.status), RecitationStatus.idle);
    });

    test('skip moves by the step and clamps at both ends', () async {
      await controller.seek(const Duration(seconds: 60));
      await controller.seekBy(AudioController.skipStep);
      expect(controller.position, const Duration(seconds: 70));

      await controller.seekBy(-AudioController.skipStep);
      expect(controller.position, const Duration(seconds: 60));

      // Skipping back from the very start must not go negative.
      await controller.seek(Duration.zero);
      await controller.seekBy(-AudioController.skipStep);
      expect(controller.position, Duration.zero);

      // Skipping past the end stops at the duration.
      await controller.seekBy(const Duration(minutes: 5));
      expect(controller.position, const Duration(minutes: 2));
    });

    test('speed steps through the offered rates and wraps', () async {
      expect(controller.speed, 1.0);
      await controller.cycleSpeed();
      expect(controller.speed, 1.25);
      expect(player.rates.last, 1.25);

      await controller.cycleSpeed();
      await controller.cycleSpeed();
      expect(controller.speed, 2.0);

      // Past the last entry it wraps to the first.
      await controller.cycleSpeed();
      expect(controller.speed, AudioController.speeds.first);
      expect(player.rates.last, AudioController.speeds.first);
    });

    test('an arbitrary speed snaps to the nearest offered rate', () async {
      await controller.setSpeed(1.6);
      expect(controller.speed, 1.5);
      await controller.setSpeed(0.1);
      expect(controller.speed, 0.75);
    });
  });

  group('completion', () {
    test('marks the surah completed at its full duration', () async {
      await controller.playSurah(
        surahNumber: 112,
        surahLabel: 'الإخلاص',
        reciter: reciter,
      );
      player.emitDuration(const Duration(seconds: 40));
      await settle();
      player.emitComplete();
      await settle();

      expect(controller.status, RecitationStatus.completed);
      expect(controller.position, const Duration(seconds: 40));
      expect(controller.isPlaying, isFalse);
      expect(controller.hasTrack, isTrue);
    });

    test('resuming after completion replays from the beginning', () async {
      await controller.playSurah(
        surahNumber: 112,
        surahLabel: 'الإخلاص',
        reciter: reciter,
      );
      player.emitDuration(const Duration(seconds: 40));
      await settle();
      player.emitComplete();
      await settle();

      await controller.resume();
      expect(player.seeks.last, Duration.zero);
      expect(controller.isPlaying, isTrue);
      expect(player.playedUrls.length, 1, reason: 'replay, not re-download');
    });
  });

  group('failures', () {
    test('a network failure surfaces a network error, not a dead button', () async {
      player.failWith = Exception('SocketException: Failed host lookup');
      await controller.playSurah(
        surahNumber: 1,
        surahLabel: 'الفاتحة',
        reciter: reciter,
      );

      expect(controller.status, RecitationStatus.error);
      expect(controller.error, 'network');
      expect(controller.isPlaying, isFalse);
      expect(controller.isLoading, isFalse);
      expect(controller.hasTrack, isFalse, reason: 'the play button must retry');
      expect(player.stopCount, greaterThan(0), reason: 'broken stream dropped');
    });

    test('a preparation timeout is reported as a timeout', () async {
      player.failWith = TimeoutException('preparation timed out');
      await controller.playSurah(
        surahNumber: 2,
        surahLabel: 'البقرة',
        reciter: reciter,
      );
      expect(controller.error, 'timeout');
      expect(controller.status, RecitationStatus.error);
    });

    test('a missing recording is reported as unavailable', () async {
      player.failWith = Exception('404 Not Found');
      await controller.playSurah(
        surahNumber: 3,
        surahLabel: 'آل عمران',
        reciter: reciter,
      );
      expect(controller.error, 'unavailable');
    });

    test('an unrecognised failure still reports a playback error', () async {
      player.failWith = Exception('weird decoder explosion');
      await controller.playSurah(
        surahNumber: 3,
        surahLabel: 'آل عمران',
        reciter: reciter,
      );
      expect(controller.error, 'playback');
      expect(controller.status, RecitationStatus.error);
    });

    test('retrying after a failure succeeds', () async {
      player.failWith = Exception('SocketException');
      await controller.playSurah(
        surahNumber: 1,
        surahLabel: 'الفاتحة',
        reciter: reciter,
      );
      expect(controller.status, RecitationStatus.error);

      player.failWith = null;
      await controller.playSurah(
        surahNumber: 1,
        surahLabel: 'الفاتحة',
        reciter: reciter,
      );
      expect(controller.status, RecitationStatus.playing);
      expect(controller.error, isNull);
      expect(controller.hasTrack, isTrue);
    });

    test('a failing pause reports an error instead of pretending', () async {
      await controller.playSurah(
        surahNumber: 1,
        surahLabel: 'الفاتحة',
        reciter: reciter,
      );
      player.failWith = Exception('SocketException');
      await controller.pause();
      expect(controller.status, RecitationStatus.error);
      expect(controller.error, 'network');
    });

    // The error state must survive the teardown stop that `_fail` issues —
    // that stop emits a `paused` event which would otherwise wipe the message
    // the user is meant to be reading.
    test('the error state survives the teardown stop', () async {
      player.failWith = Exception('SocketException: Failed host lookup');
      await controller.playSurah(
        surahNumber: 1,
        surahLabel: 'الفاتحة',
        reciter: reciter,
      );
      await settle();
      await settle();
      expect(controller.status, RecitationStatus.error);
      expect(controller.error, 'network');
      expect(controller.hasError, isTrue);
    });

    test('a dead URL fails fast via the probe, never reaching the player',
        () async {
      final probed = <String>[];
      final localPlayer = _FakePlayer();
      final fresh = AudioController(
        playerFactory: () => localPlayer,
        probe: (url) async {
          probed.add(url);
          return AudioProbe.missing;
        },
      );
      addTearDown(fresh.dispose);

      await fresh.playSurah(
        surahNumber: 2,
        surahLabel: 'البقرة',
        reciter: reciter,
      );

      expect(probed.single,
          'https://cdn.islamic.network/quran/audio-surah/128/ar.alafasy/2.mp3');
      expect(fresh.error, 'unavailable');
      expect(fresh.status, RecitationStatus.error);
      expect(localPlayer.playedUrls, isEmpty,
          reason: 'no 30s prepare timeout, because the URL was checked first');
      expect(fresh.failedReciter?.id, 'ar.alafasy');
    });

    test('a forbidden edition is reported as unavailable', () async {
      final fresh = AudioController(
        playerFactory: _FakePlayer.new,
        probe: (_) async => AudioProbe.forbidden,
      );
      addTearDown(fresh.dispose);
      await fresh.playSurah(
        surahNumber: 1,
        surahLabel: 'الفاتحة',
        reciter: reciter,
      );
      expect(fresh.error, 'unavailable');
    });

    // The probe is a plain HTTP request from the Dart side; the audio is played
    // by the platform stack. The two disagree in practice — a browser refuses a
    // cross-origin Range request to a CDN with no CORS headers while `<audio>`
    // plays the same URL fine — so an inconclusive probe must never veto
    // playback. Only a definitive 403/404 does.
    test('an inconclusive probe still attempts playback', () async {
      final localPlayer = _FakePlayer();
      final fresh = AudioController(
        playerFactory: () => localPlayer,
        probe: (_) async => AudioProbe.offline,
      );
      addTearDown(fresh.dispose);

      await fresh.playSurah(
        surahNumber: 1,
        surahLabel: 'الفاتحة',
        reciter: reciter,
      );

      expect(localPlayer.playedUrls, hasLength(1),
          reason: 'the player gets the final word');
      expect(fresh.status, RecitationStatus.playing);
      expect(fresh.error, isNull);
    });

    test('an inconclusive probe plus a dead player reports a network error',
        () async {
      final localPlayer = _FakePlayer()
        ..failWith = Exception('SocketException: Failed host lookup');
      final fresh = AudioController(
        playerFactory: () => localPlayer,
        probe: (_) async => AudioProbe.offline,
      );
      addTearDown(fresh.dispose);

      await fresh.playSurah(
        surahNumber: 1,
        surahLabel: 'الفاتحة',
        reciter: reciter,
      );
      expect(fresh.status, RecitationStatus.error);
      expect(fresh.error, 'network');
    });

    test('retry re-uses the reciter that failed', () async {
      final localPlayer = _FakePlayer();
      final fresh = AudioController(
        playerFactory: () => localPlayer,
        probe: (_) async => AudioProbe.ok,
      );
      addTearDown(fresh.dispose);

      const matrood = QuranReciter(
        id: 'ar.abdullahalmatrood',
        arabicName: 'عبد الله المطرود',
        englishName: 'Abdullah al-Matrood',
      );
      localPlayer.failWith = Exception('SocketException');
      await fresh.playSurah(
        surahNumber: 1,
        surahLabel: 'الفاتحة',
        reciter: matrood,
      );
      expect(fresh.status, RecitationStatus.error);
      expect(fresh.failedReciter?.id, 'ar.abdullahalmatrood');

      localPlayer.failWith = null;
      await fresh.retry();
      expect(localPlayer.playedUrls.last, contains('ar.abdullahalmatrood'));
      expect(fresh.status, RecitationStatus.playing);
      expect(fresh.error, isNull);
    });
  });

  group('cancelling a slow load', () {
    test('cancelling a slow prepare stops it instead of starting it', () async {
      player.playDelay = const Duration(milliseconds: 40);
      final pending = controller.playSurah(
        surahNumber: 2,
        surahLabel: 'البقرة',
        reciter: reciter,
      );
      await settle();
      expect(controller.isLoading, isTrue);

      // The spinner in the transport row is a button: tapping it cancels.
      await controller.toggle();
      expect(controller.isPaused, isTrue);

      await pending;
      await settle();
      await settle();
      expect(controller.isPlaying, isFalse,
          reason: 'a cancelled prepare must never start playing');
      expect(player.stopCount, greaterThan(0));
    });

    test('cancelling while the probe is in flight never reaches the player',
        () async {
      final localPlayer = _FakePlayer();
      final fresh = AudioController(
        playerFactory: () => localPlayer,
        probe: (_) async {
          await Future<void>.delayed(const Duration(milliseconds: 40));
          return AudioProbe.ok;
        },
      );
      addTearDown(fresh.dispose);

      final pending = fresh.playSurah(
        surahNumber: 2,
        surahLabel: 'البقرة',
        reciter: reciter,
      );
      await settle();
      await fresh.toggle();

      await pending;
      await settle();
      expect(localPlayer.playedUrls, isEmpty, reason: 'no stream was started');
      expect(fresh.isPlaying, isFalse);
    });
  });

  group('lifecycle', () {
    test('leaving the foreground pauses instead of leaking playback', () async {
      await controller.playSurah(
        surahNumber: 1,
        surahLabel: 'الفاتحة',
        reciter: reciter,
      );
      expect(controller.isPlaying, isTrue);

      controller.didChangeAppLifecycleState(AppLifecycleState.paused);
      await settle();
      expect(controller.isPaused, isTrue);
      expect(player.pauseCount, 1);
      expect(player.releaseCount, 0, reason: 'resumable, not torn down');
    });

    test('an inactive blip does not stop playback', () async {
      await controller.playSurah(
        surahNumber: 1,
        surahLabel: 'الفاتحة',
        reciter: reciter,
      );
      controller.didChangeAppLifecycleState(AppLifecycleState.inactive);
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await settle();
      expect(player.pauseCount, 0);
      expect(controller.isPlaying, isTrue);
    });

    test('dispose releases the decoder and stops notifying', () async {
      final owned = AudioController(
        playerFactory: () => player,
        probe: (_) async => AudioProbe.ok,
      );
      await owned.playSurah(
        surahNumber: 1,
        surahLabel: 'الفاتحة',
        reciter: reciter,
      );
      owned.dispose();
      await settle();
      expect(player.releaseCount, 1);
      expect(player.disposeCount, 1);
    });
  });
}

/// In-memory [RecitationPlayer] that records calls and lets the test drive the
/// platform event streams.
class _FakePlayer implements RecitationPlayer {
  final StreamController<ap.PlayerState> _states =
      StreamController<ap.PlayerState>.broadcast();
  final StreamController<Duration> _positions =
      StreamController<Duration>.broadcast();
  final StreamController<Duration> _durations =
      StreamController<Duration>.broadcast();
  final StreamController<void> _completions =
      StreamController<void>.broadcast();
  final StreamController<String> _logs = StreamController<String>.broadcast();

  final List<String> playedUrls = <String>[];
  final List<Duration> seeks = <Duration>[];
  final List<double> rates = <double>[];
  int resumeCount = 0;
  int pauseCount = 0;
  int stopCount = 0;
  int releaseCount = 0;
  int disposeCount = 0;

  /// When set, every command throws it — simulating a platform failure.
  Object? failWith;

  /// Simulates a slow platform prepare (a large surah on a slow connection).
  Duration playDelay = Duration.zero;

  void emitDuration(Duration value) => _durations.add(value);
  void emitPosition(Duration value) => _positions.add(value);
  void emitComplete() => _completions.add(null);

  @override
  Stream<ap.PlayerState> get onStateChanged => _states.stream;

  @override
  Stream<Duration> get onPosition => _positions.stream;

  @override
  Stream<Duration> get onDuration => _durations.stream;

  @override
  Stream<void> get onComplete => _completions.stream;

  @override
  Stream<String> get onLog => _logs.stream;

  void _maybeThrow() {
    final failure = failWith;
    if (failure != null) throw failure;
  }

  @override
  Future<void> playUrl(String url) async {
    _maybeThrow();
    playedUrls.add(url);
    if (playDelay > Duration.zero) {
      await Future<void>.delayed(playDelay);
    }
    _states.add(ap.PlayerState.playing);
  }

  @override
  Future<void> resume() async {
    _maybeThrow();
    resumeCount++;
    _states.add(ap.PlayerState.playing);
  }

  @override
  Future<void> pause() async {
    _maybeThrow();
    pauseCount++;
    _states.add(ap.PlayerState.paused);
  }

  @override
  Future<void> stop() async {
    _maybeThrow();
    stopCount++;
    _states.add(ap.PlayerState.stopped);
  }

  @override
  Future<void> seek(Duration position) async {
    _maybeThrow();
    seeks.add(position);
  }

  @override
  Future<void> setPlaybackRate(double rate) async {
    _maybeThrow();
    rates.add(rate);
  }

  @override
  Future<void> release() async => releaseCount++;

  @override
  Future<void> dispose() async => disposeCount++;
}
