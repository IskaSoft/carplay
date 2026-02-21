import 'package:permission_handler/permission_handler.dart';

/// Handles all runtime permission requests for the app.
class PermissionService {
  PermissionService._();
  static final PermissionService instance = PermissionService._();

  /// Returns true only when ALL required permissions are granted.
  Future<bool> requestAll() async {
    // Always-while-driving requires background location
    final results = await [
      Permission.location,
      Permission.locationAlways,
      Permission.notification, // required for foreground service on Android 13+
    ].request();

    final locationOk = results[Permission.location] == PermissionStatus.granted;
    final bgOk = results[Permission.locationAlways] == PermissionStatus.granted;

    return locationOk && bgOk;
  }

  Future<bool> hasLocationPermission() async {
    final status = await Permission.location.status;
    return status == PermissionStatus.granted;
  }

  Future<bool> hasBackgroundLocationPermission() async {
    final status = await Permission.locationAlways.status;
    return status == PermissionStatus.granted;
  }

  Future<bool> isLocationServiceEnabled() async {
    return Permission.location.serviceStatus.then(
      (s) => s == ServiceStatus.enabled,
    );
  }

  Future<void> openSettings() => openAppSettings();
}
