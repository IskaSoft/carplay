import 'package:flutter/services.dart';

/// One-way bridge: Flutter → Native car display.
///
/// The native side (Android Auto / CarPlay) registers a MethodChannel handler
/// that receives speed data and refreshes the car UI template.
///
/// Channel name must match exactly in Kotlin and Swift.
class CarDataSender {
  CarDataSender._();
  static final CarDataSender instance = CarDataSender._();

  static const MethodChannel _channel = MethodChannel(
    'com.example.carplay/car_display',
  );

  // Received from background service or TripState
  Future<void> sendUpdate({
    required double currentSpeedKmh,
    required double averageSpeedKmh,
    required double totalDistanceMeters,
    required int movingTimeSeconds,
    required String tripStatus, // "idle" | "driving" | "paused" | "stopped"
    bool useImperial = false,
  }) async {
    try {
      await _channel.invokeMethod('updateDisplay', {
        'currentSpeedKmh': currentSpeedKmh,
        'averageSpeedKmh': averageSpeedKmh,
        'totalDistanceMeters': totalDistanceMeters,
        'movingTimeSeconds': movingTimeSeconds,
        'tripStatus': tripStatus,
        'useImperial': useImperial,
        // Pre-converted values the native layer can display directly
        'currentSpeedDisplay':
            useImperial
                ? (currentSpeedKmh * 0.621371).toStringAsFixed(0)
                : currentSpeedKmh.toStringAsFixed(0),
        'averageSpeedDisplay':
            useImperial
                ? (averageSpeedKmh * 0.621371).toStringAsFixed(0)
                : averageSpeedKmh.toStringAsFixed(0),
        'speedUnit': useImperial ? 'mph' : 'km/h',
        'distanceDisplay':
            useImperial
                ? '${(totalDistanceMeters / 1609.344).toStringAsFixed(2)} mi'
                : '${(totalDistanceMeters / 1000).toStringAsFixed(2)} km',
        'durationDisplay': _formatDuration(movingTimeSeconds),
      });
    } on PlatformException catch (e) {
      // Car display not connected — safe to ignore
      debugPrint('CarDataSender: PlatformException ${e.message}');
    } on MissingPluginException {
      // Running on simulator without native car library — safe to ignore
    }
  }

  static String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

// ignore: avoid_print
void debugPrint(String msg) => print('[Average] $msg');
