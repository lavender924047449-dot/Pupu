import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// 计时页问卷与音频面板共用的三层液体玻璃背景。
class LiquidGlassBackground extends StatelessWidget {
  const LiquidGlassBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: const Alignment(0.50, -0.00),
                end: const Alignment(0.50, 1.00),
                colors: [
                  Colors.black.withValues(alpha: 0.06),
                  Colors.black.withValues(alpha: 0.00),
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(color: Colors.white.withValues(alpha: 0.012)),
            ),
          ),
        ),
        Positioned.fill(
          child: Opacity(
            opacity: 0.008,
            child: Container(decoration: const BoxDecoration(color: Colors.black)),
          ),
        ),
      ],
    );
  }
}
