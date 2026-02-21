import 'package:hive/hive.dart';

part 'trip_data.g.dart';

enum TripStatus { idle, driving, paused, stopped }

/// Immutable summary stored after each trip completes.
@HiveType(typeId: 1)
class TripData extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final DateTime startTime;

  @HiveField(2)
  final DateTime? endTime;

  @HiveField(3)
  final double totalDistanceMeters;

  @HiveField(4)
  final double averageSpeedKmh;

  @HiveField(5)
  final double maxSpeedKmh;

  @HiveField(6)
  final int durationSeconds;

  @HiveField(7)
  final String stateIndex; // stored as string for portability

  TripData({
    required this.id,
    required this.startTime,
    this.endTime,
    required this.totalDistanceMeters,
    required this.averageSpeedKmh,
    required this.maxSpeedKmh,
    required this.durationSeconds,
    required this.stateIndex,
  });

  double get totalDistanceKm => totalDistanceMeters / 1000.0;
  double get totalDistanceMiles => totalDistanceMeters / 1609.344;

  String get formattedDuration {
    final h = durationSeconds ~/ 3600;
    final m = (durationSeconds % 3600) ~/ 60;
    final s = durationSeconds % 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  TripData copyWith({
    DateTime? endTime,
    double? totalDistanceMeters,
    double? averageSpeedKmh,
    double? maxSpeedKmh,
    int? durationSeconds,
    String? stateIndex,
  }) {
    return TripData(
      id: id,
      startTime: startTime,
      endTime: endTime ?? this.endTime,
      totalDistanceMeters: totalDistanceMeters ?? this.totalDistanceMeters,
      averageSpeedKmh: averageSpeedKmh ?? this.averageSpeedKmh,
      maxSpeedKmh: maxSpeedKmh ?? this.maxSpeedKmh,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      stateIndex: stateIndex ?? this.stateIndex,
    );
  }
}
