/// Executes the *real* `lib/state/audio_controller.dart` on the plain Dart VM.
///
/// Why this exists: `flutter test` and `dart analyze` both fail on this host
/// with `ProcessException: All pipe instances are busy` — the Dart SDK cannot
/// spawn child processes at all. This harness resolves `package:flutter` and
/// `package:audioplayers` to the minimal stand-ins in `stubs/`, which lets the
/// genuine controller source (the same file the app ships, including the real
/// `AudioPlayersRecitationPlayer` adapter and the real `probeAudioUrl`, which
/// uses the genuine `package:http`) compile and execute.
///
/// Run it with:
///
/// ```
/// python tool/audio_harness/run.py
/// ```
///
/// It is a *substitute* for `flutter test test/audio_controller_test.dart`, not
/// a replacement: it cannot exercise widgets, platform channels or the real
/// audioplayers plugin. Keep both suites in sync.
library;

import 'dart:async';

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:zad/data/models/reciter.dart';
import 'package:zad/state/audio_controller.dart';

int _passed = 0;
final List<String> _failures = <String>[];

Future<void> t(String name, Future<void> Function() body) async {
  try {
    await body();
    _passed++;
  } catch (error, stack) {
    _failures.add('$name\n      $error');
    if (stack.toString().contains('harness.dart')) {
      // keep the first harness frame for orientation
    }
  }
}

void check(bool condition, String what) {
  if (!condition) throw StateError('expected: $what');
}

void eq(Object? actual, Object? expected, String what) {
  final same = actual is List && expected is List
      ? actual.length == expected.length &&
          List<int>.generate(actual.length, (i) => i)
              .every((i) => actual[i] == expected[i])
      : actual == expected;
  if (!same) {
    throw StateError('$what — expected <$expected>, got <$actual>');
  }
}

Future<void> settle() => Future<void>.delayed(Duration.zero);

const QuranReciter alafasy = QuranReciter(
  id: 'ar.alafasy',
  arabicName: 'مشاري راشد العفاسي',
  englishName: 'Mishary Rashid Alafasy',
);

const QuranReciter matrood = QuranReciter(
  id: 'ar.abdullahalmatrood',
  arabicName: 'عبد الله المطرود',
  englishName: 'Abdullah al-Matrood',
);

/// A [RecitationPlayer] that records calls and lets the harness drive the
/// platform events, mirroring `test/audio_controller_test.dart`.
class FakePlayer implements RecitationPlayer {
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
  Object? failWith;

  /// Simulates a slow platform prepare.
  Duration playDelay = Duration.zero;

  void emitDuration(Duration value) => _durations.add(value);
  void emitPosition(Duration value) => _positions.add(value);
  void emitComplete() => _completions.add(null);

  void _guard() {
    final failure = failWith;
    if (failure != null) throw failure;
  }

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

  @override
  Future<void> playUrl(String url) async {
    _guard();
    playedUrls.add(url);
    if (playDelay > Duration.zero) {
      await Future<void>.delayed(playDelay);
    }
    _states.add(ap.PlayerState.playing);
  }

  @override
  Future<void> resume() async {
    _guard();
    resumeCount++;
    _states.add(ap.PlayerState.playing);
  }

  @override
  Future<void> pause() async {
    _guard();
    pauseCount++;
    _states.add(ap.PlayerState.paused);
  }

  @override
  Future<void> stop() async {
    _guard();
    stopCount++;
    _states.add(ap.PlayerState.stopped);
  }

  @override
  Future<void> seek(Duration position) async {
    _guard();
    seeks.add(position);
  }

  @override
  Future<void> setPlaybackRate(double rate) async {
    _guard();
    rates.add(rate);
  }

  @override
  Future<void> release() async => releaseCount++;
  @override
  Future<void> dispose() async => disposeCount++;
}

/// Builds a controller wired to the *real* adapter (so the real
/// `AudioPlayersRecitationPlayer` + the stub platform player are exercised).
AudioController realAdapter({AudioProbeFn? probe}) {
  ap.AudioPlayer.reset();
  return AudioController(probe: probe ?? (_) async => AudioProbe.ok);
}

AudioController fakeBacked(FakePlayer player, {AudioProbeFn? probe}) =>
    AudioController(
      playerFactory: () => player,
      probe: probe ?? (_) async => AudioProbe.ok,
    );

