// ignore_for_file: avoid_print, public_member_api_docs

/// Stand-in for `package:audioplayers/audioplayers.dart`.
///
/// The public surface matches audioplayers 6.8.1 (verified against the real
/// package source in the pub cache) and the observable behaviour mirrors it:
/// `play()` sets the source, waits for it to be "prepared" and then starts,
/// emitting `PlayerState.playing` only at the end.
library;

import 'dart:async';

enum PlayerState { stopped, playing, paused, completed, disposed }

enum ReleaseMode { release, loop, stop }

enum PlayerMode { mediaPlayer, lowLatency }

class UrlSource {
  const UrlSource(this.url);

  final String url;

  @override
  String toString() => 'UrlSource($url)';
}

class AudioPlayer {
  AudioPlayer({String? playerId}) {
    instances.add(this);
  }

  /// Every player the app created, so a harness can drive the platform side of
  /// the real adapter.
  static final List<AudioPlayer> instances = <AudioPlayer>[];

  static AudioPlayer get last => instances.last;

  static void reset() => instances.clear();

  final StreamController<PlayerState> _states =
      StreamController<PlayerState>.broadcast();
  final StreamController<Duration> _positions =
      StreamController<Duration>.broadcast();
  final StreamController<Duration> _durations =
      StreamController<Duration>.broadcast();
  final StreamController<void> _completions =
      StreamController<void>.broadcast();
  final StreamController<String> _logs = StreamController<String>.broadcast();

  /// Test knobs.
  Object? failWith;
  Duration prepareDelay = Duration.zero;
  Duration reportedDuration = const Duration(seconds: 30);

  final List<String> playedUrls = <String>[];
  final List<Duration> seeks = <Duration>[];
  final List<double> rates = <double>[];
  int resumeCount = 0;
  int pauseCount = 0;
  int stopCount = 0;
  int releaseCount = 0;
  int disposeCount = 0;
  ReleaseMode? releaseMode;
  PlayerMode? playerMode;

  Stream<PlayerState> get onPlayerStateChanged => _states.stream;

  Stream<Duration> get onPositionChanged => _positions.stream;

  Stream<Duration> get onDurationChanged => _durations.stream;

  Stream<void> get onPlayerComplete => _completions.stream;

  Stream<String> get onLog => _logs.stream;

  void emitPosition(Duration value) => _positions.add(value);

  void emitComplete() => _completions.add(null);

  void emitLog(String message) => _logs.add(message);

  Future<void> _guard() async {
    final failure = failWith;
    if (failure != null) throw failure;
  }

  Future<void> play(Object source) async {
    await _guard();
    final url = source is UrlSource ? source.url : '$source';
    playedUrls.add(url);
    if (prepareDelay > Duration.zero) {
      await Future<void>.delayed(prepareDelay);
    }
    _durations.add(reportedDuration);
    _states.add(PlayerState.playing);
  }

  Future<void> resume() async {
    await _guard();
    resumeCount++;
    _states.add(PlayerState.playing);
  }

  Future<void> pause() async {
    await _guard();
    pauseCount++;
    _states.add(PlayerState.paused);
  }

  Future<void> stop() async {
    await _guard();
    stopCount++;
    _states.add(PlayerState.stopped);
  }

  Future<void> seek(Duration position) async {
    await _guard();
    seeks.add(position);
  }

  Future<void> setPlaybackRate(double rate) async {
    await _guard();
    rates.add(rate);
  }

  Future<void> setReleaseMode(ReleaseMode mode) async {
    releaseMode = mode;
  }

  Future<void> setPlayerMode(PlayerMode mode) async {
    playerMode = mode;
  }

  Future<void> release() async {
    releaseCount++;
  }

  Future<void> dispose() async {
    disposeCount++;
    _states.add(PlayerState.disposed);
    await _states.close();
    await _positions.close();
    await _durations.close();
    await _completions.close();
    await _logs.close();
  }
}
