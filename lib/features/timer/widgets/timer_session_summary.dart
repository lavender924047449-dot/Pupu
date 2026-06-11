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
    final sessionMinutes = lastSessionDuration.inMinutes;
    final sessionSeconds = lastSessionDuration.inSeconds.remainder(60);
    final todayLogCount = summaryStats?.todayCount ?? 0;
    final hoursSinceLastLog = summaryStats?.hoursSinceLastLog ?? 0;
    final weekLogCount = summaryStats?.weekCount ?? 0;
    final textScaler = MediaQuery.textScalerOf(context);
    final panelTop = screenSize.height * (216 / 852);
    final panelHeight = screenSize.height * (636 / 852);
    final xScale = screenSize.width / 393;
    final yScale = panelHeight / 636;

    double sx(double value) => value * xScale;
    double sy(double value) => value * yScale;

    final everyMomentWidth = sx(333);
    final everyMomentTop = sy(32);
    final everyMomentStyle = josefinStyle(
      color: Colors.white,
      fontSize: 18,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      height: 1.24,
    );

    final everyMomentPainter = TextPainter(
      text: TextSpan(text: currentEveryMomentText),
      maxLines: null,
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..text = TextSpan(text: currentEveryMomentText, style: everyMomentStyle)
      ..layout(maxWidth: everyMomentWidth);
    final everyMomentBoxHeight = everyMomentPainter.height + sy(6);
    final everyMomentBottom = everyMomentTop + everyMomentBoxHeight;

    final detailsTop = sy(360);
    final detailsWidth = sx(372);
    final detailsStyle = josefinStyle(
      color: const Color(0xFFE5E5EA),
      fontSize: 18,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      height: 1.26,
    );
    const detailsText =
        'Here are some details you can track for this session. Smooth or not, recording these signals helps you better understand your body.';
    final detailsPainter = TextPainter(
      text: const TextSpan(text: detailsText),
      maxLines: null,
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..text = TextSpan(text: detailsText, style: detailsStyle)
      ..layout(maxWidth: detailsWidth);
    final detailsBoxHeight = detailsPainter.height + sy(6);

    final summaryTextSpan = TextSpan(
      children: [
        TextSpan(
          text: 'Session Summary:\n',
          style: sfProNoShadowStyle(
            color: Colors.black,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.07,
          ),
        ),
        TextSpan(
          text: 'Duration:',
          style: sfProNoShadowStyle(
            color: const Color(0xFFE5E5EA),
            fontSize: 17,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.07,
          ),
        ),
        TextSpan(
          text: ' ${sessionMinutes} min ${sessionSeconds} sec\n',
          style: sfProNoShadowStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.07,
          ),
        ),
        TextSpan(
          text: "Today's Log:",
          style: sfProNoShadowStyle(
            color: const Color(0xFFE5E5EA),
            fontSize: 17,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.07,
          ),
        ),
        TextSpan(
          text: ' $todayLogCount\n',
          style: sfProNoShadowStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.07,
          ),
        ),
        TextSpan(
          text: 'Time since last log:',
          style: sfProNoShadowStyle(
            color: const Color(0xFFE5E5EA),
            fontSize: 17,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.07,
          ),
        ),
        TextSpan(
          text: ' $hoursSinceLastLog hrs\n',
          style: sfProNoShadowStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.07,
          ),
        ),
        TextSpan(
          text: 'Total logs this week:',
          style: sfProNoShadowStyle(
            color: const Color(0xFFE5E5EA),
            fontSize: 17,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.07,
          ),
        ),
        TextSpan(
          text: ' $weekLogCount\n',
          style: sfProNoShadowStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.07,
          ),
        ),
      ],
    );

    final summaryPainter = TextPainter(
      text: summaryTextSpan,
      maxLines: null,
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout(maxWidth: sx(372));
    final availableSpace = detailsTop - everyMomentBottom;
    final computedGap = (availableSpace - summaryPainter.height) / 2;
    final balancedGap = computedGap < 0 ? 0.0 : computedGap;
    final opticalOffset = sy(12.5);
    final summaryTop = everyMomentBottom + balancedGap + opticalOffset;

    final canLogWithMe = committedRecordId != null && !isExiting;
    final summaryContent = Stack(
      key: const ValueKey('summary-content'),
      children: [
        Positioned(
          left: sx(13),
          top: detailsTop,
          child: SizedBox(
            width: detailsWidth,
            height: detailsBoxHeight,
            child: Align(
              alignment: Alignment.topLeft,
              child: Text(detailsText, style: detailsStyle),
            ),
          ),
        ),
        Positioned(
          left: sx(30),
          top: everyMomentTop,
          child: SizedBox(
            width: everyMomentWidth,
            height: everyMomentBoxHeight,
            child: Align(
              alignment: Alignment.topLeft,
              child: Text(
                currentEveryMomentText,
                style: everyMomentStyle,
              ),
            ),
          ),
        ),
        Positioned(
          left: sx(13),
          top: summaryTop,
          child: SizedBox(
            width: sx(372),
            child: Opacity(
              opacity: 0.97,
              child: Text.rich(summaryTextSpan),
            ),
          ),
        ),
        Positioned(
          left: sx(113),
          top: sy(463),
          child: Opacity(
            opacity: canLogWithMe ? 1.0 : 0.5,
            child: GestureDetector(
              onTap: canLogWithMe ? onOpenQuestionnaire : null,
              child: Container(
                width: sx(166),
                height: sy(57),
                decoration: ShapeDecoration(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(1000),
                  ),
                  shadows: const [
                    BoxShadow(color: Color(0xFFFFFFFF), blurRadius: 0.2),
                    BoxShadow(color: Color(0xFFFFFFFF), blurRadius: 0.4),
                    BoxShadow(color: Color(0xFFFFFFFF), blurRadius: 1.39),
                    BoxShadow(color: Color(0xFFFFFFFF), blurRadius: 2.79),
                    BoxShadow(color: Color(0xFFFFFFFF), blurRadius: 4.78),
                    BoxShadow(color: Color(0xFFFFFFFF), blurRadius: 8.37),
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
                            )
                          ],
                        ),
                      ),
                    ),
                    const Center(
                      child: Text(
                        'Log with me',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF1A1A1A),
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
        Positioned(
          left: sx(145),
          top: sy(551),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: isExiting ? null : onMaybeLater,
            child: const Text(
              'Maybe Later',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black,
                fontSize: 17,
                fontFamily: 'Josefin Sans',
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
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