Future<void> main() async {
  print('== AudioController harness (real source, stubbed platform) ==');

  // ---------------------------------------------------------------- idle ----
  await t('starts idle with no track', () async {
    final c = fakeBacked(FakePlayer());
    addTearDown(c.dispose);
    eq(c.status, RecitationStatus.idle, 'status');
    eq(c.surahNumber, null, 'surahNumber');
    eq(c.hasTrack, false, 'hasTrack');
    eq(c.isPlaying, false, 'isPlaying');
    eq(c.canSeek, false, 'canSeek');
    eq(c.progress, null, 'progress');
    eq(c.error, null, 'error');
  });

  // ------------------------------------------------- real adapter + URL ----
  await t('real adapter streams the requested surah from the CDN', () async {
    final c = realAdapter();
    addTearDown(c.dispose);
    await c.playSurah(surahNumber: 18, surahLabel: 'الكهف', reciter: alafasy);
    final player = ap.AudioPlayer.last;
    eq(
      player.playedUrls,
      <String>[
        'https://cdn.islamic.network/quran/audio-surah/128/ar.alafasy/18.mp3',
      ],
      'played URL',
    );
    eq(c.surahNumber, 18, 'surahNumber');
    eq(c.status, RecitationStatus.playing, 'status after play');
    eq(c.isPlaying, true, 'isPlaying');
    eq(c.hasTrack, true, 'hasTrack');
    eq(player.releaseMode, ap.ReleaseMode.stop, 'release mode');
  });

  await t('real adapter passes the platform duration through', () async {
    final c = realAdapter();
    addTearDown(c.dispose);
    await c.playSurah(surahNumber: 1, surahLabel: 'الفاتحة', reciter: alafasy);
    await settle();
    eq(c.duration, const Duration(seconds: 30), 'duration');
    eq(c.canSeek, true, 'canSeek');
  });

  await t('real adapter maps pause/resume/seek/rate to the platform', () async {
    final c = realAdapter();
    addTearDown(c.dispose);
    await c.playSurah(surahNumber: 1, surahLabel: 'الفاتحة', reciter: alafasy);
    final player = ap.AudioPlayer.last;
    await c.pause();
    eq(player.pauseCount, 1, 'pause forwarded');
    await c.resume();
    eq(player.resumeCount, 1, 'resume forwarded');
    await c.seek(const Duration(seconds: 5));
    eq(player.seeks.single, const Duration(seconds: 5), 'seek forwarded');
    await c.setSpeed(1.5);
    eq(player.rates.single, 1.5, 'rate forwarded');
  });

  // -------------------------------------------------------- loading state ---
  await t('shows loading while the stream is being prepared', () async {
    final player = FakePlayer();
    final c = fakeBacked(player, probe: (_) async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return AudioProbe.ok;
    });
    addTearDown(c.dispose);
    final states = <RecitationStatus>[];
    c.addListener(() => states.add(c.status));

    final pending =
        c.playSurah(surahNumber: 1, surahLabel: 'الفاتحة', reciter: alafasy);
    eq(c.status, RecitationStatus.loading, 'status while probing');
    eq(c.isLoading, true, 'isLoading');
    await pending;
    await settle();
    eq(states.first, RecitationStatus.loading, 'first emitted state');
    eq(c.status, RecitationStatus.playing, 'status after prepare');
  });

  await t('a slow real prepare keeps the spinner up, then plays', () async {
    final c = realAdapter();
    addTearDown(c.dispose);
    ap.AudioPlayer.last.prepareDelay = const Duration(milliseconds: 30);
    final pending =
        c.playSurah(surahNumber: 2, surahLabel: 'البقرة', reciter: alafasy);
    eq(c.isLoading, true, 'loading during prepare');
    await pending;
    await settle();
    eq(c.status, RecitationStatus.playing, 'playing after prepare');
  });

  // ------------------------------------------------------- same track etc ---
  await t('re-selecting the same surah while playing is a no-op', () async {
    final player = FakePlayer();
    final c = fakeBacked(player);
    addTearDown(c.dispose);
    await c.playSurah(surahNumber: 1, surahLabel: 'الفاتحة', reciter: alafasy);
    await c.playSurah(surahNumber: 1, surahLabel: 'الفاتحة', reciter: alafasy);
    eq(player.playedUrls.length, 1, 'no re-download');
    eq(player.resumeCount, 0, 'no resume');
  });

  await t('re-selecting the same surah while paused resumes it', () async {
    final player = FakePlayer();
    final c = fakeBacked(player);
    addTearDown(c.dispose);
    await c.playSurah(surahNumber: 1, surahLabel: 'الفاتحة', reciter: alafasy);
    await c.pause();
    await c.playSurah(surahNumber: 1, surahLabel: 'الفاتحة', reciter: alafasy);
    eq(player.playedUrls.length, 1, 'no re-download');
    eq(player.resumeCount, 1, 'resumed');
    eq(c.isPlaying, true, 'playing');
  });

  await t('a different surah starts a fresh stream and tears the old one down',
      () async {
    final player = FakePlayer();
    final c = fakeBacked(player);
    addTearDown(c.dispose);
    await c.playSurah(surahNumber: 1, surahLabel: 'الفاتحة', reciter: alafasy);
    final stopsBefore = player.stopCount;
    await c.playSurah(surahNumber: 2, surahLabel: 'البقرة', reciter: alafasy);
    eq(player.playedUrls.length, 2, 'two streams');
    check(player.stopCount > stopsBefore, 'old stream stopped first');
    eq(c.surahNumber, 2, 'surah');
    eq(c.position, Duration.zero, 'position reset');
    eq(c.duration, Duration.zero, 'duration reset');
  });

  await t('changing reciter re-streams the same surah', () async {
    final player = FakePlayer();
    final c = fakeBacked(player);
    addTearDown(c.dispose);
    await c.playSurah(surahNumber: 1, surahLabel: 'الفاتحة', reciter: alafasy);
    await c.playSurah(surahNumber: 1, surahLabel: 'الفاتحة', reciter: matrood);
    check(
      player.playedUrls.last.contains('ar.abdullahalmatrood/1.mp3'),
      'new edition fetched',
    );
    eq(c.reciter.id, 'ar.abdullahalmatrood', 'active reciter');
  });

  await t('changing reciter while paused re-streams instead of resuming',
      () async {
    final player = FakePlayer();
    final c = fakeBacked(player);
    addTearDown(c.dispose);
    await c.playSurah(surahNumber: 1, surahLabel: 'الفاتحة', reciter: alafasy);
    await c.pause();
    final resumesBefore = player.resumeCount;
    await c.playSurah(surahNumber: 1, surahLabel: 'الفاتحة', reciter: matrood);
    eq(player.resumeCount, resumesBefore, 'must not resume the old voice');
    check(
      player.playedUrls.last.contains('ar.abdullahalmatrood/1.mp3'),
      'new voice fetched',
    );
    eq(c.isPlaying, true, 'playing');
  });

  // ------------------------------------------------------------ transport ---
  await t('pause then resume keeps the track', () async {
    final player = FakePlayer();
    final c = fakeBacked(player);
    addTearDown(c.dispose);
    await c.playSurah(surahNumber: 1, surahLabel: 'الفاتحة', reciter: alafasy);
    await c.pause();
    eq(c.isPaused, true, 'paused');
    eq(player.pauseCount, 1, 'pause forwarded');
    await c.resume();
    eq(c.isPlaying, true, 'playing');
    eq(player.resumeCount, 1, 'resume forwarded');
  });

  await t('toggle flips playing <-> paused', () async {
    final c = fakeBacked(FakePlayer());
    addTearDown(c.dispose);
    await c.playSurah(surahNumber: 1, surahLabel: 'الفاتحة', reciter: alafasy);
    await c.toggle();
    eq(c.isPaused, true, 'paused after first toggle');
    await c.toggle();
    eq(c.isPlaying, true, 'playing after second toggle');
  });

  await t('stop resets the position but keeps the surah selected', () async {
    final player = FakePlayer();
    final c = fakeBacked(player);
    addTearDown(c.dispose);
    await c.playSurah(surahNumber: 1, surahLabel: 'الفاتحة', reciter: alafasy);
    player.emitDuration(const Duration(minutes: 2));
    player.emitPosition(const Duration(seconds: 30));
    await settle();
    await c.stop();
    eq(player.stopCount, 1, 'stop forwarded');
    eq(c.position, Duration.zero, 'position reset');
    eq(c.surahNumber, 1, 'surah kept');
    eq(c.isPlaying, false, 'not playing');
  });

  await t('duration, progress and seeking come from the platform', () async {
    final player = FakePlayer();
    final c = fakeBacked(player);
    addTearDown(c.dispose);
    await c.playSurah(surahNumber: 1, surahLabel: 'الفاتحة', reciter: alafasy);
    player.emitDuration(const Duration(minutes: 2));
    player.emitPosition(const Duration(seconds: 30));
    await settle();
    eq(c.duration, const Duration(minutes: 2), 'duration');
    eq(c.progress, 0.25, 'progress');
    await c.seek(const Duration(seconds: 45));
    eq(player.seeks.last, const Duration(seconds: 45), 'seek');
    await c.seek(const Duration(minutes: 9));
    eq(player.seeks.last, const Duration(minutes: 2), 'seek clamped to duration');
    await c.seekBy(-AudioController.skipStep);
    eq(c.position, const Duration(minutes: 1, seconds: 50), 'skip back');
  });

  await t('progress is null until a duration is known', () async {
    final c = fakeBacked(FakePlayer());
    addTearDown(c.dispose);
    await c.playSurah(surahNumber: 1, surahLabel: 'الفاتحة', reciter: alafasy);
    eq(c.canSeek, false, 'canSeek');
    eq(c.progress, null, 'progress');
  });

  await t('speed steps through the offered rates and wraps', () async {
    final player = FakePlayer();
    final c = fakeBacked(player);
    addTearDown(c.dispose);
    await c.playSurah(surahNumber: 1, surahLabel: 'الفاتحة', reciter: alafasy);
    eq(c.speed, 1.0, 'default speed');
    await c.cycleSpeed();
    eq(c.speed, 1.25, 'next speed');
    await c.cycleSpeed();
    await c.cycleSpeed();
    eq(c.speed, 2.0, 'top speed');
    await c.cycleSpeed();
    eq(c.speed, 0.75, 'wrapped');
    await c.setSpeed(1.6);
    eq(c.speed, 1.5, 'snaps to nearest offered rate');
  });

  // ----------------------------------------------------------- completion ---
  await t('completion marks the surah finished at its full duration', () async {
    final player = FakePlayer();
    final c = fakeBacked(player);
    addTearDown(c.dispose);
    await c.playSurah(surahNumber: 112, surahLabel: 'الإخلاص', reciter: alafasy);
    player.emitDuration(const Duration(seconds: 40));
    await settle();
    player.emitComplete();
    await settle();
    eq(c.status, RecitationStatus.completed, 'status');
    eq(c.position, const Duration(seconds: 40), 'position');
    eq(c.hasTrack, true, 'hasTrack');
  });

  await t('resuming after completion replays without re-downloading', () async {
    final player = FakePlayer();
    final c = fakeBacked(player);
    addTearDown(c.dispose);
    await c.playSurah(surahNumber: 112, surahLabel: 'الإخلاص', reciter: alafasy);
    player.emitDuration(const Duration(seconds: 40));
    await settle();
    player.emitComplete();
    await settle();
    await c.resume();
    eq(player.seeks.last, Duration.zero, 'rewound');
    eq(c.isPlaying, true, 'playing');
    eq(player.playedUrls.length, 1, 'no re-download');
  });

  // ------------------------------------------------------------- failures ---
  await t('a network failure reports a network error, not a dead button',
      () async {
    final player = FakePlayer()
      ..failWith = Exception('SocketException: Failed host lookup');
    final c = fakeBacked(player);
    addTearDown(c.dispose);
    await c.playSurah(surahNumber: 1, surahLabel: 'الفاتحة', reciter: alafasy);
    eq(c.status, RecitationStatus.error, 'status');
    eq(c.error, 'network', 'error code');
    eq(c.hasTrack, false, 'play button must offer a retry');
  });

  await t('a preparation timeout is reported as a timeout', () async {
    final player = FakePlayer()
      ..failWith = TimeoutException('preparation timed out');
    final c = fakeBacked(player);
    addTearDown(c.dispose);
    await c.playSurah(surahNumber: 2, surahLabel: 'البقرة', reciter: alafasy);
    eq(c.error, 'timeout', 'error code');
  });

  await t('an unrecognised failure still reports a playback error', () async {
    final player = FakePlayer()..failWith = Exception('decoder exploded');
    final c = fakeBacked(player);
    addTearDown(c.dispose);
    await c.playSurah(surahNumber: 3, surahLabel: 'آل عمران', reciter: alafasy);
    eq(c.error, 'playback', 'error code');
  });

  await t('the error state survives the teardown stop', () async {
    final player = FakePlayer()
      ..failWith = Exception('SocketException: Failed host lookup');
    final c = fakeBacked(player);
    addTearDown(c.dispose);
    await c.playSurah(surahNumber: 1, surahLabel: 'الفاتحة', reciter: alafasy);
    await settle();
    await settle();
    eq(c.status, RecitationStatus.error, 'status');
    eq(c.hasError, true, 'hasError');
  });

  await t('retrying after a failure succeeds and clears the error', () async {
    final player = FakePlayer()..failWith = Exception('SocketException');
    final c = fakeBacked(player);
    addTearDown(c.dispose);
    await c.playSurah(surahNumber: 1, surahLabel: 'الفاتحة', reciter: alafasy);
    eq(c.status, RecitationStatus.error, 'errored');
    player.failWith = null;
    await c.playSurah(surahNumber: 1, surahLabel: 'الفاتحة', reciter: alafasy);
    eq(c.status, RecitationStatus.playing, 'recovered');
    eq(c.error, null, 'error cleared');
    eq(c.hasTrack, true, 'hasTrack');
  });

  await t('retry() re-uses the reciter that failed', () async {
    final player = FakePlayer()..failWith = Exception('SocketException');
    final c = fakeBacked(player);
    addTearDown(c.dispose);
    await c.playSurah(surahNumber: 1, surahLabel: 'الفاتحة', reciter: matrood);
    eq(c.failedReciter?.id, 'ar.abdullahalmatrood', 'failed reciter recorded');
    player.failWith = null;
    await c.retry();
    check(
      player.playedUrls.last.contains('ar.abdullahalmatrood'),
      'same reciter retried',
    );
    eq(c.status, RecitationStatus.playing, 'recovered');
  });

  await t('a failing pause reports an error instead of pretending', () async {
    final player = FakePlayer();
    final c = fakeBacked(player);
    addTearDown(c.dispose);
    await c.playSurah(surahNumber: 1, surahLabel: 'الفاتحة', reciter: alafasy);
    player.failWith = Exception('SocketException');
    await c.pause();
    eq(c.status, RecitationStatus.error, 'status');
  });

  // ------------------------------------------------------------- the probe --
  await t('a 404 from the CDN is still reported as unavailable, fast',
      () async {
    final player = FakePlayer();
    final c = fakeBacked(player, probe: (_) async => AudioProbe.missing);
    addTearDown(c.dispose);
    await c.playSurah(surahNumber: 2, surahLabel: 'البقرة', reciter: alafasy);
    eq(c.error, 'unavailable', 'error code');
    eq(player.playedUrls, <String>[], 'never reached the player');
    eq(c.failedReciter?.id, 'ar.alafasy', 'names the reciter');
  });

  await t('a 403 from the CDN is reported as unavailable', () async {
    final c = fakeBacked(FakePlayer(), probe: (_) async => AudioProbe.forbidden);
    addTearDown(c.dispose);
    await c.playSurah(surahNumber: 1, surahLabel: 'الفاتحة', reciter: alafasy);
    eq(c.error, 'unavailable', 'error code');
  });

  await t('an inconclusive probe still attempts playback', () async {
    // The probe is a plain HTTP request; on the web it is subject to CORS, and
    // a proxy or a captive portal can answer it with anything. The platform
    // player is the authority — it must get the chance to play.
    final player = FakePlayer();
    final c = fakeBacked(player, probe: (_) async => AudioProbe.offline);
    addTearDown(c.dispose);
    await c.playSurah(surahNumber: 1, surahLabel: 'الفاتحة', reciter: alafasy);
    eq(player.playedUrls.length, 1, 'playback was attempted');
    eq(c.status, RecitationStatus.playing, 'playing');
  });

  await t('an inconclusive probe + a player failure is explained as network',
      () async {
    final player = FakePlayer()..failWith = Exception('SocketException');
    final c = fakeBacked(player, probe: (_) async => AudioProbe.offline);
    addTearDown(c.dispose);
    await c.playSurah(surahNumber: 1, surahLabel: 'الفاتحة', reciter: alafasy);
    eq(c.status, RecitationStatus.error, 'status');
    eq(c.error, 'network', 'error code');
  });

  await t('a live probe against the real CDN answers ok', () async {
    // Exercises the genuine probeAudioUrl + the genuine package:http.
    final probe = await probeAudioUrl(
      'https://cdn.islamic.network/quran/audio-surah/128/ar.alafasy/1.mp3',
    );
    eq(probe, AudioProbe.ok, 'live probe result');
  });

  await t('the live probe classifies a nonexistent edition', () async {
    final probe = await probeAudioUrl(
      'https://cdn.islamic.network/quran/audio-surah/128/ar.definitelynotreal/1.mp3',
    );
    check(
      probe == AudioProbe.missing || probe == AudioProbe.forbidden,
      'dead edition is classified (got $probe)',
    );
  });

  // -------------------------------------------------- cancelling a load ----
  await t('cancelling a slow prepare stops the player instead of starting it',
      () async {
    final player = FakePlayer()..playDelay = const Duration(milliseconds: 40);
    final c = fakeBacked(player);
    addTearDown(c.dispose);

    final pending =
        c.playSurah(surahNumber: 2, surahLabel: 'البقرة', reciter: alafasy);
    await settle();
    eq(c.isLoading, true, 'loading');

    // The spinner is a button: tapping it cancels the load.
    await c.toggle();
    eq(c.isPaused, true, 'cancelled, not playing');

    await pending;
    await settle();
    await settle();
    eq(c.isPlaying, false, 'a cancelled prepare must never start playing');
    check(player.stopCount > 0, 'player torn down');
  });

  await t('cancelling while the probe is in flight never reaches the player',
      () async {
    final player = FakePlayer();
    final c = fakeBacked(player, probe: (_) async {
      await Future<void>.delayed(const Duration(milliseconds: 40));
      return AudioProbe.ok;
    });
    addTearDown(c.dispose);

    final pending =
        c.playSurah(surahNumber: 2, surahLabel: 'البقرة', reciter: alafasy);
    await settle();
    await c.toggle();

    await pending;
    await settle();
    eq(player.playedUrls, <String>[], 'no stream was started');
    eq(c.isPlaying, false, 'not playing');
  });

  // ------------------------------------------------------------ lifecycle ---
  await t('leaving the foreground pauses instead of leaking playback',
      () async {
    final player = FakePlayer();
    final c = fakeBacked(player);
    addTearDown(c.dispose);
    await c.playSurah(surahNumber: 1, surahLabel: 'الفاتحة', reciter: alafasy);
    c.didChangeAppLifecycleState(AppLifecycleState.paused);
    await settle();
    eq(c.isPaused, true, 'paused');
    eq(player.pauseCount, 1, 'pause forwarded');
    eq(player.releaseCount, 0, 'resumable, not torn down');
  });

  await t('an inactive blip does not stop playback', () async {
    final player = FakePlayer();
    final c = fakeBacked(player);
    addTearDown(c.dispose);
    await c.playSurah(surahNumber: 1, surahLabel: 'الفاتحة', reciter: alafasy);
    c.didChangeAppLifecycleState(AppLifecycleState.inactive);
    c.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await settle();
    eq(player.pauseCount, 0, 'no pause');
    eq(c.isPlaying, true, 'still playing');
  });

  await t('dispose releases the decoder', () async {
    final player = FakePlayer();
    final c = fakeBacked(player);
    await c.playSurah(surahNumber: 1, surahLabel: 'الفاتحة', reciter: alafasy);
    c.dispose();
    await settle();
    eq(player.releaseCount, 1, 'release called');
    eq(player.disposeCount, 1, 'dispose called');
  });

  for (final teardown in _teardowns) {
    teardown();
  }
  await settle();

  print('');
  print('passed: $_passed');
  print('failed: ${_failures.length}');
  for (final failure in _failures) {
    print('');
    print('  FAIL $failure');
  }
}

void addTearDown(void Function() callback) {
  // The harness is sequential; dispose straight after each test's body would
  // fight the awaits, so teardown callbacks are collected and run in order at
  // the end of the run.
  _teardowns.add(callback);
}

final List<void Function()> _teardowns = <void Function()>[];
