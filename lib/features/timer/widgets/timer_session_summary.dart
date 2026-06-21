import 'package:flutter/material.dart';
import 'package:pupu/core/widgets/liquid_glass_background.dart';
import 'package:pupu/features/questionnaire/questionnaire_flow.dart';
import 'package:pupu/features/timer/session_record_utils.dart';
import 'package:pupu/features/timer/widgets/timer_questionnaire_host.dart';

class TimerSessionSummaryPanel extends StatelessWidget {
  const TimerSessionSummaryPanel({
    super.key,
    required this.screenSize,
    required this.currentEveryMomentText,
    required this.lastSessionDuration,
    required this.summaryStats,
    required this.committedRecordId,
    required this.isExiting,
    required this.showLogWithMeQuestionnaire,
    required this.questionnaireFlow,
    required this.finishLoggingController,
    required this.onOpenQuestionnaire,
    required this.onMaybeLater,
    required this.onFinishQuestionnaire,
    required this.sfProNoShadowStyle,
    required this.josefinStyle,
  });

  final Size screenSize;
  final String currentEveryMomentText;
  final Duration lastSessionDuration;
  final SessionSummaryStats? summaryStats;
  final String? committedRecordId;
  final bool isExiting;
  final bool showLogWithMeQuestionnaire;
  final QuestionnaireFlow questionnaireFlow;
  final Animation<double> finishLoggingController;
  final VoidCallback onOpenQuestionnaire;
  final VoidCallback onMaybeLater;
  final Future<void> Function() onFinishQuestionnaire;
  final TextStyle Function({
    required Color color,
    required double fontSize,
    required FontWeight fontWeight,
    double? letterSpacing,
    TextDecoration? decoration,
  }) sfProNoShadowStyle;
  final TextStyle Function({
    required Color color,
    required double fontSize,
    required FontWeight fontWeight,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
  }) josefinStyle;

