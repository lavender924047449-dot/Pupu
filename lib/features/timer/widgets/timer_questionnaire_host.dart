import 'package:flutter/material.dart';
import 'package:pupu/features/questionnaire/questionnaire_flow.dart';
import 'package:pupu/features/questionnaire/questionnaire_layout_tokens.dart';
import 'package:pupu/features/questionnaire/widgets/questionnaire_interactive_panel.dart';

class TimerQuestionnaireHost extends StatelessWidget {
  const TimerQuestionnaireHost({
    super.key,
    required this.screenSize,
    required this.panelHeight,
    required this.showQuestionnaire,
    required this.questionnaireFlow,
    required this.finishLoggingController,
    required this.onFinishQuestionnaire,
    required this.summaryContent,
  });

  final Size screenSize;
  final double panelHeight;
  final bool showQuestionnaire;
  final QuestionnaireFlow questionnaireFlow;
  final Animation<double> finishLoggingController;
  final Future<void> Function() onFinishQuestionnaire;
  final Widget summaryContent;

  @override
  Widget build(BuildContext context) {
    final questionnaireContent = SizedBox(
      key: const ValueKey('questionnaire-content'),
      width: screenSize.width,
      height: panelHeight,
      child: QuestionnaireInteractivePanel(
        flow: questionnaireFlow,
        layout: QuestionnaireLayoutTokens.full(screenSize: screenSize),
        onFinish: onFinishQuestionnaire,
        finishOpacityAnimation: finishLoggingController,
      ),
    );

    return AnimatedSwitcher(
      duration: const Duration(seconds: 1),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: showQuestionnaire ? questionnaireContent : summaryContent,
    );
  }
}
