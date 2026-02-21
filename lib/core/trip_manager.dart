import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:carplay/models/location_point.dart';
import 'package:carplay/models/trip_data.dart';
import 'package:carplay/core/speed_calculator.dart';
import 'package:carplay/core/gps_service.dart';

class TripState with ChangeNotifier {
  TripState._();
  static final TripState instance = TripState._();

  // ─── Live fields ──────────────────────────────────────────────────────────

  TripStatus status = TripStatus.idle;
  double currentSpeedKmh = 0;
  double averageSpeedKmh = 0;
  double totalDistanceMeters = 0;
  double maxSpeedKmh = 0;
  int movingTimeSeconds = 0;
  DateTime? tripStartTime;
  DateTime? pauseStartTime;
  LocationPoint? lastPoint;
  bool gpsSignalLost = false;

  bool autoStart = false;

  // ─── Internal ─────────────────────────────────────────────────────────────

  StreamSubscription<LocationPoint>? _gpsSub;
  Timer? _clockTimer;
  int _pausedSeconds = 0;

  // ─── Computed ─────────────────────────────────────────────────────────────

  int get elapsedSeconds {
    if (tripStartTime == null) return 0;
    final raw = DateTime.now().difference(tripStartTime!).inSeconds;
    return raw - _pausedSeconds;
  }

  String get formattedElapsed {
    final s = elapsedSeconds;
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  double get distanceKm => totalDistanceMeters / 1000.0;
  double get distanceMiles => totalDistanceMeters / 1609.344;

  // ─── Public control ───────────────────────────────────────────────────────

  /// Returns true if trip started successfully, false if GPS unavailable.
  Future<bool> startTrip() async {
    if (status == TripStatus.driving) return true;

    _reset();

    // FIX: Cancel any leftover GPS listener from previous trip BEFORE
    // starting a new one. This is what makes NEW TRIP work correctly.
    await _gpsSub?.cancel();
    _gpsSub = null;

    // FIX: GpsService.start() now returns bool.
    // If GPS is off or permission denied, abort cleanly — stay in idle state
    // so the dashboard can show the correct dialog to the user.
    final gpsStarted = await GpsService.instance.start();
    if (!gpsStarted) {
      gpsSignalLost = true;
      notifyListeners();
      return false; // Dashboard will show GPS disabled dialog
    }

    status = TripStatus.driving;
    tripStartTime = DateTime.now();
    gpsSignalLost = false;

    // Subscribe to the GPS broadcast stream
    _gpsSub = GpsService.instance.locationStream.listen(
      _onGpsFix,
      onError: _onGpsError,
    );

    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (status == TripStatus.driving) {
        movingTimeSeconds++;
        notifyListeners();
      }
    });

    notifyListeners();
    return true;
  }

  void pauseTrip() {
    if (status != TripStatus.driving) return;
    status = TripStatus.paused;
    pauseStartTime = DateTime.now();
    notifyListeners();
  }

  void resumeTrip() {
    if (status != TripStatus.paused) return;
    if (pauseStartTime != null) {
      _pausedSeconds += DateTime.now().difference(pauseStartTime!).inSeconds;
    }
    pauseStartTime = null;
    status = TripStatus.driving;
    notifyListeners();
  }

  Future<TripData?> stopTrip() async {
    if (status == TripStatus.idle) return null;

    status = TripStatus.stopped;
    _clockTimer?.cancel();
    _clockTimer = null;

    await _gpsSub?.cancel();
    _gpsSub = null;

    await GpsService.instance.stop();

    final trip = TripData(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      startTime: tripStartTime ?? DateTime.now(),
      endTime: DateTime.now(),
      totalDistanceMeters: totalDistanceMeters,
      averageSpeedKmh: averageSpeedKmh,
      maxSpeedKmh: maxSpeedKmh,
      durationSeconds: elapsedSeconds,
      stateIndex: 'stopped',
    );

    final box = Hive.box<TripData>('trips');
    await box.add(trip);

    _reset();
    notifyListeners();
    return trip;
  }

  // ─── GPS processing ───────────────────────────────────────────────────────

  void _onGpsFix(LocationPoint fix) {
    gpsSignalLost = false;

    final speedKmh = SpeedCalculator.computeCurrentSpeedKmh(
      fix,
      previous: lastPoint,
    );
    currentSpeedKmh = speedKmh;
    if (speedKmh > maxSpeedKmh) maxSpeedKmh = speedKmh;

    // Auto-start
    if (status == TripStatus.idle && autoStart && speedKmh > 10.0) {
      startTrip();
      return;
    }

    // Accumulate distance when driving
    if (status == TripStatus.driving) {
      if (lastPoint != null &&
          SpeedCalculator.shouldAcceptFix(fix, previous: lastPoint)) {
        final d = SpeedCalculator.haversineDistance(lastPoint!, fix);
        if (d > 3) totalDistanceMeters += d;
      }

      averageSpeedKmh = SpeedCalculator.computeAverageSpeedKmh(
        totalDistanceMeters,
        movingTimeSeconds,
      );
    }

    lastPoint = fix;
    notifyListeners();
  }

  void _onGpsError(Object error) {
    gpsSignalLost = true;
    notifyListeners();
  }

  // ─── Private ──────────────────────────────────────────────────────────────

  void _reset() {
    currentSpeedKmh = 0;
    averageSpeedKmh = 0;
    totalDistanceMeters = 0;
    maxSpeedKmh = 0;
    movingTimeSeconds = 0;
    _pausedSeconds = 0;
    tripStartTime = null;
    pauseStartTime = null;
    lastPoint = null;
    gpsSignalLost = false;
  }
}

enum TripStatus { idle, driving, paused, stopped }
