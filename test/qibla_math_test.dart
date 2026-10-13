import 'package:flutter_test/flutter_test.dart';
import 'package:zad/data/services/qibla_service.dart';

/// The Qibla is pure geography — these tests pin the maths so a regression in
/// the bearing formula cannot silently point users in the wrong direction.
void main() {
  group('bearingToKaaba', () {
    test('matches the known bearing from Cairo (~136°)', () {
      final bearing = QiblaService.bearingToKaaba(30.0444, 31.2357);
      expect(bearing, closeTo(136.2, 2.0));
    });

    test('matches the known bearing from Jakarta (~295°)', () {
      final bearing = QiblaService.bearingToKaaba(-6.2088, 106.8456);
      expect(bearing, closeTo(295.1, 2.5));
    });

    test('matches the known bearing from New York (~58°)', () {
      final bearing = QiblaService.bearingToKaaba(40.7128, -74.0060);
      expect(bearing, closeTo(58.5, 2.5));
    });

    test('always returns a value in the 0..360 range', () {
      for (final lat in <double>[-80, -30, 0, 30, 60, 80]) {
        for (final lng in <double>[-170, -60, 0, 60, 170]) {
          final bearing = QiblaService.bearingToKaaba(lat, lng);
          expect(bearing, greaterThanOrEqualTo(0));
          expect(bearing, lessThan(360));
        }
      }
    });
  });

  group('distanceToKaabaKm', () {
    test('Cairo to Makkah is roughly 1270 km', () {
      final km = QiblaService.distanceToKaabaKm(30.0444, 31.2357);
      expect(km, closeTo(1270, 120));
    });

    test('is zero at the Kaaba itself', () {
      final km = QiblaService.distanceToKaabaKm(
        QiblaService.kaabaLatitude,
        QiblaService.kaabaLongitude,
      );
      expect(km, lessThan(0.5));
    });
  });

  group('angle helpers', () {
    test('normalize wraps into 0..360', () {
      expect(QiblaService.normalize(-10), closeTo(350, 1e-9));
      expect(QiblaService.normalize(370), closeTo(10, 1e-9));
      expect(QiblaService.normalize(720), closeTo(0, 1e-9));
    });

    test('signedDifference takes the short way round', () {
      expect(QiblaService.signedDifference(10, 350), closeTo(20, 1e-9));
      expect(QiblaService.signedDifference(350, 10), closeTo(-20, 1e-9));
      expect(QiblaService.signedDifference(90, 90), closeTo(0, 1e-9));
      // Exactly half a turn: +180 and -180 describe the same rotation, so only
      // the magnitude is meaningful.
      expect(
        QiblaService.signedDifference(0, 180).abs(),
        closeTo(180, 1e-9),
      );
    });

    test('relativeToDevice rotates the bearing into the device frame', () {
      expect(QiblaService.relativeToDevice(100, 100), closeTo(0, 1e-9));
      expect(QiblaService.relativeToDevice(100, 90), closeTo(10, 1e-9));
      expect(QiblaService.relativeToDevice(10, 350), closeTo(20, 1e-9));
    });

    test('applyDeclination adds the magnetic offset', () {
      expect(QiblaService.applyDeclination(100, 5), closeTo(105, 1e-9));
      expect(QiblaService.applyDeclination(358, 5), closeTo(3, 1e-9));
    });
  });

  group('accuracy buckets', () {
    test('maps the raw platform value', () {
      expect(QiblaService.bucketForAccuracy(null), AccuracyBucket.unknown);
      expect(QiblaService.bucketForAccuracy(double.nan), AccuracyBucket.unknown);
      expect(QiblaService.bucketForAccuracy(0.1), AccuracyBucket.high);
      expect(QiblaService.bucketForAccuracy(0.2), AccuracyBucket.high);
      expect(QiblaService.bucketForAccuracy(0.4), AccuracyBucket.medium);
      expect(QiblaService.bucketForAccuracy(0.9), AccuracyBucket.low);
    });
  });

  group('cardinalFor', () {
    test('maps headings onto the four quadrants', () {
      expect(cardinalFor(0), CompassCardinal.north);
      expect(cardinalFor(350), CompassCardinal.north);
      expect(cardinalFor(44), CompassCardinal.north);
      expect(cardinalFor(90), CompassCardinal.east);
      expect(cardinalFor(180), CompassCardinal.south);
      expect(cardinalFor(270), CompassCardinal.west);
      expect(cardinalFor(315), CompassCardinal.west);
    });
  });
}
