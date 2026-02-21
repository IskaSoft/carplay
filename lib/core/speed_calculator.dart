import 'dart:math' as math;
import 'package:carplay/models/location_point.dart';

/// Pure calculation engine — no Flutter or platform dependencies.
class SpeedCalculator {
  SpeedCalculator._();

  static const double _earthRadiusMeters = 6371000.0;

  // ─── Haversine ────────────────────────────────────────────────────────────

  /// Returns distance in metres between two GPS coordinates.
  static double haversineDistance(LocationPoint a, LocationPoint b) {
    final lat1 = _toRad(a.latitude);
    final lat2 = _toRad(b.latitude);
    final dLat = _toRad(b.latitude - a.latitude);
    final dLon = _toRad(b.longitude - a.longitude);
    final sinDLat = math.sin(dLat / 2);
    final sinDLon = math.sin(dLon / 2);
    final h =
        sinDLat * sinDLat + math.cos(lat1) * math.cos(lat2) * sinDLon * sinDLon;
    return 2 * _earthRadiusMeters * math.asin(math.sqrt(h));
  }

  // ─── Speed ────────────────────────────────────────────────────────────────

  // FIX: Restore GPS chipset Doppler speed as primary source.
  //
  // Your previous version (haversine-only) had two problems:
  //
  // 1. PHANTOM SPEED WHEN STATIONARY: Even a parked phone drifts 2–5 metres
  //    between GPS fixes. With 1-second updates, haversine gives 7–18 km/h
  //    when you are completely still. The chipset Doppler never does this —
  //    it reads ~0.0 m/s when stationary.
  //
  // 2. WRONG AVERAGE SPEED: Because haversine reported phantom speed while
  //    stopped (red lights, parking), average speed was inflated the entire
  //    trip — sometimes by 10–20 km/h on city drives.
  //
  // GPS chipset Doppler is accurate to ±0.05 m/s even at walking speed.
  // Haversine is kept as fallback only for old chipsets that return speedMs < 0.
  static double computeCurrentSpeedKmh(
    LocationPoint point, {
    LocationPoint? previous,
  }) {
    // ✅ PRIMARY: GPS chipset Doppler speed — accurate, noise-free at stops
    if (point.hasValidSpeed && point.isAccurate) {
      return point.speedKmh;
    }

    // ✅ FALLBACK: haversine Δdist/Δt only when chipset speed unavailable
    if (previous != null) {
      final distM = haversineDistance(previous, point);
      final dtSec =
          point.timestamp
              .difference(previous.timestamp)
              .inMilliseconds
              .toDouble() /
          1000.0;
      if (dtSec > 0.1 && dtSec < 10.0) {
        return (distM / dtSec) * 3.6;
      }
    }

    return 0.0;
  }

  /// averageSpeed = totalDistance / movingTime
  static double computeAverageSpeedKmh(
    double totalDistanceMeters,
    int movingTimeSeconds,
  ) {
    if (movingTimeSeconds <= 0) return 0.0;
    return (totalDistanceMeters / movingTimeSeconds) * 3.6;
  }

  // ─── Unit conversion ──────────────────────────────────────────────────────

  static double kmhToMph(double kmh) => kmh * 0.621371;
  static double metersToMiles(double m) => m / 1609.344;
  static double metersToKm(double m) => m / 1000.0;

  // ─── Noise filter ─────────────────────────────────────────────────────────

  /// Returns true when the fix should be accepted for distance accumulation.
  static bool shouldAcceptFix(LocationPoint fix, {LocationPoint? previous}) {
    if (!fix.isAccurate) return false;
    if (previous == null) return true;
    final distM = haversineDistance(previous, fix);
    final dtSec =
        fix.timestamp.difference(previous.timestamp).inMilliseconds / 1000.0;
    if (dtSec <= 0) return false;
    // Reject GPS glitches (> 300 km/h implied speed between two fixes)
    final impliedSpeedKmh = (distM / dtSec) * 3.6;
    if (impliedSpeedKmh > 300) return false;
    return true;
  }

  static double _toRad(double deg) => deg * math.pi / 180.0;
}
