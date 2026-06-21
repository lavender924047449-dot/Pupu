import 'package:pupu/features/questionnaire/questionnaire_spec.dart';

/// 问卷必做/路径/作答校验（纯函数，便于单测）。
abstract final class QuestionnaireValidation {
  /// 单选：有选中项；多选：至少一项。
  static bool isQuestionAnswered(
    QuestionId id,
    Map<QuestionId, Set<int>> answers,
  ) {
    final selected = answers[id];
    return selected != null && selected.isNotEmpty;
  }

  static int? _singleAnswer(
    QuestionId id,
    Map<QuestionId, Set<int>> answers,
  ) {
    final selected = answers[id];
    if (selected == null || selected.isEmpty) return null;
    return selected.first;
  }

  /// 在当前分支路径上，该题是否为必做。
  static bool isRequiredOnPath(
    QuestionId id,
    Map<QuestionId, Set<int>> answers,
  ) {
    if (!isRequiredQuestion(id)) return false;

    final q1 = _singleAnswer(QuestionId.q1, answers);

    switch (id) {
      case QuestionId.q1:
        return true;
      case QuestionId.q2:
      case QuestionId.q3:
      case QuestionId.q4:
      case QuestionId.q51:
      case QuestionId.q52:
      case QuestionId.q7:
        return q1 == 1 || q1 == 2;
      case QuestionId.q81:
        return q1 == 3;
      case QuestionId.q82:
        return q1 == 3 && _singleAnswer(QuestionId.q81, answers) == 2;
      case QuestionId.q9:
        final q81 = _singleAnswer(QuestionId.q81, answers);
        return q1 == 3 && q81 != null && q81 != 2;
      default:
        return false;
    }
  }

  /// 从 q1 沿当前答案模拟路径，收集路径上的必做题 ID。
  static List<QuestionId> expectedRequiredOnPath(
    Map<QuestionId, Set<int>> answers,
  ) {
    final result = <QuestionId>[];
    var current = QuestionId.q1;

    while (true) {
      if (isRequiredOnPath(current, answers)) {
        result.add(current);
        if (!isQuestionAnswered(current, answers)) break;
      }

      final next = _resolveNext(current, answers);
      if (next == null) break;
      current = next;
    }

    return result;
  }

  /// 路径上所有未作答的必做题（保持路径顺序）。
  static List<QuestionId> unfinishedRequired(
    Map<QuestionId, Set<int>> answers,
  ) {
    return expectedRequiredOnPath(answers)
        .where((id) => !isQuestionAnswered(id, answers))
        .toList(growable: false);
  }

  /// 必做多选且当前路径必做、尚未选择任何项 → 阻止 Next。
  static bool shouldBlockRequiredMultiNext(
    QuestionId id,
    Map<QuestionId, Set<int>> answers,
  ) {
    if (!requiredMultiSelectIds.contains(id)) return false;
    if (!isRequiredOnPath(id, answers)) return false;
    return !isQuestionAnswered(id, answers);
  }

  /// 选做题或未选时可按默认 option 推进；必做未答则无法推进。
  static QuestionId? _resolveNext(
    QuestionId current,
    Map<QuestionId, Set<int>> answers,
  ) {
    final selected = answers[current];
    if (selected != null && selected.isNotEmpty) {
      return nextQuestion(current, selected.first);
    }
    if (optionalQuestionIds.contains(current)) {
      return nextQuestion(current, 1);
    }
    return null;
  }
}
