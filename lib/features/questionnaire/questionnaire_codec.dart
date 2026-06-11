import 'package:pupu/features/questionnaire/questionnaire_spec.dart';

Map<String, List<int>> encodeAnswers(
  Map<QuestionId, Set<int>> selectedAnswers,
  List<QuestionId> visibleOrder,
) {
  final result = <String, List<int>>{};
  for (final questionId in visibleOrder) {
    final values = selectedAnswers[questionId];
    if (values == null || values.isEmpty) continue;
    final sorted = values.toList()..sort();
    result[questionId.name] = sorted;
  }
  return result;
}

Map<QuestionId, Set<int>> decodeAnswers(Map<String, List<int>> answers) {
  final result = <QuestionId, Set<int>>{};
  for (final entry in answers.entries) {
    QuestionId? questionId;
    for (final value in QuestionId.values) {
      if (value.name == entry.key) {
        questionId = value;
        break;
      }
    }
    if (questionId == null) continue;
    result[questionId] = entry.value.toSet();
  }
  return result;
}
