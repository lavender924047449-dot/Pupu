import 'package:flutter_test/flutter_test.dart';
import 'package:pupu/features/questionnaire/questionnaire_flow.dart';
import 'package:pupu/features/questionnaire/questionnaire_spec.dart';

void main() {
  test('shouldShowFinishButton hidden when q82 unanswered on terminal branch', () {
    final flow = QuestionnaireFlow();
    flow.onOptionSelected(QuestionId.q1, 3);
    flow.onOptionSelected(QuestionId.q81, 2);
    flow.onQuestionnaireScrolled(reachedBottom: true, didUserScroll: true);

    expect(flow.shouldShowFinishButton(), isFalse);

    flow.onOptionSelected(QuestionId.q82, 1);
    expect(flow.shouldShowFinishButton(), isTrue);
  });
}
