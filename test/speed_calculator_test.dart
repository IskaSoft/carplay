import 'package:flutter_test/flutter_test.dart';
import 'package:carplay/core/speed_calculator.dart';
import 'package:carplay/models/location_point.dart';

LocationPoint _pt(
  double lat,
  double lng,
  double speedMs,
  double acc,
  int tsMs,
) => LocationPoint(
  latitude: lat,
  longitude: lng,
  speedMs: speedMs,
  accuracy: acc,
  timestamp: DateTime.fromMillisecondsSinceEpoch(tsMs),
);

void main() {
  group('SpeedCalculator', () {
    test('haversine: 1 degree latitude ≈ 111.2 km', () {
      final a = _pt(51.5074, -0.1278, 0, 5, 0);
      final b = _pt(52.5074, -0.1278, 0, 5, 0);
      final d = SpeedCalculator.haversineDistance(a, b);
      expect(d / 1000, closeTo(111.2, 0.5));
    });

    test('haversine: same point = 0', () {
      final a = _pt(51.5074, -0.1278, 0, 5, 0);
      expect(SpeedCalculator.haversineDistance(a, a), closeTo(0, 0.001));
    });

    test('currentSpeed uses GPS chipset speed', () {
      final p = _pt(51.5, 0, 27.78, 5, 0); // 100 km/h
      expect(SpeedCalculator.computeCurrentSpeedKmh(p), closeTo(100.0, 0.1));
    });

    test('averageSpeed: 10 km / 600 s = 60 km/h', () {
      expect(
        SpeedCalculator.computeAverageSpeedKmh(10000, 600),
        closeTo(60.0, 0.01),
      );
    });

    test('averageSpeed: zero time returns 0', () {
      expect(SpeedCalculator.computeAverageSpeedKmh(10000, 0), 0.0);
    });

    test('shouldAcceptFix rejects accuracy > 25 m', () {
      final bad = _pt(51.5, 0, 10, 100, 0);
      expect(SpeedCalculator.shouldAcceptFix(bad), isFalse);
    });

    test('shouldAcceptFix rejects GPS jump > 300 km/h', () {
      final prev = _pt(51.5074, -0.1278, 10, 5, 0);
      final jump = _pt(52.5074, -0.1278, 10, 5, 1000); // 111 km in 1 s
      expect(SpeedCalculator.shouldAcceptFix(jump, previous: prev), isFalse);
    });

    test('unit conversions are correct', () {
      expect(SpeedCalculator.kmhToMph(100), closeTo(62.137, 0.01));
      expect(SpeedCalculator.metersToKm(1000), 1.0);
      expect(SpeedCalculator.metersToMiles(1609.344), closeTo(1.0, 0.001));
    });
  });
}
