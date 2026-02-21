import 'package:flutter/material.dart';

class GpsStatusBar extends StatelessWidget {
  const GpsStatusBar({
    super.key,
    required this.isLost,
    required this.isTracking,
  });

  final bool isLost;
  final bool isTracking;

  @override
  Widget build(BuildContext context) {
    if (!isTracking && !isLost) return const SizedBox.shrink();

    final (text, color, icon) = isLost
        ? ('GPS Signal Lost', const Color(0xFFEF5350), Icons.gps_off_rounded)
        : ('GPS Active', const Color(0xFF00E676), Icons.gps_fixed_rounded);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      color: color.withOpacity(0.08),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
