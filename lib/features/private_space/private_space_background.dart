import 'dart:math';

import 'package:flutter/material.dart';

class PrivateSpaceBackground extends StatelessWidget {
  const PrivateSpaceBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/child.png',
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ),
        IgnorePointer(
          child: CustomPaint(
            painter: _StarFieldPainter(),
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }
}

class PrivateSpaceParticleOverlay extends StatefulWidget {
  const PrivateSpaceParticleOverlay({super.key});

  @override
  State<PrivateSpaceParticleOverlay> createState() =>
      _PrivateSpaceParticleOverlayState();
}

class _PrivateSpaceParticleOverlayState extends State<PrivateSpaceParticleOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  )..forward();

  final Random _random = Random();
  late final List<_Particle> _particles = List.generate(
    64,
    (_) => _Particle(
      beginX: _random.nextBool()
          ? -0.2 - _random.nextDouble() * 0.3
          : 1.2 + _random.nextDouble() * 0.3,
      beginY: -0.1 + _random.nextDouble() * 1.2,
      endX: 0.2 + _random.nextDouble() * 0.6,
      endY: 0.24 + _random.nextDouble() * 0.5,
      size: 1.0 + _random.nextDouble() * 2.1,
      delay: _random.nextDouble() * 0.35,
    ),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) {
          return CustomPaint(
            painter: _ParticlePainter(
              particles: _particles,
              t: _controller.value,
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

class _Particle {
  const _Particle({
    required this.beginX,
    required this.beginY,
    required this.endX,
    required this.endY,
    required this.size,
    required this.delay,
  });

  final double beginX;
  final double beginY;
  final double endX;
  final double endY;
  final double size;
  final double delay;
}

class _ParticlePainter extends CustomPainter {
  const _ParticlePainter({required this.particles, required this.t});

  final List<_Particle> particles;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final progress = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      final eased = Curves.easeOutCubic.transform(progress);
      if (eased <= 0) continue;

      final dx = (p.beginX + (p.endX - p.beginX) * eased) * size.width;
      final dy = (p.beginY + (p.endY - p.beginY) * eased) * size.height;
      final alpha = eased < 0.82 ? eased * 0.9 : (1 - eased) * 3.2;

      final paint = Paint()
        ..color = const Color(0xFFFDE68A).withValues(alpha: alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4);

      canvas.drawCircle(Offset(dx, dy), p.size, paint);

      final corePaint = Paint()
        ..color = Colors.white.withValues(alpha: alpha * 0.88);
      canvas.drawCircle(Offset(dx, dy), p.size * 0.32, corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) {
    return oldDelegate.t != t || oldDelegate.particles != particles;
  }
}

class _StarFieldPainter extends CustomPainter {
  _StarFieldPainter() {
    final random = Random(42);
    for (int i = 0; i < 140; i++) {
      _stars.add(Offset(random.nextDouble(), random.nextDouble()));
      _sizes.add(0.4 + random.nextDouble() * 1.4);
      _opacity.add(0.2 + random.nextDouble() * 0.7);
    }
  }

  final List<Offset> _stars = <Offset>[];
  final List<double> _sizes = <double>[];
  final List<double> _opacity = <double>[];

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < _stars.length; i++) {
      final point = Offset(_stars[i].dx * size.width, _stars[i].dy * size.height);
      final alpha = _opacity[i];
      final paint = Paint()
        ..color = Color.lerp(
          const Color(0xFFFDE68A),
          Colors.white,
          alpha,
        )!
            .withValues(alpha: alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
      canvas.drawCircle(point, _sizes[i], paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
