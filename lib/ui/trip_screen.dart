import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../models/trip_data.dart';

/// Displays the summary of a just-completed trip.
class TripScreen extends StatelessWidget {
  const TripScreen({super.key, required this.trip});
  final TripData trip;

  @override
  Widget build(BuildContext context) {
    // FIX: Read imperial setting from Hive — same source of truth as dashboard.
    // Old code hardcoded 'km' for the big number and 'mi' for the stat card,
    // showing both units at the same time (1.23 km + 0.76 mi = confusing).
    final box = Hive.box('settings');
    final useImperial = box.get('useImperial', defaultValue: false) as bool;

    final distanceValue =
        useImperial
            ? trip.totalDistanceMiles.toStringAsFixed(2)
            : trip.totalDistanceKm.toStringAsFixed(2);
    final distanceUnit = useImperial ? 'mi' : 'km';

    final avgSpeed =
        useImperial
            ? '${(trip.averageSpeedKmh * 0.621371).toStringAsFixed(1)} mph'
            : '${trip.averageSpeedKmh.toStringAsFixed(1)} km/h';

    final maxSpeed =
        useImperial
            ? '${(trip.maxSpeedKmh * 0.621371).toStringAsFixed(1)} mph'
            : '${trip.maxSpeedKmh.toStringAsFixed(1)} km/h';

    final distanceStat =
        useImperial
            ? '${trip.totalDistanceMiles.toStringAsFixed(2)} mi'
            : '${trip.totalDistanceKm.toStringAsFixed(2)} km';

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        elevation: 0,
        title: const Text(
          'Trip Summary',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w300,
            letterSpacing: 2,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date and time range
              Text(
                DateFormat('EEEE, d MMMM yyyy').format(trip.startTime),
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 13,
                  letterSpacing: 1,
                ),
              ),
              Text(
                '${DateFormat('HH:mm').format(trip.startTime)} — '
                '${trip.endTime != null ? DateFormat('HH:mm').format(trip.endTime!) : '--:--'}',
                style: const TextStyle(color: Colors.white70, fontSize: 15),
              ),

              const SizedBox(height: 40),

              // Big distance — now uses correct unit
              Center(
                child: Column(
                  children: [
                    Text(
                      distanceValue,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 72,
                        fontWeight: FontWeight.w200,
                        letterSpacing: -2,
                      ),
                    ),
                    Text(
                      distanceUnit,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 16,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Stats grid — all consistent unit
              Row(
                children: [
                  _SummaryTile(
                    label: 'DURATION',
                    value: trip.formattedDuration,
                    color: const Color(0xFFCE93D8),
                  ),
                  const SizedBox(width: 12),
                  _SummaryTile(
                    label: 'AVG SPEED',
                    value: avgSpeed,
                    color: const Color(0xFF64B5F6),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _SummaryTile(
                    label: 'MAX SPEED',
                    value: maxSpeed,
                    color: const Color(0xFFEF9A9A),
                  ),
                  const SizedBox(width: 12),
                  _SummaryTile(
                    label: 'DISTANCE',
                    value: distanceStat,
                    color: const Color(0xFFFFB74D),
                  ),
                ],
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'DONE',
                    style: TextStyle(color: Colors.white, letterSpacing: 2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF12121E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: color.withOpacity(0.7),
                fontSize: 10,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w300,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lists all past trips from Hive.
class TripHistoryScreen extends StatelessWidget {
  const TripHistoryScreen({super.key});

  Future<void> _deleteTrip(BuildContext context, TripData trip) async {
    // Show confirmation dialog before deleting
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            backgroundColor: const Color(0xFF12121E),
            title: const Text(
              'Delete Trip?',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'This trip will be permanently deleted.',
              style: TextStyle(color: Colors.white54),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white38),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Color(0xFFEF5350)),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await trip.delete(); // Hive HiveObject.delete() removes it from the box
    }
  }

  @override
  Widget build(BuildContext context) {
    final tripsBox = Hive.box<TripData>('trips');

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        elevation: 0,
        title: const Text(
          'Trip History',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w300,
            letterSpacing: 2,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ValueListenableBuilder(
        valueListenable: tripsBox.listenable(),
        builder: (context, Box<TripData> box, _) {
          // Read imperial setting inside builder so it stays reactive
          final settingsBox = Hive.box('settings');
          final useImperial =
              settingsBox.get('useImperial', defaultValue: false) as bool;

          final trips = box.values.toList().reversed.toList();

          if (trips.isEmpty) {
            return const Center(
              child: Text(
                'No trips yet',
                style: TextStyle(color: Colors.white38),
              ),
            );
          }

          return ListView.builder(
            itemCount: trips.length,
            itemBuilder: (context, i) {
              final trip = trips[i];
              final dist =
                  useImperial
                      ? '${trip.totalDistanceMiles.toStringAsFixed(2)} mi'
                      : '${trip.totalDistanceKm.toStringAsFixed(2)} km';
              final avg =
                  useImperial
                      ? '${(trip.averageSpeedKmh * 0.621371).toStringAsFixed(1)} mph'
                      : '${trip.averageSpeedKmh.toStringAsFixed(1)} km/h';

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF12121E),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.only(
                    left: 16,
                    right: 4,
                    top: 8,
                    bottom: 8,
                  ),
                  title: Text(
                    dist,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w300,
                      fontSize: 18,
                    ),
                  ),
                  subtitle: Text(
                    'Avg $avg  ·  ${trip.formattedDuration}',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  // Date on the left of the delete icon
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat(
                          'dd MMM\nHH:mm',
                        ).format(trip.startTime.toLocal()),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Delete icon button
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: Color(0xFFEF5350),
                          size: 20,
                        ),
                        tooltip: 'Delete trip',
                        onPressed: () => _deleteTrip(context, trip),
                      ),
                    ],
                  ),
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TripScreen(trip: trip),
                        ),
                      ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) {
      return '${duration.inMinutes.toString().padLeft(2, '0')}:'
          '${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
    }
    return '${duration.inHours.toString().padLeft(2, '0')}:'
        '${(duration.inMinutes % 60).toString().padLeft(2, '0')}:'
        '${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
  }
}
