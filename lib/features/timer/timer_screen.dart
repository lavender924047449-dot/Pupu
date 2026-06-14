/// 计时页面
/// Figma 设计集成 - iPhone 14 & 15 Pro - 1
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pupu/core/every_moment_texts.dart';
import 'package:pupu/core/warm_sentences_timer.dart';
import 'package:pupu/features/questionnaire/questionnaire_flow.dart';
import 'package:pupu/features/questionnaire/questionnaire_codec.dart';
import 'package:pupu/features/timer/session_record_utils.dart';
import 'package:pupu/features/timer/widgets/audio_picker.dart';
import 'package:pupu/features/timer/widgets/timer_dialogs.dart';
import 'package:pupu/features/timer/widgets/timer_session_summary.dart';
import 'package:pupu/features/timer/widgets/timer_wave_painter.dart';
import 'package:pupu/features/timer/widgets/warm_sentence_overlay.dart';
import 'package:pupu/providers/audio_provider.dart';
import 'package:pupu/providers/home_audio_provider.dart';
import 'package:pupu/providers/records_provider.dart';

class TimerScreen extends ConsumerStatefulWidget {
  const TimerScreen({super.key});

  @override
  ConsumerState<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends ConsumerState<TimerScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _cloudGlowController;
  late final AnimationController _displaySwitchController;
  late final AnimationController _waveAnimationController;
  late final AnimationController _warmSentenceController;
  late final Animation<double> _warmSentenceOpacity;
  Timer? _timer;
  Timer? _warmIntervalTimer;

  Duration _elapsed = Duration.zero;
  Duration _lastSessionDuration = Duration.zero;
  _TimerUiState _uiState = _TimerUiState.idle;
  _DisplayMode _displayMode = _DisplayMode.number;
  bool _waveIsAnimating = false;
  bool _showSessionPanel = false;
  bool _showLogWithMeQuestionnaire = false;
  final QuestionnaireFlow _questionnaireFlow = QuestionnaireFlow();
  double _wavePhaseOffset = 0.0; // 累积相位，确保连续波动
  late final AnimationController _finishLoggingController;
  late final AnimationController _audioRotationController;
  late final AnimationController _audioPanelController;
  final math.Random _random = math.Random();
  String _currentEveryMomentText = '';
  bool _showAudioPanel = false;
  int? _selectedAudioIndex;
  DateTime? _runningStartedAt;
  Duration _elapsedBeforeCurrentRun = Duration.zero;
  DateTime? _sessionStartedAt;
  String? _committedRecordId;
  SessionSummaryStats? _summaryStats;
  bool _handlingBackNavigation = false;
  bool _isExiting = false;
  bool _warmIsDisplaying = false;
  int _warmIntervalRemainingMs = 0;
  DateTime? _warmIntervalStartedAt;
  String _currentWarmSentence = '';
  final Set<int> _usedWarmIndices = <int>{};

  int _currentBackgroundIndex = 0;
  final List<String> _backgroundImages = const [
    'assets/images/background_1 (1).png',
    'assets/images/background_1 (2).png',
  ];

  List<Shadow> get _textShadows => [
        Shadow(
          offset: const Offset(0, 1),
          blurRadius: 0,
          color: const Color(0xFF000000).withValues(alpha: 0.25),
        ),
      ];

  TextStyle _sfProStyle({
    required Color color,
    required double fontSize,
    required FontWeight fontWeight,
    double? letterSpacing,
    TextDecoration? decoration,
  }) {
    final effectiveLetterSpacing =
        (letterSpacing == null || letterSpacing < 0) ? 0.0 : letterSpacing;
    return TextStyle(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontFamily: 'SF Pro',
      letterSpacing: effectiveLetterSpacing,
      decoration: decoration,
      shadows: _textShadows,
    );
  }

  TextStyle _sfProNoShadowStyle({
    required Color color,
    required double fontSize,
    required FontWeight fontWeight,
    double? letterSpacing,
    TextDecoration? decoration,
  }) {
    final effectiveLetterSpacing =
        (letterSpacing == null || letterSpacing < 0) ? 0.0 : letterSpacing;
    return TextStyle(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontFamily: 'SF Pro',
      letterSpacing: effectiveLetterSpacing,
      decoration: decoration,
    );
  }