  @override
  Widget build(BuildContext context) {
    final panelTop = screenSize.height * (216 / 852);
    final panelHeight = screenSize.height * (636 / 852);
    final xScale = screenSize.width / 393;

    double sx(double value) => value * xScale;

    final summaryContent = _SessionSummaryBody(
      horizontalPadding: sx(13),
      contentWidth: sx(372),
      everyMomentWidth: sx(333),
      sessionMinutes: lastSessionDuration.inMinutes,
      sessionSeconds: lastSessionDuration.inSeconds.remainder(60),
      todayLogCount: summaryStats?.todayCount ?? 0,
      hoursSinceLastLog: summaryStats?.hoursSinceLastLog ?? 0,
      weekLogCount: summaryStats?.weekCount ?? 0,
      currentEveryMomentText: currentEveryMomentText,
      canLogWithMe: committedRecordId != null && !isExiting,
      isExiting: isExiting,
      onOpenQuestionnaire: onOpenQuestionnaire,
      onMaybeLater: onMaybeLater,
      sfProNoShadowStyle: sfProNoShadowStyle,
      josefinStyle: josefinStyle,
      logButtonWidth: sx(166),
      logButtonHeight: panelHeight * (57 / 636),
      ctaGap: (screenSize.height * (28 / 852)).clamp(20.0, 40.0),
    );

    return Positioned(
      left: 0,
      top: panelTop,
      child: SizedBox(
        width: screenSize.width,
        height: panelHeight,
        child: Stack(
          children: [
            const Positioned.fill(
              child: LiquidGlassBackground(),
            ),
            Positioned.fill(
              child: TimerQuestionnaireHost(
                screenSize: screenSize,
                panelHeight: panelHeight,
                showQuestionnaire: showLogWithMeQuestionnaire,
                questionnaireFlow: questionnaireFlow,
                finishLoggingController: finishLoggingController,
                onFinishQuestionnaire: onFinishQuestionnaire,
                summaryContent: summaryContent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionSummaryBody extends StatefulWidget {
  const _SessionSummaryBody({
    required this.horizontalPadding,
    required this.contentWidth,
    required this.everyMomentWidth,
    required this.sessionMinutes,
    required this.sessionSeconds,
    required this.todayLogCount,
    required this.hoursSinceLastLog,
    required this.weekLogCount,
    required this.currentEveryMomentText,
    required this.canLogWithMe,
    required this.isExiting,
    required this.onOpenQuestionnaire,
    required this.onMaybeLater,
    required this.sfProNoShadowStyle,
    required this.josefinStyle,
    required this.logButtonWidth,
    required this.logButtonHeight,
    required this.ctaGap,
  });

  final double horizontalPadding;
  final double contentWidth;
  final double everyMomentWidth;
  final int sessionMinutes;
  final int sessionSeconds;
  final int todayLogCount;
  final int hoursSinceLastLog;
  final int weekLogCount;
  final String currentEveryMomentText;
  final bool canLogWithMe;
  final bool isExiting;
  final VoidCallback onOpenQuestionnaire;
  final VoidCallback onMaybeLater;
  final TextStyle Function({
    required Color color,
    required double fontSize,
    required FontWeight fontWeight,
    double? letterSpacing,
    TextDecoration? decoration,
  }) sfProNoShadowStyle;
  final TextStyle Function({
    required Color color,
    required double fontSize,
    required FontWeight fontWeight,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
  }) josefinStyle;
  final double logButtonWidth;
  final double logButtonHeight;
  final double ctaGap;

  @override
  State<_SessionSummaryBody> createState() => _SessionSummaryBodyState();
}

class _SessionSummaryBodyState extends State<_SessionSummaryBody> {
  static const _detailsCollapsedText =
      'You can add log details to better understand your body.';
  static const _detailsExpandedText =
      'Track how it went, how you felt, and anything unusual. '
      'Smooth or not, these details help you spot patterns over time.';

  bool _detailsExpanded = false;

  TextStyle _labelStyle() => widget.sfProNoShadowStyle(
        color: const Color(0xFFE5E5EA),
        fontSize: 17,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.07,
      );

  TextStyle _valueStyle() => widget.sfProNoShadowStyle(
        color: Colors.white,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.07,
      );

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(label, style: _labelStyle()),
          ),
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: _valueStyle(),
            ),
          ),
        ],
      ),
    );
  }

  /// Session Summary 统计区 + 可折叠说明文（不含 CTA）。
  Widget _buildSummarySection(TextStyle detailsStyle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Opacity(
          opacity: 0.97,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Session Summary:',
                style: widget.sfProNoShadowStyle(
                  color: const Color(0xFF0088FF),
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.07,
                ),
              ),
              const SizedBox(height: 8),
              _statRow(
                'Duration:',
                '${widget.sessionMinutes} min ${widget.sessionSeconds} sec',
              ),
              _statRow("Today's Log:", '${widget.todayLogCount}'),
              _statRow(
                'Time since last log:',
                '${widget.hoursSinceLastLog} hr',
              ),
              _statRow(
                'Total logs this week:',
                '${widget.weekLogCount}',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _detailsExpanded = !_detailsExpanded),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _detailsExpanded
                      ? _detailsExpandedText
                      : _detailsCollapsedText,
                  style: detailsStyle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                _detailsExpanded ? '▲' : '▼',
                style: detailsStyle.copyWith(
                  color: const Color(0xFF0088FF),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Log with me / Maybe Later CTA 区（保留 SafeArea 底部避让）。
  Widget _buildCtaSection() {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Opacity(
              opacity: widget.canLogWithMe ? 1.0 : 0.5,
              child: Semantics(
                button: true,
                enabled: widget.canLogWithMe,
                label: 'Log with me',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap:
                        widget.canLogWithMe ? widget.onOpenQuestionnaire : null,
                    borderRadius: BorderRadius.circular(1000),
                    child: Container(
                      width: widget.logButtonWidth,
                      height: widget.logButtonHeight,
                      decoration: ShapeDecoration(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(1000),
                        ),
                        shadows: const [
                          BoxShadow(
                            color: Color(0xFFFFFFFF),
                            blurRadius: 0.2,
                          ),
                          BoxShadow(
                            color: Color(0xFFFFFFFF),
                            blurRadius: 0.4,
                          ),
                          BoxShadow(
                            color: Color(0xFFFFFFFF),
                            blurRadius: 1.39,
                          ),
                          BoxShadow(
                            color: Color(0xFFFFFFFF),
                            blurRadius: 2.79,
                          ),
                          BoxShadow(
                            color: Color(0xFFFFFFFF),
                            blurRadius: 4.78,
                          ),
                          BoxShadow(
                            color: Color(0xFFFFFFFF),
                            blurRadius: 8.37,
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Container(
                              clipBehavior: Clip.antiAlias,
                              decoration: ShapeDecoration(
                                color: const Color(0xFFF7F7F7),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(296),
                                ),
                                shadows: const [
                                  BoxShadow(
                                    color: Color(0x1E000000),
                                    blurRadius: 40,
                                    offset: Offset(0, 8),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Center(
                            child: Text(
                              'Log with me',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF0088FF),
                                fontSize: 17,
                                fontFamily: 'Josefin Sans',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: widget.isExiting ? null : widget.onMaybeLater,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white.withValues(alpha: 0.85),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
              ),
              child: Text(
                'Maybe Later',
                style: widget.josefinStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// 引导语以下区域：在剩余视口高度内垂直居中；内容超出时可滚动。
  Widget _buildCenteredScrollableSummary(TextStyle detailsStyle) {
    return Expanded(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewportHeight = constraints.maxHeight;

          return SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: ConstrainedBox(
              // 至少占满引导语以下的可见高度，以便 Center 能计算垂直中心。
              constraints: BoxConstraints(minHeight: viewportHeight),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSummarySection(detailsStyle),
                    SizedBox(height: widget.ctaGap),
                    _buildCtaSection(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailsStyle = widget.josefinStyle(
      color: const Color(0xFFE5E5EA),
      fontSize: 18,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      height: 1.26,
    );

    return KeyedSubtree(
      key: const ValueKey('summary-content'),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: widget.horizontalPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 暖心引导语：固定顶部，不随下方滚动。
            const SizedBox(height: 32),
            SizedBox(
              width: widget.everyMomentWidth,
              child: Text(
                widget.currentEveryMomentText,
                style: widget.josefinStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0,
                  height: 1.24,
                ),
              ),
            ),
            // 引导语与居中块之间的最小间距（2.B）。
            const SizedBox(height: 20),
            _buildCenteredScrollableSummary(detailsStyle),
          ],
        ),
      ),
    );
  }
}
