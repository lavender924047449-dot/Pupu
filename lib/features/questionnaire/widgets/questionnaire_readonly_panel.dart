import 'package:flutter/material.dart';
import 'package:pupu/core/widgets/liquid_glass_background.dart';
import 'package:pupu/features/questionnaire/questionnaire_layout_tokens.dart';
import 'package:pupu/features/questionnaire/questionnaire_spec.dart';

class QuestionnaireReadonlyPanel extends StatefulWidget {
  final Map<String, List<int>> answers;
  final QuestionnaireLayoutTokens layout;
  final ScrollController? scrollController;

  /// 仅 Logs 内联只读块传入；超过该数量的已答题目默认折叠。
  final int? collapseAfterAnsweredCount;

  const QuestionnaireReadonlyPanel({
    super.key,
    required this.answers,
    required this.layout,
    this.scrollController,
    this.collapseAfterAnsweredCount,
  });

  @override
  State<QuestionnaireReadonlyPanel> createState() =>
      _QuestionnaireReadonlyPanelState();
}

class _QuestionnaireReadonlyPanelState extends State<QuestionnaireReadonlyPanel> {
  bool _expanded = false;

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

  List<({QuestionId id, List<int> selected})> _answeredItems() {
    final items = <({QuestionId id, List<int> selected})>[];
    for (final questionId in QuestionId.values) {
      final selected = widget.answers[questionId.name];
      if (selected == null || selected.isEmpty) continue;
      items.add((id: questionId, selected: selected));
    }
    return items;
  }

  Widget _buildQuestionBlock({
    required QuestionId questionId,
    required List<int> selected,
    required bool isLast,
  }) {
    final spec = questionSpec(questionId);
    final optionByValue = <int, QuestionnaireOption>{};
    for (final option in spec.options) {
      if (!option.selectable) continue;
      optionByValue[option.value] = option;
    }
    final selectedOptions = selected
        .map((value) => optionByValue[value])
        .whereType<QuestionnaireOption>()
        .toList();

    if (selectedOptions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : widget.layout.sy(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            spec.title,
            style: _sf(
              color: Colors.white,
              fontSize: 18,
              weight: FontWeight.w600,
            ),
          ),
          SizedBox(height: widget.layout.sy(6)),
          ...selectedOptions.map(
            (option) => Padding(
              padding: EdgeInsets.only(bottom: widget.layout.sy(4)),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF0088FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: widget.layout.sx(8),
                  vertical: widget.layout.sy(2),
                ),
                child: Text(
                  '• ${option.label}',
                  style: _sf(
                    color: Colors.white,
                    fontSize: 18,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapseToggle({required bool expanded}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _expanded = !_expanded),
      child: Padding(
        padding: EdgeInsets.only(top: widget.layout.sy(4)),
        child: Align(
          alignment: Alignment.centerRight,
          child: Text(
            expanded ? '▲' : '▼',
            style: _sf(
              color: const Color(0xFF0088FF),
              fontSize: 18,
              weight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _answeredItems();
    if (items.isEmpty) return const SizedBox.shrink();

    final collapseAfter = widget.collapseAfterAnsweredCount;
    final canCollapse =
        collapseAfter != null && items.length > collapseAfter;
    final visibleCount =
        canCollapse && !_expanded ? collapseAfter : items.length;
    final visibleItems = items.take(visibleCount).toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          const Positioned.fill(child: LiquidGlassBackground()),
          SingleChildScrollView(
            controller: widget.scrollController,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: widget.layout.sx(13),
              vertical: widget.layout.sy(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Log Details',
                  style: _sf(
                    color: Colors.white,
                    fontSize: 16,
                    weight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: widget.layout.sy(14)),
                ...List.generate(visibleItems.length, (index) {
                  final item = visibleItems[index];
                  return _buildQuestionBlock(
                    questionId: item.id,
                    selected: item.selected,
                    isLast: !canCollapse && index == visibleItems.length - 1,
                  );
                }),
                if (canCollapse) _buildCollapseToggle(expanded: _expanded),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
