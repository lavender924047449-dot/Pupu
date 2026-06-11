import 'package:flutter/material.dart';

/// Home 页音乐星星开关。
///
/// - 始终闪烁（idle 1s / playing 2s）
/// - 仅播放时强化（更大更亮）
class MusicStarToggle extends StatefulWidget {
  const MusicStarToggle({
    super.key,
    required this.centerX,
    required this.centerY,
    required this.hitRadius,
    required this.isPlaying,
    required this.onTap,
  });

  final double centerX;
  final double centerY;
  final double hitRadius;
  final bool isPlaying;
  final VoidCallback onTap;

  @override
  State<MusicStarToggle> createState() => _MusicStarToggleState();
}

class _MusicStarToggleState extends State<MusicStarToggle>
    with SingleTickerProviderStateMixin {
  static const Duration _idleDuration = Duration(seconds: 1);
  static const Duration _playingDuration = Duration(seconds: 2);

  late final AnimationController _blinkController;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: widget.isPlaying ? _playingDuration : _idleDuration,
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant MusicStarToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPlaying == widget.isPlaying) return;
    _blinkController.duration =
        widget.isPlaying ? _playingDuration : _idleDuration;
    _blinkController
      ..reset()
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final diameter = (widget.hitRadius * 2).clamp(44.0, 80.0);

    return Positioned(
      left: widget.centerX - diameter / 2,
      top: widget.centerY - diameter / 2,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: SizedBox(
          width: diameter,
          height: diameter,
          child: AnimatedBuilder(
            animation: _blinkController,
            builder: (context, _) {
              final t = _blinkController.value;
              final idleOpacity = 0.42 + (0.43 * t);
              final glowBoost = widget.isPlaying ? 1.0 : 0.0;
              final starScale = widget.isPlaying ? 1.35 : 1.0;
              final coreSize = diameter * 0.22 * starScale;

              return Center(
                child: Opacity(
                  opacity: idleOpacity,
                  child: Container(
                    width: coreSize,
                    height: coreSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(
                        alpha: widget.isPlaying ? 0.98 : 0.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(
                            alpha: 0.35 + (0.25 * t) + (0.2 * glowBoost),
                          ),
                          blurRadius: 8 + (10 * t) + (8 * glowBoost),
                          spreadRadius: 1 + (1.8 * t) + (2.2 * glowBoost),
                        ),
                        BoxShadow(
                          color: Colors.white.withValues(
                            alpha: 0.12 + (0.1 * t) + (0.2 * glowBoost),
                          ),
                          blurRadius: 14 + (12 * t) + (10 * glowBoost),
                          spreadRadius: 4 + (2.5 * t) + (4.5 * glowBoost),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
