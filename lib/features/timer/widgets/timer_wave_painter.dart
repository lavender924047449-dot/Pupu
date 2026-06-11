import 'dart:math' as math;

import 'package:flutter/material.dart';

class TimerWavePainter extends CustomPainter {
  TimerWavePainter({
    required this.animationValue,
    required this.currentPhase,
    required this.isAnimating,
  });

  final double animationValue;
  final double currentPhase;
  final bool isAnimating;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.65)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final centerY = size.height / 2;
    final amplitude = 5.0;
    final wavelength = size.width / 2.5;

    if (!isAnimating) {
      canvas.drawLine(
        Offset(0, centerY),
        Offset(size.width, centerY),
        paint,
      );
      return;
    }

    final path = Path();
    final step = 2.0;
    final frequency = 2 * math.pi / wavelength;

    for (double x = 0; x <= size.width; x += step) {
      final y = centerY + amplitude * math.sin(frequency * x - currentPhase);
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(TimerWavePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.currentPhase != currentPhase ||
        oldDelegate.isAnimating != isAnimating;
  }
}
