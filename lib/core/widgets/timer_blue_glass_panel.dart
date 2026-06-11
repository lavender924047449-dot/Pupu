import 'dart:ui';

import 'package:flutter/material.dart';

/// Timer 页「Stop timing?」同款蓝色液体玻璃面板。
///
/// 支持可选宽高（不传时由父布局约束），并允许自定义圆角，
/// 以便在 Dialog（四角 24）和 BottomSheet（仅顶部 20）间复用。
class TimerBlueGlassPanel extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  final Widget child;

  const TimerBlueGlassPanel({
    super.key,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    required this.child,
  });

  static const Color _timerBlue = Color(0xFF0088FF);
  static const double _blurSigma = 12;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: _blurSigma, sigmaY: _blurSigma),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.22),
              width: 1,
            ),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _timerBlue.withValues(alpha: 0.34),
                _timerBlue.withValues(alpha: 0.48),
              ],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 40,
                offset: Offset(0, 8),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: borderRadius,
                    gradient: LinearGradient(
                      begin: const Alignment(0.5, 0),
                      end: const Alignment(0.5, 1),
                      colors: [
                        Colors.white.withValues(alpha: 0.16),
                        Colors.white.withValues(alpha: 0.04),
                      ],
                    ),
                  ),
                ),
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
