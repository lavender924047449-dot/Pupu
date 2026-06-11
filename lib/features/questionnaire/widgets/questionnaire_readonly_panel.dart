import 'package:flutter/material.dart';
import 'package:pupu/core/widgets/liquid_glass_background.dart';
import 'package:pupu/features/questionnaire/questionnaire_layout_tokens.dart';
import 'package:pupu/features/questionnaire/questionnaire_spec.dart';

class QuestionnaireReadonlyPanel extends StatelessWidget {
  final Map<String, List<int>> answers;
  final QuestionnaireLayoutTokens layout;
  final ScrollController? scrollController;

  const QuestionnaireReadonlyPanel({
    super.key,
    required this.answers,
    required this.layout,
    this.scrollController,
  });

  TextStyle _sf({
    required Color color,
    required double fontSize,
    required FontWeight weight,
  }) {
    return TextStyle(
      color: color,
      fontSize: layout.scaledFont(fontSize),
      fontWeight: weight,
      fontFamily: 'SF Pro',
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = <({QuestionId id, List<int> selected})>[];
    for (final questionId in QuestionId.values) {
      final selected = answers[questionId.name];
      if (selected == null || selected.isEmpty) continue;
      items.add((id: questionId, selected: selected));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          const Positioned.fill(child: LiquidGlassBackground()),
          SingleChildScrollView(
            controller: scrollController,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: layout.sx(13),
              vertical: layout.sy(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(items.length, (index) {
                final item = items[index];
                final spec = questionSpec(item.id);
                final optionByValue = <int, QuestionnaireOption>{};
                for (final option in spec.options) {
                  if (!option.selectable) continue;
                  optionByValue[option.value] = option;
                }
                final selectedOptions = item.selected
                    .map((value) => optionByValue[value])
                    .whereType<QuestionnaireOption>()
                    .toList();

                if (selectedOptions.isEmpty) {
                  return const SizedBox.shrink();
                }

                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == items.length - 1 ? 0 : layout.sy(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Q${index + 1} ${spec.title}',
                        style: _sf(
                          color: Colors.white,
                          fontSize: 18,
                          weight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: layout.sy(6)),
                      ...selectedOptions.map(
                        (option) => Padding(
                          padding: EdgeInsets.only(bottom: layout.sy(4)),
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0088FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: layout.sx(8),
                              vertical: layout.sy(2),
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
              }),
            ),
          ),
        ],
      ),
    );
  }
}
