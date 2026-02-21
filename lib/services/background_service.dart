import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:carplay/core/gps_service.dart';
import 'package:carplay/core/speed_calculator.dart';
import 'package:carplay/core/trip_manager.dart';
import 'package:carplay/models/location_point.dart';
import 'package:carplay/models/trip_data.dart';

/// Bootstraps flutter_background_service so tracking persists when the
/// phone screen turns off or the user switches apps.
///
/// Architecture:
///   Main isolate  ←→  Background isolate (this file)
///   The background isolate owns the GPS stream and TripState.
///   It broadcasts updates to the main isolate via ServiceInstance events.
class BackgroundServiceManager {
  static const String _channelId = 'com.example.carplay.tracking';
  static const String _channelName = 'CarPlay – Speed Tracking';

  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    await service.configure(
      // ── Android: foreground service with persistent notification ──────────
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        isForegroundMode: true,
        autoStart: false,
        notificationChannelId: _channelId,
        initialNotificationTitle: 'CarPlay',
        initialNotificationContent: 'Speed tracking active',
        foregroundServiceNotificationId: 888,
        foregroundServiceTypes: [AndroidForegroundType.location],
      ),
      // ── iOS: background fetch + location ─────────────────────────────────
      iosConfiguration: IosConfiguration(
        onForeground: _onStart,
        onBackground: _onIosBackground,
        autoStart: false,
      ),
    );
  }

  static Future<bool> start() => FlutterBackgroundService().startService();
  static Future<bool> isRunning() => FlutterBackgroundService().isRunning();

  static void stop() => FlutterBackgroundService().invoke('stopService');

  /// Send a command to the background isolate.
  static void send(String event, [Map<String, dynamic>? data]) =>
      FlutterBackgroundService().invoke(event, data);

  // ─── Background isolate entry point ──────────────────────────────────────

  @pragma('vm:entry-point')
  static Future<void> _onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    // Re-open Hive in the background isolate
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(LocationPointAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(TripDataAdapter());
    }
    await Hive.openBox<TripData>('trips');

    // Local state for this isolate
    double totalDistanceMeters = 0;
    double currentSpeedKmh = 0;
    double averageSpeedKmh = 0;
    int movingTimeSeconds = 0;
    double maxSpeedKmh = 0;
    LocationPoint? lastPoint;
    bool isActive = false;

    // ── Listen for commands from main isolate ─────────────────────────────
    service.on('start').listen((_) async {
      isActive = true;
      totalDistanceMeters = 0;
      currentSpeedKmh = 0;
      averageSpeedKmh = 0;
      movingTimeSeconds = 0;
      maxSpeedKmh = 0;
      lastPoint = null;
      await GpsService.instance.start();
    });

    service.on('stop').listen((_) async {
      isActive = false;
      await GpsService.instance.stop();
      service.invoke('stopped', {});
    });

    service.on('stopService').listen((_) async {
      await GpsService.instance.stop();
      service.stopSelf();
    });

    // ── GPS stream ────────────────────────────────────────────────────────
    Timer? clockTimer;
    clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (isActive) movingTimeSeconds++;
    });

    GpsService.instance.locationStream.listen((fix) {
      if (!isActive) return;

      currentSpeedKmh = SpeedCalculator.computeCurrentSpeedKmh(
        fix,
        previous: lastPoint,
      );
      if (currentSpeedKmh > maxSpeedKmh) maxSpeedKmh = currentSpeedKmh;

      if (lastPoint != null &&
          SpeedCalculator.shouldAcceptFix(fix, previous: lastPoint)) {
        totalDistanceMeters += SpeedCalculator.haversineDistance(
          lastPoint!,
          fix,
        );
      }

      averageSpeedKmh = SpeedCalculator.computeAverageSpeedKmh(
        totalDistanceMeters,
        movingTimeSeconds,
      );

      lastPoint = fix;

      // Broadcast to main isolate & car displays
      service.invoke('update', {
        'currentSpeedKmh': currentSpeedKmh,
        'averageSpeedKmh': averageSpeedKmh,
        'totalDistanceMeters': totalDistanceMeters,
        'movingTimeSeconds': movingTimeSeconds,
        'maxSpeedKmh': maxSpeedKmh,
        'lat': fix.latitude,
        'lng': fix.longitude,
        'accuracy': fix.accuracy,
      });

      // Update foreground notification
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: 'Average – ${currentSpeedKmh.toStringAsFixed(0)} km/h',
          content:
              'Avg ${averageSpeedKmh.toStringAsFixed(0)} km/h · ${(totalDistanceMeters / 1000).toStringAsFixed(2)} km',
        );
      }
    });
  }

  @pragma('vm:entry-point')
  static Future<bool> _onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    return true;
  }
}
