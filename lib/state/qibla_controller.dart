import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/models/settings_models.dart';
import '../data/services/qibla_service.dart';
import 'prayer_controller.dart' show PrayerController;

enum QiblaState { idle, loading, ready, needsLocation, noSensor, error }

/// Owns the Qibla computation: the geographic bearing to the Kaaba plus the
/// live device heading from the magnetometer.
///
/// The direction is always derived from **real location and sensor data** — the
/// compass is never decorative. When the sensor is missing or unreliable the
/// UI is told, so it can present the numeric bearing and calibration guidance
/// instead of pretending to be exact.
class QiblaController extends ChangeNotifier {
  QiblaController({required PrayerController prayer})
    : // Public parameter is `prayer`; the field is private, so an initializing
      // formal would rename the public API.
      // ignore: prefer_initializing_formals
      _prayer = prayer,
      _service = const QiblaService();

  final PrayerController _prayer;
  final QiblaService _service;

  StreamSubscription<CompassReading>? _subscription;

  QiblaState _state = QiblaState.idle;
  QiblaState get state => _state;

  double? _bearing;
  double? get bearing => _bearing;

  double? _distanceKm;
  double? get distanceKm => _distanceKm;

  double? _heading;
  double? get heading => _heading;

  bool _hasSensor = true;
  bool get hasSensor => _hasSensor;

  bool _sensorReported = false;

  /// True until the first non-null heading arrives — the UI shows a
  /// "calibrating" state instead of a frozen needle.
  bool get isCalibrating => _hasSensor && _heading == null;

  String? _error;
  String? get error => _error;

  /// How far the user must turn the phone so the top points at the Kaaba.
  double? get relativeAngle {
    final b = _bearing;
    final h = _heading;
    if (b == null || h == null) return null;
    return QiblaService.relativeToDevice(b, h);
  }

  /// Deviation from the Qibla in the -180..180 range.
  double? get deviation {
    final rel = relativeAngle;
    if (rel == null) return null;
    return QiblaService.signedDifference(rel, 0);
  }

  bool get isAligned {
    final d = deviation;
    if (d == null) return false;
    return d.abs() <= 5;
  }

  /// Accuracy of the *heading reading* (not of the Qibla maths).
  double? _headingAccuracy;
  AccuracyBucket get accuracy =>
      QiblaService.bucketForAccuracy(_headingAccuracy);

  /// True when the reading should not be trusted for precise alignment.
  bool get isUnreliable =>
      !_hasSensor || accuracy == AccuracyBucket.low || accuracy == AccuracyBucket.unknown;

  Future<void> initialise() async {
    await refresh();
    _listenToSensor();
  }

  Future<void> refresh() async {
    _state = QiblaState.loading;
    _error = null;
    notifyListeners();

    try {
      final resolved = await _prayer.resolveOnce(requestPermission: true);
      switch (resolved.status) {
        case LocationStatus.ok:
          break;
        case LocationStatus.permissionDenied:
        case LocationStatus.permissionDeniedForever:
        case LocationStatus.serviceDisabled:
        case LocationStatus.unavailable:
        case LocationStatus.notConfigured:
          _bearing = null;
          _distanceKm = null;
          _state = QiblaState.needsLocation;
          notifyListeners();
          return;
      }

      final lat = resolved.latitude!;
      final lng = resolved.longitude!;
      _bearing = QiblaService.bearingToKaaba(lat, lng);
      _distanceKm = QiblaService.distanceToKaabaKm(lat, lng);
      _state = _hasSensor ? QiblaState.ready : QiblaState.noSensor;
    } catch (e) {
      _error = e.toString();
      _state = QiblaState.error;
    }
    notifyListeners();
  }

  void _listenToSensor() {
    if (_sensorReported) return;
    _sensorReported = true;
    _hasSensor = QiblaService.hasHeadingSensor;
    if (!_hasSensor) {
      if (_state == QiblaState.ready) _state = QiblaState.noSensor;
      notifyListeners();
      return;
    }
    try {
      _subscription = _service.headings().listen(
        (reading) {
          _heading = reading.heading;
          _headingAccuracy = reading.accuracy;
          if (reading.heading != null && _state == QiblaState.noSensor) {
            _state = QiblaState.ready;
          }
          notifyListeners();
        },
        onError: (_) {
          _hasSensor = false;
          _state = QiblaState.noSensor;
          notifyListeners();
        },
        cancelOnError: false,
      );
    } catch (_) {
      _hasSensor = false;
      _state = QiblaState.noSensor;
      notifyListeners();
    }
  }

  /// Degrees to turn, and which way.
  (double, bool)? get turnInstruction {
    final d = deviation;
    if (d == null || isAligned) return null;
    return (d.abs(), d > 0);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
