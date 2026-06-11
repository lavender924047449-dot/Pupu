import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:pupu/features/questionnaire/questionnaire_flow.dart';
import 'package:pupu/features/questionnaire/questionnaire_layout_tokens.dart';
import 'package:pupu/features/questionnaire/questionnaire_spec.dart';

class QuestionnaireInteractivePanel extends StatefulWidget {
  final QuestionnaireFlow flow;
  final QuestionnaireLayoutTokens layout;
  final VoidCallback onFinish;
  final Animation<double>? finishOpacityAnimation;

  const QuestionnaireInteractivePanel({
    super.key,
    required this.flow,
    required this.layout,
    required this.onFinish,
    this.finishOpacityAnimation,
  });

  @override
  State<QuestionnaireInteractivePanel> createState() =>
      _QuestionnaireInteractivePanelState();
}

class _QuestionnaireInteractivePanelState
    extends State<QuestionnaireInteractivePanel> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final didUserScroll = position.userScrollDirection != ScrollDirection.idle;
    final reachedBottom = position.pixels >= (position.maxScrollExtent - 12.0);
    widget.flow.onQuestionnaireScrolled(
      reachedBottom: reachedBottom,
      didUserScroll: didUserScroll,
    );
  }

  TextStyle _sf({
    required Color color,
    required double fontSize,
    required FontWeight weight,
  }) {
    return TextStyle(
      color: color,
      fontSize: widget.layout.scaledFont(fontSize),
      fontWeight: weight,
      fontFamily: 'SF Pro',
    );
  }

  Widget _pillButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: widget.layout.sx(14),
          vertical: widget.layout.sy(8),
        ),
        decoration: ShapeDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
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
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: _sf(
            color: const Color(0xFF0088FF),
            fontSize: 16,
            weight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final flow = widget.flow;
    return AnimatedBuilder(
      animation: flow,
      builder: (context, _) {
        return Stack(
          children: [
            Positioned.fill(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: EdgeInsets.fromLTRB(
                  widget.layout.sx(13),
                  widget.layout.sy(26),
                  widget.layout.sx(8),
                  widget.layout.sy(84),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children:
                      List.generate(flow.visibleQuestions.length, (index) {
                    final questionId = flow.visibleQuestions[index];
                    final spec = questionSpec(questionId);
                    final selectedOptions =
                        flow.selectedAnswers[questionId] ?? <int>{};
                    final isCompleted = flow.completedQuestions.contains(questionId);
                    final isFadingIn = flow.fadingInQuestions.contains(questionId);
                    final isCollapsed = flow.isCollapsed(questionId);

                    return Padding(
                      padding: EdgeInsets.only(bottom: widget.layout.sy(18)),
                      child: AnimatedOpacity(
                        opacity: isFadingIn ? 0.0 : (isCompleted ? 0.4 : 1.0),
                        duration: const Duration(seconds: 1),
                        curve: Curves.easeInOut,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (flow.isCollapsibleQuestion(questionId))
                              Padding(
                                padding: EdgeInsets.only(
                                  bottom: widget.layout.sy(8),
                                ),
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () =>
                                      flow.toggleQuestionCollapsed(questionId),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: widget.layout.sy(6),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Flexible(
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  'Any other little details?',
                                                  style: _sf(
                                                    color: const Color(0xFF0088FF),
                                                    fontSize: 18,
                                                    weight: FontWeight.w600,
                                                  ).copyWith(height: 1),
                                                ),
                                                SizedBox(
                                                  width: widget.layout.sx(4),
                                                ),
                                                Text(
                                                  isCollapsed ? '▼' : '▲',
                                                  style: _sf(
                                                    color: const Color(0xFF0088FF),
                                                    fontSize: 18,
                                                    weight: FontWeight.w600,
                                                  ).copyWith(height: 1),
                                                ),
                                              ],
                                            ),
                                          ),
                                          _pillButton(
                                            label: 'Skip',
                                            onTap: () => flow.skipQuestion(questionId),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (!flow.isCollapsibleQuestion(questionId) || !isCollapsed)
                              ...[
                                Text(
                                  'Q${index + 1} ${spec.title}',
                                  style: _sf(
                                    color: Colors.white,
                                    fontSize: 18,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: widget.layout.sy(6)),
                              ],
                            if (!isCollapsed)
                              ...List.generate(spec.options.length, (optionIndex) {
                                final option = spec.options[optionIndex];
                                if (!option.selectable) {
                                  return Padding(
                                    padding: EdgeInsets.only(
                                        bottom: widget.layout.sy(4)),
                                    child: Text(
                                      option.label,
                                      style: _sf(
                                        color: Colors.white,
                                        fontSize: 18,
                                        weight: FontWeight.w600,
                                      ),
                                    ),
                                  );
                                }
                                final logicalIndex = option.value;
                                final isSelected =
                                    selectedOptions.contains(logicalIndex);
                                return SizedBox(
                                  width: double.infinity,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () =>
                                        flow.onOptionSelected(questionId, logicalIndex),
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                        bottom: widget.layout.sy(4),
                                      ),
                                      child: Container(
                                        width: double.infinity,
                                        decoration: isSelected
                                            ? BoxDecoration(
                                                color: const Color(0xFF0088FF).withValues(
                                                  alpha: isCompleted ? 0.4 : 1.0,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              )
                                            : null,
                                        padding: EdgeInsets.symmetric(
                                          horizontal: widget.layout.sx(8),
                                          vertical: widget.layout.sy(2),
                                        ),
                                        child: Text(
                                          '• ${option.label}',
                                          style: _sf(
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.white.withValues(alpha: 0.92),
                                            fontSize: 18,
                                            weight: isSelected
                                                ? FontWeight.w600
                                                : FontWeight.w400,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            if (!isCollapsed &&
                                spec.isMultiSelect &&
                                questionId != QuestionId.q102)
                              Padding(
                                padding: EdgeInsets.only(
                                  top: widget.layout.sy(8),
                                ),
                                child: _pillButton(
                                  label: 'Next',
                                  onTap: () => flow.advanceFromMultiQuestion(questionId),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
            if (flow.shouldShowFinishButton())
              Positioned(
                right: widget.layout.sx(18),
                bottom: widget.layout.sy(18),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onFinish,
                  child: AnimatedBuilder(
                    animation: widget.finishOpacityAnimation ??
                        const AlwaysStoppedAnimation<double>(1),
                    builder: (context, child) {
                      final opacity = widget.finishOpacityAnimation == null
                          ? 1.0
                          : TweenSequence<double>([
                              TweenSequenceItem(
                                tween: Tween(begin: 1.0, end: 0.4),
                                weight: 50,
                              ),
                              TweenSequenceItem(
                                tween: Tween(begin: 0.4, end: 1.0),
                                weight: 50,
                              ),
                            ]).evaluate(widget.finishOpacityAnimation!);
                      return Opacity(opacity: opacity, child: child);
                    },
                    child: Text(
                      '>>Finish Logging',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: const Color(0xFFC6C6C8),
                        fontSize: widget.layout.scaledFont(16),
                        fontFamily: 'SF Pro',
                        fontWeight: FontWeight.w400,
                        letterSpacing: 2.40 * widget.layout.scaleX,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
