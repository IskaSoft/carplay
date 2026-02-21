import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:carplay/models/location_point.dart';

class GpsService {
  GpsService._();
  static final GpsService instance = GpsService._();

  StreamSubscription<Position>? _subscription;

  // Single long-lived broadcast controller for the app lifetime.
  // Never closed so TripManager can re-subscribe on every new trip.
  final StreamController<LocationPoint> _controller =
      StreamController<LocationPoint>.broadcast();

  Stream<LocationPoint> get locationStream => _controller.stream;
  bool get isTracking => _subscription != null;

  static const LocationSettings _locationSettings = LocationSettings(
    accuracy: LocationAccuracy.bestForNavigation,
    distanceFilter: 0,
    timeLimit: null,
  );

  // ─── Public API ───────────────────────────────────────────────────────────

  /// Returns false if GPS service is disabled or permission denied.
  /// Returns true when streaming started successfully.
  Future<bool> start() async {
    // Cancel any existing subscription before starting fresh.
    // This is what makes NEW TRIP work correctly after STOP TRIP.
    if (_subscription != null) {
      await _subscription!.cancel();
      _subscription = null;
    }

    // FIX: Check GPS service BEFORE starting the stream.
    // Old code added errors to the controller immediately, but TripManager
    // had not yet called listen() at that point — errors were lost silently.
    // Now we return false so the caller (TripManager / dashboard) can react.
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false; // Caller shows "GPS is turned off" dialog
    }

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false; // Caller shows permission dialog
    }

    _subscription = Geolocator.getPositionStream(
      locationSettings: _locationSettings,
    ).listen(
      (position) => _controller.add(_fromPosition(position)),
      onError: (Object e) {
        // GPS lost mid-trip (tunnel, signal lost) — emit error so
        // TripManager can set gpsSignalLost = true. Keep alive to recover.
        _controller.addError(e);
      },
      cancelOnError: false,
    );

    return true;
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    // Do NOT close _controller — it must stay open for the next trip.
  }

  Future<LocationPoint?> currentPosition() async {
    try {
      final p = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 10),
      );
      return _fromPosition(p);
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    stop();
    _controller.close();
  }

  LocationPoint _fromPosition(Position p) {
    return LocationPoint(
      latitude: p.latitude,
      longitude: p.longitude,
      speedMs: p.speed,
      accuracy: p.accuracy,
      timestamp: p.timestamp,
      altitude: p.altitude,
    );
  }
}
