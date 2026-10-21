// ignore_for_file: avoid_print, public_member_api_docs

/// Minimal stand-in for `package:flutter/foundation.dart`.
///
/// Only the surface that `lib/state/audio_controller.dart` actually touches is
/// implemented, so the real controller source can be compiled and executed on
/// the plain Dart VM (no dart:ui, no Flutter engine).
library;

class ChangeNotifier {
  final List<void Function()> _listeners = <void Function()>[];

  bool get hasListeners => _listeners.isNotEmpty;

  void addListener(void Function() listener) => _listeners.add(listener);

  void removeListener(void Function() listener) => _listeners.remove(listener);

  void notifyListeners() {
    for (final listener in List<void Function()>.of(_listeners)) {
      listener();
    }
  }

  void dispose() => _listeners.clear();

  @override
  String toString() => 'ChangeNotifier(${_listeners.length} listeners)';
}

void debugPrint(String? message) => print(message);

bool get kIsWeb => false;

class _VisibleForTesting {
  const _VisibleForTesting();
}

const visibleForTesting = _VisibleForTesting();
