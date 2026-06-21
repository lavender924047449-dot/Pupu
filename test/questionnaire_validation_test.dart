import 'package:flutter_test/flutter_test.dart';
import 'package:pupu/features/questionnaire/questionnaire_spec.dart';
import 'package:pupu/features/questionnaire/questionnaire_validation.dart';

Map<QuestionId, Set<int>> _answers(Map<QuestionId, int> raw) {
  return raw.map((key, value) => MapEntry(key, {value}));
}

void main() {
  group('isRequiredOnPath', () {
    test('success path requires q2–q52 and q7', () {
      final answers = _answers({QuestionId.q1: 1});
      expect(QuestionnaireValidation.isRequiredOnPath(QuestionId.q2, answers), isTrue);
      expect(QuestionnaireValidation.isRequiredOnPath(QuestionId.q7, answers), isTrue);
      expect(QuestionnaireValidation.isRequiredOnPath(QuestionId.q81, answers), isFalse);
    });

    test('failure path q81≠2 requires q81 and q9', () {
      final answers = _answers({
        QuestionId.q1: 3,
        QuestionId.q81: 1,
      });
      expect(QuestionnaireValidation.isRequiredOnPath(QuestionId.q9, answers), isTrue);
      expect(QuestionnaireValidation.isRequiredOnPath(QuestionId.q82, answers), isFalse);
      expect(QuestionnaireValidation.isRequiredOnPath(QuestionId.q7, answers), isFalse);
    });

    test('failure path q81=2 requires q82 only as terminal branch', () {
      final answers = _answers({
        QuestionId.q1: 3,
        QuestionId.q81: 2,
      });
      expect(QuestionnaireValidation.isRequiredOnPath(QuestionId.q82, answers), isTrue);
      expect(QuestionnaireValidation.isRequiredOnPath(QuestionId.q9, answers), isFalse);
    });
  });

  group('unfinishedRequired', () {
    test('missing q7 on success path', () {
      final answers = _answers({
        QuestionId.q1: 1,
        QuestionId.q2: 1,
        QuestionId.q3: 1,
        QuestionId.q4: 1,
        QuestionId.q51: 1,
        QuestionId.q52: 1,
      });
      final unfinished = QuestionnaireValidation.unfinishedRequired(answers);
      expect(unfinished, contains(QuestionId.q7));
    });

    test('missing q9 on failure path', () {
      final answers = _answers({
        QuestionId.q1: 3,
        QuestionId.q81: 1,
      });
      final unfinished = QuestionnaireValidation.unfinishedRequired(answers);
      expect(unfinished, contains(QuestionId.q9));
    });

    test('missing q82 on q81=2 terminal branch', () {
      final answers = _answers({
        QuestionId.q1: 3,
        QuestionId.q81: 2,
      });
      final unfinished = QuestionnaireValidation.unfinishedRequired(answers);
      expect(unfinished, contains(QuestionId.q82));
    });

    test('q6/q101/q102 skipped do not appear in unfinished', () {
      final answers = _answers({
        QuestionId.q1: 1,
        QuestionId.q2: 1,
        QuestionId.q3: 1,
        QuestionId.q4: 1,
        QuestionId.q51: 1,
        QuestionId.q52: 1,
        QuestionId.q7: 1,
      });
      final unfinished = QuestionnaireValidation.unfinishedRequired(answers);
      expect(unfinished, isEmpty);
    });
  });

  group('shouldBlockRequiredMultiNext', () {
    test('blocks empty required multi q52', () {
      final answers = _answers({
        QuestionId.q1: 1,
        QuestionId.q2: 1,
        QuestionId.q3: 1,
        QuestionId.q4: 1,
        QuestionId.q51: 1,
      });
      expect(
        QuestionnaireValidation.shouldBlockRequiredMultiNext(QuestionId.q52, answers),
        isTrue,
      );
    });

    test('does not block optional q6', () {
      final answers = _answers({
        QuestionId.q1: 1,
        QuestionId.q2: 1,
        QuestionId.q3: 1,
        QuestionId.q4: 1,
        QuestionId.q51: 1,
        QuestionId.q52: 1,
      });
      expect(
        QuestionnaireValidation.shouldBlockRequiredMultiNext(QuestionId.q6, answers),
        isFalse,
      );
    });

    test('does not block optional q101', () {
      final answers = _answers({
        QuestionId.q1: 1,
        QuestionId.q2: 1,
        QuestionId.q3: 1,
        QuestionId.q4: 1,
        QuestionId.q51: 1,
        QuestionId.q52: 1,
        QuestionId.q7: 1,
      });
      expect(
        QuestionnaireValidation.shouldBlockRequiredMultiNext(QuestionId.q101, answers),
        isFalse,
      );
    });

    test('does not block when selection exists', () {
      final answers = {
        QuestionId.q1: {1},
        QuestionId.q52: {1},
      };
      expect(
        QuestionnaireValidation.shouldBlockRequiredMultiNext(QuestionId.q52, answers),
        isFalse,
      );
    });
  });
}
