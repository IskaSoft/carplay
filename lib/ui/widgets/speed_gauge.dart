import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Animated circular speed gauge — the centrepiece of the dashboard.
class SpeedGauge extends StatelessWidget {
  const SpeedGauge({super.key, required this.speedValue, required this.unit});

  final double speedValue;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final displaySpeed = speedValue.clamp(0.0, 999.0);

    return SizedBox(
      width: 260,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer ring with arc fill
          CustomPaint(
            size: const Size(260, 260),
            painter: _ArcPainter(speedFraction: (displaySpeed / 200).clamp(0, 1)),
          ),
          // Speed number
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(end: displaySpeed),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
                builder: (_, value, __) => Text(
                  value.toStringAsFixed(0),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 80,
                    fontWeight: FontWeight.w200,
                    height: 1.0,
                    letterSpacing: -2,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                unit.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 13,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  const _ArcPainter({required this.speedFraction});
  final double speedFraction;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    // Track arc
    final trackPaint = Paint()
      ..color = Colors.white10
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    const startAngle = math.pi * 0.75;
    const sweepAngle = math.pi * 1.5;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      trackPaint,
    );

    // Fill arc
    if (speedFraction > 0) {
      final fillColor = _speedColor(speedFraction);
      final fillPaint = Paint()
        ..shader = SweepGradient(
          startAngle: startAngle,
          endAngle: startAngle + sweepAngle * speedFraction,
          colors: [fillColor.withOpacity(0.6), fillColor],
          transform: GradientRotation(startAngle),
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle * speedFraction,
        false,
        fillPaint,
      );
    }
  }

  Color _speedColor(double fraction) {
    if (fraction < 0.4) return const Color(0xFF00E676);   // green
    if (fraction < 0.7) return const Color(0xFFFFB74D);   // amber
    return const Color(0xFFEF5350);                        // red
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.speedFraction != speedFraction;
}
