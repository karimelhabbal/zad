import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/models/settings_models.dart';
import '../data/services/location_service.dart';
import '../data/services/prayer_times_service.dart';
import 'settings_controller.dart';

enum PrayerState { idle, loading, ready, needsLocation, permissionDenied, error }

/// Owns the location + prayer-time state shared by the home dashboard and the
/// prayer-times screen, so both always show identical data.
class PrayerController extends ChangeNotifier {
  PrayerController({
    required SettingsController settings,
    LocationService? locationService,
    PrayerTimesService? prayerTimesService,
  }) : // The public parameter name is intentionally `settings`; the field is
       // private, so an initializing formal would rename the public API.
       // ignore: prefer_initializing_formals
       _settings = settings,
       _locationService = locationService ?? LocationService(),
       _prayerTimes = prayerTimesService ?? const PrayerTimesService();

  final SettingsController _settings;
  final LocationService _locationService;
  final PrayerTimesService _prayerTimes;

  PrayerState _state = PrayerState.idle;
  PrayerState get state => _state;

  ResolvedLocation _location = ResolvedLocation.notConfigured;
  ResolvedLocation get location => _location;

  PrayerSchedule? _schedule;
  PrayerSchedule? get schedule => _schedule;

  String? _error;
  String? get error => _error;

  Timer? _ticker;

  DateTime _now = DateTime.now();
  DateTime get now => _now;

  bool get isReady => _state == PrayerState.ready && _schedule != null;

  /// Countdown to the next prayer, refreshed every second.
  Duration get remaining =>
      _schedule?.remaining(_now) ?? const Duration(seconds: 0);

  PrayerSlot? get nextPrayer => _schedule?.next;

  PrayerSlot? get currentPrayer => _schedule?.current;

  double get dayProgress => _schedule?.progress(_now) ?? 0;

  /// Starts the second-by-second countdown used by the home card.
  void startTicker() {
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
      _now = DateTime.now();
      notifyListeners();
    });
  }

  void stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  /// Resolves the location and recomputes the schedule.
  ///
  /// [requestPermission] should be `true` only when the user explicitly asked
  /// for their location, so the permission dialog is never shown on startup.
  Future<void> refresh({bool requestPermission = false}) async {
    _state = PrayerState.loading;
    _error = null;
    notifyListeners();

    try {
      final settings = _settings.settings;
      final resolved = requestPermission
          ? await _locationService.resolveFromDevice(settings.location)
          : await _locationService.resolve(settings.location);
      _location = resolved;

      switch (resolved.status) {
        case LocationStatus.ok:
          break;
        case LocationStatus.permissionDenied:
        case LocationStatus.permissionDeniedForever:
          _schedule = null;
          _state = PrayerState.permissionDenied;
          notifyListeners();
          return;
        case LocationStatus.serviceDisabled:
        case LocationStatus.unavailable:
        case LocationStatus.notConfigured:
          _schedule = null;
          _state = PrayerState.needsLocation;
          notifyListeners();
          return;
      }

      _schedule = _prayerTimes.compute(
        latitude: resolved.latitude!,
        longitude: resolved.longitude!,
        settings: settings,
      );

      if (_schedule == null) {
        _state = PrayerState.error;
        _error = 'calculation_failed';
      } else {
        _state = PrayerState.ready;
      }
    } catch (e) {
      _schedule = null;
      _state = PrayerState.error;
      _error = e.toString();
    }
    notifyListeners();
  }

  /// Recomputes using the settings without touching permissions.
  Future<void> recompute() async {
    final resolved = _location;
    if (!resolved.isOk) {
      await refresh();
      return;
    }
    _schedule = _prayerTimes.compute(
      latitude: resolved.latitude!,
      longitude: resolved.longitude!,
      settings: _settings.settings,
    );
    _state = _schedule == null ? PrayerState.error : PrayerState.ready;
    notifyListeners();
  }

  /// Convenience for the Qibla screen and the manual-location sheet.
  Future<ResolvedLocation> resolveOnce({bool requestPermission = true}) =>
      requestPermission
      ? _locationService.resolveFromDevice(_settings.settings.location)
      : _locationService.resolve(_settings.settings.location);

  Future<List<GeoPlace>> searchCity(String query) => _locationService.searchCity(
    query,
    language: _settings.settings.isArabic ? 'ar' : 'en',
  );

  Future<bool> openAppSettings() => _locationService.openAppSettings();

  Future<bool> openLocationSettings() =>
      _locationService.openLocationSettings();

  /// Human-readable summary of the coordinates currently in use.
  String get locationSummary {
    final city = _location.cityName;
    if (city != null && city.isNotEmpty) return city;
    if (_location.isOk) {
      return '${_location.latitude!.toStringAsFixed(3)}, '
          '${_location.longitude!.toStringAsFixed(3)}';
    }
    return '';
  }

  @override
  void dispose() {
    stopTicker();
    _locationService.dispose();
    super.dispose();
  }
}
