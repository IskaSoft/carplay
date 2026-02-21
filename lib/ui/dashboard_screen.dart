import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:location/location.dart' as loc;
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:carplay/core/trip_manager.dart';
import 'package:carplay/platform_bridge/car_data_sender.dart';
import 'package:carplay/services/permission_service.dart';
import 'package:carplay/ui/settings_screen.dart';
import 'package:carplay/ui/trip_screen.dart';
import 'package:carplay/ui/widgets/speed_gauge.dart';
import 'package:carplay/ui/widgets/stat_card.dart';
import 'package:carplay/ui/widgets/gps_status_bar.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    final ok = await PermissionService.instance.hasLocationPermission();
    if (!ok && mounted) _showPermissionDialog();
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => AlertDialog(
            backgroundColor: const Color(0xFF12121E),
            title: const Text(
              'Location Permission Required',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'This app needs location permission to track speed and distance.\n\n'
              'Please allow "All the time" access for background tracking.',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  PermissionService.instance.requestAll();
                },
                child: const Text(
                  'Grant Permission',
                  style: TextStyle(color: Color(0xFF00E676)),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  PermissionService.instance.openSettings();
                },
                child: const Text(
                  'Open Settings',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            ],
          ),
    );
  }

  // Shows the NATIVE Android "enable location" popup dialog using the
  // location package which calls GoogleApiClient LocationSettingsRequest —
  // the exact same dialog with "No thanks" / "Enable" buttons.
  // Returns true if user enabled GPS, false if they declined.
  Future<bool> _requestGpsEnable() async {
    final location = loc.Location();
    try {
      // requestService() shows the native Android GPS enable dialog.
      // If GPS is already on it returns true immediately.
      // If user taps "Enable" it returns true.
      // If user taps "No thanks" it returns false.
      final enabled = await location.requestService();
      return enabled;
    } catch (_) {
      // Fallback: open location settings page if dialog fails
      await Geolocator.openLocationSettings();
      return false;
    }
  }

  Future<void> _toggleTrip(TripState trip) async {
    if (trip.status == TripStatus.idle || trip.status == TripStatus.stopped) {
      // Check location permission first
      final hasPermission =
          await PermissionService.instance.hasLocationPermission();
      if (!hasPermission) {
        if (mounted) _showPermissionDialog();
        return;
      }

      // Check GPS service (is location turned on in phone settings?)
      final gpsEnabled =
          await PermissionService.instance.isLocationServiceEnabled();
      if (!gpsEnabled) {
        // Show native Android "enable GPS" popup dialog
        final userEnabled = await _requestGpsEnable();
        if (!userEnabled) return; // User tapped "No thanks" — do nothing
        // User tapped "Enable" — GPS is now on, continue starting trip
      }

      await WakelockPlus.enable();
      final started = await trip.startTrip();
      if (!started) {
        await WakelockPlus.disable();
        // GPS still not available after enable attempt — open settings
        if (mounted) await _requestGpsEnable();
      }
    } else if (trip.status == TripStatus.driving) {
      final result = await trip.stopTrip();
      await WakelockPlus.disable();
      if (result != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TripScreen(trip: result)),
        );
      }
    } else if (trip.status == TripStatus.paused) {
      trip.resumeTrip();
    }
  }

  void _pauseTrip(TripState trip) {
    trip.pauseTrip();
  }

  @override
  Widget build(BuildContext context) {
    // FIX: Wrap with ValueListenableBuilder on the Hive settings box.
    // This makes the dashboard rebuild INSTANTLY when the toggle changes —
    // no need to come back from Settings, no restart required.
    return ValueListenableBuilder(
      valueListenable: Hive.box('settings').listenable(),
      builder: (context, Box settingsBox, _) {
        final useImperial =
            settingsBox.get('useImperial', defaultValue: false) as bool;
        return Consumer<TripState>(
          builder: (context, trip, _) {
            return _buildScaffold(context, trip, useImperial);
          },
        );
      },
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    TripState trip,
    bool useImperial,
  ) {
    // Send to Android Auto on every state update
    CarDataSender.instance.sendUpdate(
      currentSpeedKmh: trip.currentSpeedKmh,
      averageSpeedKmh: trip.averageSpeedKmh,
      totalDistanceMeters: trip.totalDistanceMeters,
      movingTimeSeconds: trip.movingTimeSeconds,
      tripStatus: trip.status.name,
      useImperial: useImperial,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: _buildAppBar(context, trip),
      body: SafeArea(
        child: Column(
          children: [
            GpsStatusBar(
              isLost: trip.gpsSignalLost,
              isTracking:
                  (trip.status == TripStatus.driving ||
                      trip.status == TripStatus.paused) &&
                  !trip.gpsSignalLost,
            ),
            Expanded(child: _buildBody(context, trip, useImperial)),
            const SizedBox(height: 24),
            _buildControls(context, trip),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, TripState trip) {
    return AppBar(
      backgroundColor: const Color(0xFF0A0A0F),
      elevation: 0,
      title: Row(
        children: [
          const Text(
            'CarPlay',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w300,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(width: 8),
          if (trip.status == TripStatus.driving)
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF00E676),
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.history_rounded, color: Colors.white54),
          onPressed:
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TripHistoryScreen()),
              ),
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined, color: Colors.white54),
          onPressed:
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, TripState trip, bool useImperial) {
    final speed =
        useImperial ? (trip.currentSpeedKmh * 0.621371) : trip.currentSpeedKmh;
    final unit = useImperial ? 'mph' : 'km/h';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SpeedGauge(speedValue: speed, unit: unit),
          const SizedBox(height: 48),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  label: 'AVG SPEED',
                  value:
                      useImperial
                          ? (trip.averageSpeedKmh * 0.621371).toStringAsFixed(1)
                          : trip.averageSpeedKmh.toStringAsFixed(1),
                  unit: unit,
                  icon: Icons.show_chart_rounded,
                  color: const Color(0xFF64B5F6),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  label: 'DISTANCE',
                  value:
                      useImperial
                          ? (trip.totalDistanceMeters / 1609.344)
                              .toStringAsFixed(2)
                          : (trip.totalDistanceMeters / 1000).toStringAsFixed(
                            2,
                          ),
                  unit: useImperial ? 'mi' : 'km',
                  icon: Icons.straighten_rounded,
                  color: const Color(0xFFFFB74D),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  label: 'DURATION',
                  value: trip.formattedElapsed,
                  unit: '',
                  icon: Icons.timer_outlined,
                  color: const Color(0xFFCE93D8),
                  isTime: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  label: 'MAX SPEED',
                  value:
                      useImperial
                          ? (trip.maxSpeedKmh * 0.621371).toStringAsFixed(1)
                          : trip.maxSpeedKmh.toStringAsFixed(1),
                  unit: unit,
                  icon: Icons.speed_rounded,
                  color: const Color(0xFFEF9A9A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControls(BuildContext context, TripState trip) {
    final isDriving = trip.status == TripStatus.driving;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          AnimatedOpacity(
            opacity: isDriving ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: GestureDetector(
              onTap: isDriving ? () => _pauseTrip(trip) : null,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C2E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Icon(
                  Icons.pause_rounded,
                  color: Colors.white70,
                  size: 28,
                ),
              ),
            ),
          ),
          if (isDriving) const SizedBox(width: 12),
          Expanded(
            child: _TripButton(
              status: trip.status,
              onTap: () => _toggleTrip(trip),
            ),
          ),
        ],
      ),
    );
  }
}
////////////////

// ─── iOS GPS Enable Dialog ────────────────────────────────────────────────────
// Styled to match iOS native system alert appearance.
// Apple does not expose a programmatic GPS enable API like Android,
// so we show this dialog then redirect to Location Settings.

class _IosGpsDialog extends StatelessWidget {
  const _IosGpsDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          // iOS system alert uses a frosted white background
          color: const Color(0xFFF2F2F7),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Icon ────────────────────────────────────────────────────────
            const SizedBox(height: 24),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_on_rounded,
                color: Color(0xFF007AFF), // iOS blue
                size: 30,
              ),
            ),
            const SizedBox(height: 16),

            // ── Title ───────────────────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Location Services Off',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF000000),
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.4,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // ── Body ────────────────────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'To track your speed and distance, enable Location Services in Settings.\n\n'
                'Go to:\nSettings → Privacy → Location Services',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF3C3C43),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Divider ─────────────────────────────────────────────────────
            const Divider(height: 1, color: Color(0xFFD1D1D6)),

            // ── Buttons — iOS style: stacked, full width ─────────────────────
            // "Settings" button (primary — blue)
            SizedBox(
              width: double.infinity,
              child: TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(14),
                      bottomRight: Radius.circular(14),
                    ),
                  ),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Open Settings',
                  style: TextStyle(
                    color: Color(0xFF007AFF),
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            // Divider between buttons
            const Divider(height: 1, color: Color(0xFFD1D1D6)),

            // "Not Now" button (secondary — normal weight blue)
            SizedBox(
              width: double.infinity,
              child: TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(14),
                      bottomRight: Radius.circular(14),
                    ),
                  ),
                ),
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Not Now',
                  style: TextStyle(
                    color: Color(0xFF007AFF),
                    fontSize: 17,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}
// ─── Trip Button ──────────────────────────────────────────────────────────────

class _TripButton extends StatelessWidget {
  const _TripButton({required this.status, required this.onTap});

  final TripStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      TripStatus.idle => (
        'START TRIP',
        const Color(0xFF00E676),
        Icons.play_arrow_rounded,
      ),
      TripStatus.driving => (
        'STOP TRIP',
        const Color(0xFFEF5350),
        Icons.stop_rounded,
      ),
      TripStatus.paused => (
        'RESUME',
        const Color(0xFFFFB74D),
        Icons.play_arrow_rounded,
      ),
      TripStatus.stopped => (
        'NEW TRIP',
        const Color(0xFF00E676),
        Icons.play_arrow_rounded,
      ),
    };

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.6), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
