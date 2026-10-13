import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_compass/flutter_compass.dart';

/// Geographic Qibla maths plus the device heading stream.
class QiblaService {
  const QiblaService();

  /// Kaaba coordinates (Masjid al-Haram, Makkah).
  static const double kaabaLatitude = 21.4225241;
  static const double kaabaLongitude = 39.8261818;

  /// Great-circle initial bearing from a location to the Kaaba, in degrees
  /// clockwise from **true north** (0..360).
  static double bearingToKaaba(double latitude, double longitude) {
    final phi1 = _rad(latitude);
    final phi2 = _rad(kaabaLatitude);
    final deltaLambda = _rad(kaabaLongitude - longitude);

    final y = math.sin(deltaLambda) * math.cos(phi2);
    final x =
        math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(deltaLambda);
    final bearing = math.atan2(y, x);
    return normalize(_deg(bearing));
  }

  /// Haversine distance to the Kaaba in kilometres.
  static double distanceToKaabaKm(double latitude, double longitude) {
    const earthRadiusKm = 6371.0088;
    final dPhi = _rad(kaabaLatitude - latitude);
    final dLambda = _rad(kaabaLongitude - longitude);
    final a =
        math.sin(dPhi / 2) * math.sin(dPhi / 2) +
        math.cos(_rad(latitude)) *
            math.cos(_rad(kaabaLatitude)) *
            math.sin(dLambda / 2) *
            math.sin(dLambda / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  /// Normalises an angle to the 0..360 range.
  static double normalize(double degrees) {
    var value = degrees % 360;
    if (value < 0) value += 360;
    return value;
  }

  /// Shortest signed difference `a - b` in the -180..180 range.
  static double signedDifference(double a, double b) {
    var diff = normalize(a) - normalize(b);
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    return diff;
  }

  /// Rotates a bearing into the device's reference frame.
  ///
  /// [qiblaBearing] is measured from true north; [deviceHeading] is the
  /// direction the top of the device points to. The result is how far the user
  /// must turn the phone (0 = the top of the phone points at the Kaaba).
  static double relativeToDevice(double qiblaBearing, double deviceHeading) =>
      normalize(qiblaBearing - deviceHeading);

  /// Magnetic declination is not available from the compass plugin, so the
  /// caller can supply the value produced by the platform. Kept explicit so the
  /// UI can be honest about the accuracy of the reading.
  static double applyDeclination(double magneticHeading, double declination) =>
      normalize(magneticHeading + declination);

  /// A stream of device headings in degrees from true north, together with the
  /// platform's accuracy estimate.
  ///
  /// Emits a [CompassReading] whose `heading` is `null` when the platform
  /// cannot determine an orientation, and completes immediately on devices with
  /// no heading sensor.
  Stream<CompassReading> headings() {
    final events = FlutterCompass.events;
    if (events == null) return const Stream<CompassReading>.empty();
    return events.map(
      (event) => CompassReading(
        heading: event.heading,
        accuracy: event.accuracy,
      ),
    );
  }

  /// Whether the platform exposes a heading sensor.
  static bool get hasHeadingSensor => FlutterCompass.events != null;

  /// Maps the raw platform accuracy (radians, as reported by Android/iOS) to a
  /// coarse 0..2 bucket used for the accuracy badge.
  static AccuracyBucket bucketForAccuracy(double? accuracy) {
    if (accuracy == null || accuracy.isNaN) return AccuracyBucket.unknown;
    if (accuracy <= 0.2) return AccuracyBucket.high;
    if (accuracy <= 0.6) return AccuracyBucket.medium;
    return AccuracyBucket.low;
  }

  static double _rad(double degrees) => degrees * math.pi / 180.0;

  static double _deg(double radians) => radians * 180.0 / math.pi;
}

enum AccuracyBucket { high, medium, low, unknown }

/// One compass sample: heading from true north plus the platform's accuracy.
class CompassReading {
  const CompassReading({required this.heading, required this.accuracy});

  final double? heading;

  /// Raw accuracy value reported by the platform (radians on Android/iOS).
  final double? accuracy;
}

/// The cardinal label for a heading, localised by the caller.
enum CompassCardinal { north, east, south, west }

CompassCardinal cardinalFor(double heading) {
  final value = QiblaService.normalize(heading);
  // North spans (315, 360) ∪ [0, 45); the four quadrants are otherwise equal.
  if (value < 45 || value > 315) return CompassCardinal.north;
  if (value < 135) return CompassCardinal.east;
  if (value < 225) return CompassCardinal.south;
  return CompassCardinal.west;
}
