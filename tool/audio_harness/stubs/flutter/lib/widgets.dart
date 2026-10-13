// ignore_for_file: avoid_print, public_member_api_docs

/// Minimal stand-in for `package:flutter/widgets.dart`.
///
/// Mirrors the parts of the widget-binding surface used by
/// `lib/state/audio_controller.dart` (`WidgetsBindingObserver`,
/// `AppLifecycleState`, `WidgetsBinding.instance`).
library;

export 'foundation.dart';

enum AppLifecycleState { detached, resumed, inactive, hidden, paused }

mixin class WidgetsBindingObserver {
  void didChangeAppLifecycleState(AppLifecycleState state) {}
}

class WidgetsBinding {
  WidgetsBinding._();

  static final WidgetsBinding instance = WidgetsBinding._();

  final List<WidgetsBindingObserver> _observers = <WidgetsBindingObserver>[];

  int get observerCount => _observers.length;

  void addObserver(WidgetsBindingObserver observer) {
    if (!_observers.contains(observer)) _observers.add(observer);
  }

  void removeObserver(WidgetsBindingObserver observer) =>
      _observers.remove(observer);
}