  TextStyle _josefinStyle({
    required Color color,
    required double fontSize,
    required FontWeight fontWeight,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
  }) {
    return TextStyle(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontFamily: 'Josefin Sans',
      letterSpacing: letterSpacing,
      height: height,
      decoration: decoration,
      shadows: _textShadows,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cloudGlowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _displaySwitchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _waveAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8000),
    );

    _finishLoggingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _audioRotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );

    _audioPanelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _warmSentenceController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 21),
    );
    _warmSentenceOpacity = TweenSequence<double>([
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 3,
      ),
      TweenSequenceItem<double>(
        tween: ConstantTween<double>(1.0),
        weight: 15,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 3,
      ),
    ]).animate(_warmSentenceController);
    _warmSentenceController.addStatusListener(_onWarmAnimationStatus);

    _currentEveryMomentText = _pickRandomEveryMomentText();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ref.read(timerAudioServiceProvider).stop();
    _timer?.cancel();
    _warmIntervalTimer?.cancel();
    _cloudGlowController.dispose();
    _displaySwitchController.dispose();
    _waveAnimationController.dispose();
    _warmSentenceController.removeStatusListener(_onWarmAnimationStatus);
    _warmSentenceController.dispose();
    _questionnaireFlow.dispose();
    _finishLoggingController.dispose();
    _audioRotationController.dispose();
    _audioPanelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop || _handlingBackNavigation) return;
        // 系统返回上一页时立即停掉 Timer 音频，避免等待 dispose 造成残留。
        unawaited(ref.read(timerAudioServiceProvider).stop());
        if (!_showSessionPanel) return;
        _handlingBackNavigation = true;
        await _resumeHomeMusicIfEnabled();
      },
      child: Scaffold(
        body: Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                onTap: _switchBackgroundImage,
                child: AnimatedSwitcher(
                  duration: const Duration(seconds: 10),
                  switchInCurve: Curves.easeInOut,
                  switchOutCurve: Curves.easeInOut,
                  layoutBuilder: (currentChild, previousChildren) {
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        ...previousChildren,
                        ?currentChild,
                      ],
                    );
                  },
                  transitionBuilder: (child, animation) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  child: Image.asset(
                    _backgroundImages[_currentBackgroundIndex],
                    key: ValueKey<int>(_currentBackgroundIndex),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                top: screenSize.height * 0.066,
                left: screenSize.width * 0.219,
                child: AnimatedBuilder(
                  animation: _cloudGlowController,
                  builder: (context, child) {
                    final t = _cloudGlowController.value;
                    final scale = 0.96 + (t * 0.08);
                    final cloudSize = screenSize.width * 0.56;

                    // 让云朵图片本体做缩放，阴影参数维持Figma风格。
                    return SizedBox(
                      width: cloudSize,
                      height: cloudSize,
                      child: Opacity(
                        opacity: 0.5,
                        child: Center(
                          child: Transform.scale(
                            scale: scale,
                            alignment: Alignment.center,
                            child: SizedBox(
                              width: cloudSize,
                              height: cloudSize,
                              child: Image.asset(
                                'assets/images/light_cloud.png',
                                width: cloudSize,
                                height: cloudSize,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (!_showSessionPanel) ...[
                SafeArea(child: _buildTimerLayout(screenSize)),
                Positioned(
                  top: screenSize.height * 0.066 + screenSize.width * 0.56,
                  bottom: 286,
                  left: 0,
                  right: 0,
                  child: Align(
                    alignment: const Alignment(0, -0.50),
                    child: WarmSentenceOverlay(
                      animation: _warmSentenceOpacity,
                      text: _currentWarmSentence,
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 88,
                  child: Center(child: _buildActionRow()),
                ),
                // 音频层置于操作区之上，确保 scrim 锁住 Start/Pause/Stop/🎵。
                AudioPickerLayer(
                  isOpen: _showAudioPanel,
                  panelAnimation: _audioPanelController,
                  selectedIndex: _selectedAudioIndex,
                  onClose: _closeAudioPanel,
                  onSelect: _onAudioItemTap,
                  screenSize: screenSize,
                ),
              ],
              if (_showSessionPanel) _buildSessionPanel(screenSize),
            ],
          ),
        ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 需求：切后台不停止音乐；计时通过 wall clock 在恢复时补齐。
    if (state == AppLifecycleState.resumed &&
        _uiState == _TimerUiState.running &&
        _runningStartedAt != null) {
      setState(_syncElapsedWithWallClock);
    }
  }

  void _switchBackgroundImage() {
    setState(() {
      _currentBackgroundIndex =
          (_currentBackgroundIndex + 1) % _backgroundImages.length;
    });
  }

  Widget _buildTimerLayout(Size screenSize) {
    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          bottom: 180,
          child: Center(
            child: GestureDetector(
              onTap: _toggleDisplayMode,
              child: _buildDisplayContent(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDisplayContent() {
    return AnimatedSwitcher(
      duration: Duration(milliseconds: _displaySwitchController.duration!.inMilliseconds),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: _displayMode == _DisplayMode.number
          ? _buildTimeText()
          : _buildWaveDisplay(),
    );
  }

  Widget _buildTimeText() {
    final minutes = _elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = _elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');

    return SizedBox(
      key: const ValueKey('time-display'),
      width: 268,
      height: 106,
      child: Text(
        '$minutes：$seconds',
        textAlign: TextAlign.center,
        style: _sfProStyle(
          color: Colors.white,
          fontSize: 45,
          fontWeight: FontWeight.w300,
        ),
      ),
    );
  }

  Widget _buildWaveDisplay() {
    return SizedBox(
      key: const ValueKey('wave-display'),
      width: MediaQuery.of(context).size.width,
      height: 106,
      child: Center(
        child: GestureDetector(
          onTap: () {
            // 整个波形区域都是热区
            _toggleDisplayMode();
          },
          child: AnimatedBuilder(
            animation: _waveAnimationController,
            builder: (context, child) {
              // 累积相位：动画值每循环一次，累加 2π
              // 使得波形连续流动而不是断跳
              final currentPhase = (_waveAnimationController.value * 2 * math.pi) + _wavePhaseOffset;
              
              return CustomPaint(
                painter: TimerWavePainter(
                  animationValue: _waveAnimationController.value,
                  currentPhase: currentPhase,
                  isAnimating: _waveIsAnimating,
                ),
                size: Size(MediaQuery.of(context).size.width, 106),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildActionRow() {
    const musicButtonGap = 16.0;
    final musicButton = TimerMusicButton(
      rotationAnimation: _audioRotationController,
      onTap: _openAudioPanel,
    );

    switch (_uiState) {
      case _TimerUiState.idle:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _actionButton(label: 'Start', onTap: _startTimer),
            const SizedBox(width: musicButtonGap),
            musicButton,
          ],
        );
      case _TimerUiState.running:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _actionButton(label: 'Pause', onTap: _pauseTimer),
            const SizedBox(width: 22),
            _actionButton(label: 'Stop', onTap: _stopTimer),
            const SizedBox(width: musicButtonGap),
            musicButton,
          ],
        );
      case _TimerUiState.paused:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _actionButton(label: 'Resume', onTap: _resumeTimer),
            const SizedBox(width: musicButtonGap),
            musicButton,
          ],
        );
    }
  }

  Widget _buildSessionPanel(Size screenSize) {
    return TimerSessionSummaryPanel(
      screenSize: screenSize,
      currentEveryMomentText: _currentEveryMomentText,
      lastSessionDuration: _lastSessionDuration,
      summaryStats: _summaryStats,
      committedRecordId: _committedRecordId,
      isExiting: _isExiting,
      showLogWithMeQuestionnaire: _showLogWithMeQuestionnaire,
      questionnaireFlow: _questionnaireFlow,
      finishLoggingController: _finishLoggingController,
      onOpenQuestionnaire: () {
        setState(() {
          _resetQuestionnaireFlow();
          _showLogWithMeQuestionnaire = true;
        });
      },
      onMaybeLater: _showMaybeLaterDialog,
      onFinishQuestionnaire: _onFinishLoggingTapped,
      sfProNoShadowStyle: _sfProNoShadowStyle,
      josefinStyle: _josefinStyle,
    );
  }

  Future<void> _onFinishLoggingTapped() async {
    if (_isExiting) return;
    if (_committedRecordId == null) return;

    await showTimerGlassDialog(
      context,
      child: TimerFinishSessionDialog(
        onNo: () {},
        onYes: _finishQuestionnaire,
      ),
    );
  }

  Future<void> _finishQuestionnaire() async {
    if (_isExiting) return;
    final recordId = _committedRecordId;
    if (recordId == null) return;
    final answers = encodeAnswers(
      _questionnaireFlow.selectedAnswers,
      _questionnaireFlow.visibleQuestions,
    );
    setState(() {
      _showLogWithMeQuestionnaire = false;
    });
    try {
      await mergeQuestionnaireAnswers(
        recordId: recordId,
        answers: answers,
      );
      if (!mounted) return;
      bumpRecordsRefresh(ref);
      _resetQuestionnaireFlow();
      await _exitToHome();
    } on StateError {
      if (!mounted) return;
      // 记录不存在时维持在 Timer 页面，不执行离场。
      setState(() {
        _showLogWithMeQuestionnaire = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _showLogWithMeQuestionnaire = true;
      });
    }
  }

  void _openAudioPanel() {
    if (_showAudioPanel) return;
    setState(() {
      _showAudioPanel = true;
    });
    _audioPanelController.forward(from: 0.0);
  }

  void _closeAudioPanel() {
    if (!_showAudioPanel) return;
    _audioPanelController.reverse().whenComplete(() {
      if (!mounted) return;
      setState(() {
        _showAudioPanel = false;
      });
    });
  }

  void _onAudioItemTap(int index) {
    setState(() {
      if (_selectedAudioIndex == index) {
        _selectedAudioIndex = null;
      } else {
        _selectedAudioIndex = index;
      }
      _syncAudioRotation();
    });
    _syncTimerAudio();
  }

  /// 根据 [_selectedAudioIndex] 同步播放/停止；门控由父级保证（仅计时阶段可触发）。
  void _syncTimerAudio() {
    final index = _selectedAudioIndex;
    final audio = ref.read(timerAudioServiceProvider);
    if (index == null || index == 0) {
      audio.stop();
    } else {
      audio.playTrack(index);
    }
  }

  void _syncAudioRotation() {
    final shouldRotate = _selectedAudioIndex != null && _selectedAudioIndex != 0;
    if (shouldRotate) {
      if (!_audioRotationController.isAnimating) {
        _audioRotationController.repeat();
      }
      return;
    }
    _audioRotationController.stop();
    _audioRotationController.value = 0.0;
  }

  void _resetAudioOnSessionEnter() {
    _showAudioPanel = false;
    _audioPanelController.reset();
    _selectedAudioIndex = null;
    _syncAudioRotation();
    ref.read(timerAudioServiceProvider).stop();
  }

  void _resetQuestionnaireFlow() {
    _questionnaireFlow.reset();
  }

  Widget _actionButton({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 119,
        height: 54,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              child: Container(
                width: 119,
                height: 54,
                decoration: ShapeDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  shadows: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 40,
                      offset: Offset(0, 8),
                      spreadRadius: 0,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              right: 0,
              bottom: 0,
              child: Align(
                alignment: Alignment.center,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: _josefinStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startTimer() {
    _timer?.cancel();
    _stopWarm();
    setState(() {
      _showSessionPanel = false;
      _showLogWithMeQuestionnaire = false;
      _resetQuestionnaireFlow();
      _sessionStartedAt = DateTime.now();
      _committedRecordId = null;
      _summaryStats = null;
      _elapsed = Duration.zero;
      _elapsedBeforeCurrentRun = Duration.zero;
      _runningStartedAt = DateTime.now();
      _uiState = _TimerUiState.running;
      _waveIsAnimating = true;
      // 重置相位偏移
      _wavePhaseOffset = 0.0;
    });

    _waveAnimationController.repeat();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _uiState != _TimerUiState.running) return;
      setState(() {
        _syncElapsedWithWallClock();
      });
    });
    _scheduleWarmSentence(const Duration(seconds: 25));
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() {
      _syncElapsedWithWallClock();
      _elapsedBeforeCurrentRun = _elapsed;
      _runningStartedAt = null;
      _uiState = _TimerUiState.paused;
      _waveIsAnimating = false;
      // 保存当前相位，暂停时记录波形位置
      _wavePhaseOffset += _waveAnimationController.value * 2 * math.pi;
    });
    _waveAnimationController.stop();
    _pauseWarm();
  }

  void _resumeTimer() {
    _timer?.cancel();
    setState(() {
      _runningStartedAt = DateTime.now();
      _uiState = _TimerUiState.running;
      _waveIsAnimating = true;
    });
    // 从 0 开始循环，相位偏移维持之前保存的值
    _waveAnimationController.repeat();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _uiState != _TimerUiState.running) return;
      setState(() {
        _syncElapsedWithWallClock();
      });
    });
    _resumeWarm();
  }

  void _stopTimer() {
    // 先暂停计时，然后显示确认对话框
    _pauseTimer();
    _showStopConfirmDialog();
  }

  void _doStopTimer() {
    // 真正执行停止逻辑
    _syncElapsedWithWallClock();
    final sessionStartedAt = _sessionStartedAt ?? DateTime.now();
    final elapsedAtStop = _elapsed;
    _timer?.cancel();
    setState(() {
      _lastSessionDuration = elapsedAtStop;
      _currentEveryMomentText = _pickRandomEveryMomentText();
      _currentWarmSentence = '';
      _elapsed = Duration.zero;
      _elapsedBeforeCurrentRun = Duration.zero;
      _runningStartedAt = null;
      _uiState = _TimerUiState.idle;
      _waveIsAnimating = false;
      _resetAudioOnSessionEnter();
      _showSessionPanel = true;
      _showLogWithMeQuestionnaire = false;
      _resetQuestionnaireFlow();
      // 重置相位偏移
      _wavePhaseOffset = 0.0;
    });
    _waveAnimationController.stop();
    _stopWarm();
    unawaited(_commitSessionAndComputeSummary(
      startedAt: sessionStartedAt,
      elapsed: elapsedAtStop,
    ));
  }

  void _syncElapsedWithWallClock() {
    if (_runningStartedAt == null) return;
    final runningDuration = DateTime.now().difference(_runningStartedAt!);
    _elapsed = _elapsedBeforeCurrentRun + runningDuration;
  }

  Future<void> _commitSessionAndComputeSummary({
    required DateTime startedAt,
    required Duration elapsed,
  }) async {
    // Session 进入时只允许写入一条记录，避免重复 stop 触发脏数据。
    if (_committedRecordId != null) return;

    final record = await commitTimerSession(
      startedAt: startedAt,
      elapsed: elapsed,
    );
    if (!mounted) return;

    // 周起点遵循系统 locale。先读取 context，避免 async gap 后再访问。
    final firstDayOfWeekIndex = MaterialLocalizations.of(context).firstDayOfWeekIndex;
    final allRecords = await ref.read(recordsWithRefreshProvider.future);
    final summaryStats = computeSummaryStats(
      all: allRecords,
      currentRecordId: record.id,
      firstDayOfWeekIndex: firstDayOfWeekIndex,
      now: DateTime.now(),
    );

    if (!mounted) return;
    setState(() {
      _committedRecordId = record.id;
      _summaryStats = summaryStats;
    });
    bumpRecordsRefresh(ref);
  }

  Future<void> _resumeHomeMusicIfEnabled() async {
    final isEnabled = ref.read(homeMusicEnabledProvider);
    if (!isEnabled) return;
    await ref.read(homeAudioServiceProvider).resume();
  }

  Future<void> _exitToHome() async {
    // 统一 Home 退出：恢复 BGM 后 pop，视觉由 Route reverse 过渡负责。
    if (_handlingBackNavigation || _isExiting) return;
    _handlingBackNavigation = true;
    _isExiting = true;
    await ref.read(timerAudioServiceProvider).stop();
    await _resumeHomeMusicIfEnabled();
    if (mounted) Navigator.of(context).pop();
  }

  String _pickRandomEveryMomentText() {
    if (kEveryMomentTextLibrary.isEmpty) return '';
    if (kEveryMomentTextLibrary.length == 1) return kEveryMomentTextLibrary.first;

    var picked = kEveryMomentTextLibrary[_random.nextInt(kEveryMomentTextLibrary.length)];
    while (picked == _currentEveryMomentText) {
      picked = kEveryMomentTextLibrary[_random.nextInt(kEveryMomentTextLibrary.length)];
    }
    return picked;
  }

  void _onWarmAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    if (!mounted || _uiState != _TimerUiState.running || _showSessionPanel) return;
    _warmIsDisplaying = false;
    _scheduleNextWarmInterval();
  }

  void _scheduleNextWarmInterval() {
    final elapsedSeconds = _elapsed.inSeconds;
    final intervalMs =
        elapsedSeconds < 180 ? 50000 : elapsedSeconds < 600 ? 120000 : 240000;
    _scheduleWarmSentence(Duration(milliseconds: intervalMs));
  }

  void _scheduleWarmSentence(Duration delay) {
    _warmIntervalTimer?.cancel();
    _warmIsDisplaying = false;
    _warmIntervalRemainingMs = delay.inMilliseconds;
    _warmIntervalStartedAt = DateTime.now();
    _warmIntervalTimer = Timer(delay, _triggerWarmSentence);
  }

  void _triggerWarmSentence() {
    if (!mounted || _uiState != _TimerUiState.running || _showSessionPanel) return;
    _warmIntervalTimer = null;
    _warmIntervalStartedAt = null;
    _warmIntervalRemainingMs = 0;
    setState(() {
      _currentWarmSentence = _pickWarmSentence();
      _warmIsDisplaying = true;
    });
    _warmSentenceController.forward(from: 0.0);
  }

  String _pickWarmSentence() {
    if (kWarmSentencesTimer.isEmpty) return '';
    if (_usedWarmIndices.length >= kWarmSentencesTimer.length) {
      _usedWarmIndices.clear();
    }

    int index = _random.nextInt(kWarmSentencesTimer.length);
    while (_usedWarmIndices.contains(index)) {
      index = _random.nextInt(kWarmSentencesTimer.length);
    }
    _usedWarmIndices.add(index);
    return kWarmSentencesTimer[index];
  }

  void _pauseWarm() {
    if (_warmIsDisplaying) {
      _warmSentenceController.stop();
      return;
    }
    _warmIntervalTimer?.cancel();
    _warmIntervalTimer = null;
    final startedAt = _warmIntervalStartedAt;
    if (startedAt == null) return;
    final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
    final remainingMs = (_warmIntervalRemainingMs - elapsedMs)
        .clamp(0, _warmIntervalRemainingMs)
        .toInt();
    _warmIntervalRemainingMs = remainingMs;
    _warmIntervalStartedAt = null;
  }

  void _resumeWarm() {
    if (_warmIsDisplaying) {
      _warmSentenceController.forward();
      return;
    }
    if (_warmIntervalRemainingMs <= 0) return;
    _warmIntervalStartedAt = DateTime.now();
    _warmIntervalTimer = Timer(
      Duration(milliseconds: _warmIntervalRemainingMs),
      _triggerWarmSentence,
    );
  }

  void _stopWarm() {
    _warmIntervalTimer?.cancel();
    _warmIntervalTimer = null;
    _warmSentenceController.stop();
    _warmSentenceController.reset();
    _warmIsDisplaying = false;
    _warmIntervalRemainingMs = 0;
    _warmIntervalStartedAt = null;
    _usedWarmIndices.clear();
    _currentWarmSentence = '';
  }

  void _showStopConfirmDialog() {
    showTimerGlassDialog(
      context,
      child: TimerStopConfirmDialog(
        onYes: _doStopTimer,
        onNo: _resumeTimer,
      ),
    );
  }

  void _showMaybeLaterDialog() {
    if (_isExiting) return;
    showTimerGlassDialog(
      context,
      child: TimerMaybeLaterDialog(
        onGotIt: () async {
          Navigator.of(context).pop();
          await _exitToHome();
        },
      ),
    );
  }
  void _toggleDisplayMode() {
    if (_displayMode == _DisplayMode.number) {
      setState(() {
        _displayMode = _DisplayMode.wave;
      });
      _displaySwitchController.forward(from: 0.0);
    } else {
      setState(() {
        _displayMode = _DisplayMode.number;
      });
      _displaySwitchController.forward(from: 0.0);
    }
  }
}

enum _TimerUiState {
  idle,
  running,
  paused,
}

enum _DisplayMode {
  number,
  wave,
}

