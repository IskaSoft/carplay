import 'package:hive/hive.dart';

part 'location_point.g.dart';

/// A single GPS fix captured during a trip.
/// speedMs comes directly from the GPS chipset via geolocator.
@HiveType(typeId: 0)
class LocationPoint extends HiveObject {
  @HiveField(0)
  final double latitude;

  @HiveField(1)
  final double longitude;

  @HiveField(2)
  final double speedMs; // m/s as reported by GPS hardware

  @HiveField(3)
  final double accuracy; // horizontal accuracy in metres

  @HiveField(4)
  final DateTime timestamp;

  @HiveField(5)
  final double altitude;

  LocationPoint({
    required this.latitude,
    required this.longitude,
    required this.speedMs,
    required this.accuracy,
    required this.timestamp,
    this.altitude = 0.0,
  });

  double get speedKmh => speedMs >= 0 ? speedMs * 3.6 : 0.0;
  double get speedMph => speedMs >= 0 ? speedMs * 2.23694 : 0.0;

  bool get hasValidSpeed => speedMs >= 0;

  // FIX: Changed from 10.0 → 25.0 metres.
  // The old 10m threshold was far too strict. In urban areas most Android
  // phones report 12–20m accuracy even with a clear sky. With 10m, almost
  // every fix was rejected → shouldAcceptFix always returned false →
  // distance never accumulated and speed fell back to noisy haversine only.
  // 25m is the industry-standard threshold used by Google Maps and Waze.
  bool get isAccurate => accuracy <= 25.0;

  @override
  String toString() =>
      'LocationPoint(${speedKmh.toStringAsFixed(1)} km/h, acc ${accuracy.toStringAsFixed(0)} m)';
}
