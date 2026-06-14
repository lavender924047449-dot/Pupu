// 主页面（星空）
// Figma 首屏：星空背景 + 发光云朵 + Flow with me
// 右下角发光区域进入档案页面
// HOME-001: 文案下方音乐星星开关

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pupu/core/animations.dart';
import 'package:pupu/core/constants.dart';
import 'package:pupu/features/home/home_music.dart';
import 'package:pupu/features/home/widgets/music_star_toggle.dart';
import 'package:pupu/features/timer/timer_screen.dart';
import 'package:pupu/features/archive/new_archive_screen.dart';
import 'package:pupu/features/private_space/private_space_screen.dart';
import 'package:pupu/providers/home_audio_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const double _cloudDesignSize = 296;
  static const double _cloudTopRatio = 35 / kHomeDesignHeight;
  static const double _textTopRatio = 474 / kHomeDesignHeight;

  late AnimationController _breathController;
  late AnimationController _blinkController;
  late Animation<double> _breathScale;
  Timer? _rolloverTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _breathController = AnimationController(
      vsync: this,
      duration: Duration(
          milliseconds: (durationBreathSec * 1000).round()),
    )..repeat(reverse: true);

    _breathScale = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOut),
    );

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _rolloverTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      ref.read(homeAudioServiceProvider).evaluateDayRollover();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _rolloverTimer?.cancel();
    _rolloverTimer = null;
    _breathController.dispose();
    _blinkController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      ref.read(homeAudioServiceProvider).pauseForLeave();
      return;
    }
    if (state == AppLifecycleState.resumed) {
      ref.read(homeAudioServiceProvider).evaluateDayRollover();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMusicPlaying =
        ref.watch(homeMusicPlayingProvider).value ?? false;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final screenHeight = constraints.maxHeight;
          final widthScale = screenWidth / kHomeDesignWidth;
          final clampedWidthScale = widthScale.clamp(0.82, 1.35);

          final cloudSize = _cloudDesignSize * clampedWidthScale;
          final cloudTop = screenHeight * _cloudTopRatio;
          final textTop = screenHeight * _textTopRatio;
          final musicStarCenterX =
              (kMusicStarCenterXDesign / kHomeDesignWidth) * screenWidth;
          final musicStarCenterY =
              (kMusicStarCenterYDesign / kHomeDesignHeight) * screenHeight;
          final musicStarHitRadius =
              (kMusicStarHitRadiusDesign / kHomeDesignWidth) * screenWidth;

          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/images/home_intro_bg.png',
                fit: BoxFit.cover,
              ),
              Positioned(
                left: 0,
                right: 0,
                top: cloudTop,
                child: GestureDetector(
                  onLongPress: () => _openPrivateSpace(context),
                  child: AnimatedBuilder(
                    animation: _breathScale,
                    builder: (_, child) => Transform.scale(
                      scale: _breathScale.value,
                      child: child,
                    ),
                    child: Center(
                      child: SizedBox(
                        width: cloudSize,
                        height: cloudSize,
                        child: Container(
                          decoration: const BoxDecoration(
                            image: DecorationImage(
                              image: AssetImage('assets/images/cloud_ipp_2.png'),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: textTop,
                child: GestureDetector(
                  onTap: () => _openTimer(context),
                  child: AnimatedBuilder(
                    animation: _blinkController,
                    builder: (_, _) => Opacity(
                      opacity: 1 - (0.5 * _blinkController.value),
                      child: const Text(
                        'Flow with me',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 42,
                          fontWeight: FontWeight.w100,
                          fontFamily: 'Raleway',
                          fontStyle: FontStyle.italic,
                          height: 1,
                          letterSpacing: -0.35,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              MusicStarToggle(
                centerX: musicStarCenterX,
                centerY: musicStarCenterY,
                hitRadius: musicStarHitRadius,
                isPlaying: isMusicPlaying,
                onTap: () => ref.read(homeAudioServiceProvider).onStarTap(ref),
              ),
              // 右下角微弱光亮 - 进入档案页面
              Positioned(
                right: 0,
                bottom: 0,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final screenWidth = MediaQuery.of(context).size.width;
                    final glowSize = screenWidth / 20; // 屏幕宽的1/20
                    return GestureDetector(
                      onTap: () => _openNewArchive(context),
                      behavior: HitTestBehavior.opaque,
                      child: SizedBox(
                        width: glowSize * 3, // 点击热区
                        height: glowSize * 3,
                        child: Align(
                          alignment: Alignment.bottomRight,
                          child: Container(
                            width: glowSize,
                            height: glowSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  blurRadius: 16,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openTimer(BuildContext context) {
    ref.read(homeAudioServiceProvider).pauseForLeave();
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const TimerScreen(),
        transitionDuration: pageTransitionDuration,
        reverseTransitionDuration: pageTransitionDuration,
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: standardCurve,
            ),
            child: child,
          );
        },
      ),
    );
  }

  /// 打开新档案页面
  void _openNewArchive(BuildContext context) {
    ref.read(homeAudioServiceProvider).pauseForLeave();
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const NewArchiveScreen(),
        transitionDuration: pageTransitionDuration,
        reverseTransitionDuration: pageTransitionDuration,
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: standardCurve,
            ),
            child: child,
          );
        },
      ),
    );
  }


  void _openPrivateSpace(BuildContext context) {
    ref.read(homeAudioServiceProvider).pauseForLeave();
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const PrivateSpaceScreen(),
        transitionDuration: pageTransitionDuration,
        reverseTransitionDuration: pageTransitionDuration,
        transitionsBuilder: (_, animation, _, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: standardCurve,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.88, end: 1).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }
}
