import 'package:flutter/foundation.dart';
import 'package:pupu/features/questionnaire/questionnaire_spec.dart';

class QuestionnaireFlow extends ChangeNotifier {
  final List<QuestionId> _visibleQuestions = [QuestionId.q1];
  final Map<QuestionId, Set<int>> _selectedAnswers = {};
  final Set<QuestionId> _completedQuestions = {};
  final Set<QuestionId> _fadingInQuestions = {};
  final Set<QuestionId> _collapsedQuestions = {
    QuestionId.q6,
    QuestionId.q101,
  };

  bool _questionnaireAtBottom = false;
  bool _requireScrollAfterTerminalShown = false;
  bool _didUserScrollAfterTerminalShown = false;

  List<QuestionId> get visibleQuestions => List.unmodifiable(_visibleQuestions);
  Map<QuestionId, Set<int>> get selectedAnswers => Map.unmodifiable(_selectedAnswers);
  Set<QuestionId> get completedQuestions => Set.unmodifiable(_completedQuestions);
  Set<QuestionId> get fadingInQuestions => Set.unmodifiable(_fadingInQuestions);

  bool isCollapsed(QuestionId questionId) => _collapsedQuestions.contains(questionId);

  void reset() {
    _visibleQuestions
      ..clear()
      ..add(QuestionId.q1);
    _selectedAnswers.clear();
    _completedQuestions.clear();
    _fadingInQuestions.clear();
    _collapsedQuestions
      ..clear()
      ..add(QuestionId.q6)
      ..add(QuestionId.q101);
    _questionnaireAtBottom = false;
    _requireScrollAfterTerminalShown = false;
    _didUserScrollAfterTerminalShown = false;
    notifyListeners();
  }

  bool isCollapsibleQuestion(QuestionId questionId) {
    return questionId == QuestionId.q6 || questionId == QuestionId.q101;
  }

  void toggleQuestionCollapsed(QuestionId questionId) {
    if (!isCollapsibleQuestion(questionId)) return;
    if (_collapsedQuestions.contains(questionId)) {
      _collapsedQuestions.remove(questionId);
    } else {
      _collapsedQuestions.add(questionId);
    }
    notifyListeners();
  }

  bool shouldShowFinishButton() {
    if (_visibleQuestions.isEmpty) return false;
    final lastQuestion = _visibleQuestions.last;
    final selected = _selectedAnswers[lastQuestion];
    final selectedOption = (selected == null || selected.isEmpty) ? 1 : selected.first;
    final noNextQuestion = nextQuestion(lastQuestion, selectedOption) == null;
    if (!noNextQuestion) return false;
    if (_requireScrollAfterTerminalShown && !_didUserScrollAfterTerminalShown) {
      return false;
    }
    return _questionnaireAtBottom;
  }

  void onQuestionnaireScrolled({
    required bool reachedBottom,
    required bool didUserScroll,
  }) {
    if (_requireScrollAfterTerminalShown && didUserScroll && !_didUserScrollAfterTerminalShown) {
      _didUserScrollAfterTerminalShown = true;
    }
    if (reachedBottom == _questionnaireAtBottom) return;
    _questionnaireAtBottom = reachedBottom;
    notifyListeners();
  }

  bool _isTerminalQuestion(QuestionId questionId) {
    return nextQuestion(questionId, 1) == null;
  }

  void _onQuestionAppended(QuestionId questionId) {
    _questionnaireAtBottom = false;
    if (_isTerminalQuestion(questionId)) {
      _requireScrollAfterTerminalShown = true;
      _didUserScrollAfterTerminalShown = false;
      return;
    }
    _requireScrollAfterTerminalShown = false;
    _didUserScrollAfterTerminalShown = false;
  }

  void skipQuestion(QuestionId questionId) {
    final index = _visibleQuestions.indexOf(questionId);
    if (index == -1) return;

    final next = nextQuestion(questionId, 1);
    if (next == null) return;

    _completedQuestions.add(questionId);
    if (index + 1 < _visibleQuestions.length) {
      if (_visibleQuestions[index + 1] == next) {
        notifyListeners();
        return;
      }
      _visibleQuestions.removeRange(index + 1, _visibleQuestions.length);
    }
    _visibleQuestions.add(next);
    _onQuestionAppended(next);
    _selectedAnswers.removeWhere((key, _) => !_visibleQuestions.contains(key));
    _completedQuestions.removeWhere((key) => !_visibleQuestions.contains(key));
    notifyListeners();
  }

  void onOptionSelected(QuestionId questionId, int optionIndex) {
    final spec = questionSpec(questionId);
    if (spec.isMultiSelect) {
      final current = _selectedAnswers.putIfAbsent(questionId, () => <int>{});
      if (questionId == QuestionId.q6) {
        const amountGroup = <int>{1, 2, 3, 4};
        const thicknessGroup = <int>{5, 6, 7, 8};
        if (amountGroup.contains(optionIndex)) {
          current.removeWhere((value) => amountGroup.contains(value));
          current.add(optionIndex);
          notifyListeners();
          return;
        }
        if (thicknessGroup.contains(optionIndex)) {
          current.removeWhere((value) => thicknessGroup.contains(value));
          current.add(optionIndex);
          notifyListeners();
          return;
        }
      }
      if (current.contains(optionIndex)) {
        current.remove(optionIndex);
      } else {
        current.add(optionIndex);
      }
      notifyListeners();
      return;
    }

    final index = _visibleQuestions.indexOf(questionId);
    if (index == -1) return;
    _selectedAnswers[questionId] = {optionIndex};

    final next = nextQuestion(questionId, optionIndex);
    final hasOldNext = index + 1 < _visibleQuestions.length;
    final oldNext = hasOldNext ? _visibleQuestions[index + 1] : null;
    if (oldNext != null && oldNext != next) {
      _visibleQuestions.removeRange(index + 1, _visibleQuestions.length);
    }
    if (next == null) {
      _completedQuestions.add(questionId);
      notifyListeners();
      return;
    }
    final hasNextNow = index + 1 < _visibleQuestions.length;
    if (!hasNextNow) {
      _visibleQuestions.add(next);
      _onQuestionAppended(next);
    }
    _selectedAnswers.removeWhere((key, _) => !_visibleQuestions.contains(key));
    _completedQuestions.removeWhere((key) => !_visibleQuestions.contains(key));
    _completedQuestions.add(questionId);
    notifyListeners();
  }

  void advanceFromMultiQuestion(QuestionId questionId) {
    final index = _visibleQuestions.indexOf(questionId);
    if (index == -1) return;
    final selected = _selectedAnswers[questionId];
    final selectedOption = (selected == null || selected.isEmpty) ? 1 : selected.first;
    final next = nextQuestion(questionId, selectedOption);
    if (next == null) return;

    _completedQuestions.add(questionId);
    if (index + 1 < _visibleQuestions.length) {
      if (_visibleQuestions[index + 1] == next) {
        notifyListeners();
        return;
      }
      _visibleQuestions.removeRange(index + 1, _visibleQuestions.length);
    }
    _visibleQuestions.add(next);
    _onQuestionAppended(next);
    _selectedAnswers.removeWhere((key, _) => !_visibleQuestions.contains(key));
    _completedQuestions.removeWhere((key) => !_visibleQuestions.contains(key));
    notifyListeners();
  }
}
