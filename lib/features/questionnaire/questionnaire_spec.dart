enum QuestionId {
  q1,
  q2,
  q3,
  q4,
  q51,
  q52,
  q6,
  q7,
  q81,
  q82,
  q9,
  q101,
  q102,
}

class QuestionnaireSpec {
  final String title;
  final bool isMultiSelect;
  final List<QuestionnaireOption> options;

  const QuestionnaireSpec({
    required this.title,
    required this.isMultiSelect,
    required this.options,
  });
}

class QuestionnaireOption {
  final String label;
  final int value;
  final bool selectable;

  const QuestionnaireOption({
    required this.label,
    this.value = 0,
    this.selectable = true,
  });
}

QuestionId? nextQuestion(QuestionId questionId, int selectedOption) {
  switch (questionId) {
    case QuestionId.q1:
      if (selectedOption == 1 || selectedOption == 2) return QuestionId.q2;
      return QuestionId.q81;
    case QuestionId.q2:
      return QuestionId.q3;
    case QuestionId.q3:
      return QuestionId.q4;
    case QuestionId.q4:
      return QuestionId.q51;
    case QuestionId.q51:
      return QuestionId.q52;
    case QuestionId.q52:
      return QuestionId.q6;
    case QuestionId.q6:
      return QuestionId.q7;
    case QuestionId.q7:
      return QuestionId.q101;
    case QuestionId.q81:
      return selectedOption == 2 ? QuestionId.q82 : QuestionId.q9;
    case QuestionId.q82:
      return null;
    case QuestionId.q9:
      return QuestionId.q101;
    case QuestionId.q101:
      return QuestionId.q102;
    case QuestionId.q102:
      return null;
  }
}

QuestionnaireSpec questionSpec(QuestionId questionId) {
  switch (questionId) {
    case QuestionId.q1:
      return const QuestionnaireSpec(
        title: 'How did it go?',
        isMultiSelect: false,
        options: [
          QuestionnaireOption(label: 'Passed stool smoothly', value: 1),
          QuestionnaireOption(label: 'Passed a small amount', value: 2),
          QuestionnaireOption(label: 'Tried, but was unable to pass stool', value: 3),
        ],
      );
    case QuestionId.q2:
      return const QuestionnaireSpec(
        title: 'How much effort did it take?',
        isMultiSelect: false,
        options: [
          QuestionnaireOption(label: 'No effort at all / very easy', value: 1),
          QuestionnaireOption(label: 'A little effort', value: 2),
          QuestionnaireOption(label: 'Quite a bit of effort', value: 3),
          QuestionnaireOption(label: 'Lot of effort / Straining for a long time', value: 4),
        ],
      );
    case QuestionId.q3:
      return const QuestionnaireSpec(
        title: 'How do you feel afterwards?',
        isMultiSelect: false,
        options: [
          QuestionnaireOption(label: 'Completely empty', value: 1),
          QuestionnaireOption(label: 'Slightly incomplete', value: 2),
          QuestionnaireOption(label: 'Very incomplete', value: 3),
        ],
      );
    case QuestionId.q4:
      return const QuestionnaireSpec(
        title: 'What was the Consistency?',
        isMultiSelect: false,
        options: [
          QuestionnaireOption(label: 'Well-formed, soft, and easy to pass', value: 1),
          QuestionnaireOption(label: 'Formed, slightly dry, but mostly smooth', value: 2),
          QuestionnaireOption(label: 'Soft lumps, irregular edges, tends to break apart', value: 3),
          QuestionnaireOption(label: 'Formed but hard, with visible cracks', value: 4),
          QuestionnaireOption(label: 'Small, hard pieces (pellet-like), difficult to pass', value: 5),
          QuestionnaireOption(label: 'Loose or watery, not formed', value: 6),
        ],
      );
    case QuestionId.q51:
      return const QuestionnaireSpec(
        title: 'What color was it closest to?',
        isMultiSelect: false,
        options: [
          QuestionnaireOption(label: 'Brown / dark brown', value: 1),
          QuestionnaireOption(label: 'Yellowish brown', value: 2),
          QuestionnaireOption(label: 'Green', value: 3),
          QuestionnaireOption(label: 'Red / reddish', value: 4),
          QuestionnaireOption(label: 'Black / very dark (tar-like)', value: 5),
          QuestionnaireOption(label: 'White / pale / clay-colored', value: 6),
          QuestionnaireOption(label: 'Yellow and oily', value: 7),
          QuestionnaireOption(label: 'Not sure', value: 8),
        ],
      );
    case QuestionId.q52:
      return const QuestionnaireSpec(
        title: 'Any other observations? (Select all that apply)',
        isMultiSelect: true,
        options: [
          QuestionnaireOption(label: 'Nothing unusual', value: 1),
          QuestionnaireOption(label: 'Bright red blood on the surface', value: 2),
          QuestionnaireOption(label: 'Dark red or black blood mixed in', value: 3),
          QuestionnaireOption(label: 'Clear or white mucus', value: 4),
          QuestionnaireOption(label: 'Yellow-white or pus-like discharge', value: 5),
          QuestionnaireOption(label: 'Noticeable undigested food', value: 6),
          QuestionnaireOption(label: 'Oily characteristics:', selectable: false),
          QuestionnaireOption(label: 'Looks oily or shiny', value: 7),
          QuestionnaireOption(label: 'Floating on the water', value: 8),
          QuestionnaireOption(label: 'Oily film left on the toilet bowl', value: 9),
        ],
      );
    case QuestionId.q6:
      return const QuestionnaireSpec(
        title: '(Optional) Would you like to add a few more details?',
        isMultiSelect: true,
        options: [
          QuestionnaireOption(label: 'Amount:', selectable: false),
          QuestionnaireOption(label: 'Very little', value: 1),
          QuestionnaireOption(label: 'Moderate', value: 2),
          QuestionnaireOption(label: 'Large amount', value: 3),
          QuestionnaireOption(label: 'Not sure', value: 4),
          QuestionnaireOption(label: 'Thickness:', selectable: false),
          QuestionnaireOption(label: 'About the same as usual', value: 5),
          QuestionnaireOption(label: 'Slightly thinner', value: 6),
          QuestionnaireOption(label: 'Very thin / Pencil-like', value: 7),
          QuestionnaireOption(label: 'Not sure', value: 8),
        ],
      );
    case QuestionId.q7:
      return const QuestionnaireSpec(
        title: 'How did you feel during the process? (Select all that apply)',
        isMultiSelect: true,
        options: [
          QuestionnaireOption(label: 'No noticeable discomfort', value: 1),
          QuestionnaireOption(label: 'Abdominal pain or cramping', value: 2),
          QuestionnaireOption(label: 'Anal pain', value: 3),
          QuestionnaireOption(label: 'Strong urgency / felt hard to hold', value: 4),
          QuestionnaireOption(label: 'Slight leakage / could not fully hold it', value: 5),
          QuestionnaireOption(label: 'Strong feelings of tension or anxiety', value: 6),
          QuestionnaireOption(label: 'A "blocked" or "stuck" sensation', value: 7),
          QuestionnaireOption(label: 'Needed to change position', value: 8),
          QuestionnaireOption(label: 'Needed to strain or stay here for a long time', value: 9),
          QuestionnaireOption(label: 'Needed to press on the abdomen or use other assistance', value: 10),
          QuestionnaireOption(label: 'Interrupted by external factors', value: 11),
        ],
      );
    case QuestionId.q81:
      return const QuestionnaireSpec(
        title: 'What best describes the main reason this time?',
        isMultiSelect: false,
        options: [
          QuestionnaireOption(label: 'Felt the urge, but could not pass', value: 1),
          QuestionnaireOption(label: 'No clear urge, just tried', value: 2),
          QuestionnaireOption(
              label: 'Felt uneasy or anxious, could not relax physically', value: 3),
          QuestionnaireOption(label: 'The environment did not feel comfortable', value: 4),
          QuestionnaireOption(label: 'Felt pressed for time', value: 5),
          QuestionnaireOption(label: 'Interrupted or had to stop midway', value: 6),
          QuestionnaireOption(label: 'Not sure', value: 7),
        ],
      );
    case QuestionId.q82:
      return const QuestionnaireSpec(
        title: 'What mainly led you to try this time?',
        isMultiSelect: false,
        options: [
          QuestionnaireOption(
              label: 'Wanted to go in advance in case there is no time later', value: 1),
          QuestionnaireOption(label: 'Felt a bit anxious and wanted to check', value: 2),
          QuestionnaireOption(
              label: 'The environment felt suitable, so decided to try', value: 3),
          QuestionnaireOption(label: 'Just tried casually', value: 4),
          QuestionnaireOption(label: 'Not sure', value: 5),
        ],
      );
    case QuestionId.q9:
      return const QuestionnaireSpec(
        title: 'How did you feel during the process? (Select all that apply)',
        isMultiSelect: true,
        options: [
          QuestionnaireOption(label: 'No noticeable discomfort', value: 1),
          QuestionnaireOption(label: 'Abdominal pain or cramping', value: 2),
          QuestionnaireOption(label: 'Anal pain', value: 3),
          QuestionnaireOption(label: 'Strong urgency / felt hard to hold', value: 4),
          QuestionnaireOption(label: 'Slight leakage / could not fully hold it', value: 5),
          QuestionnaireOption(label: 'Strong feelings of tension or anxiety', value: 6),
          QuestionnaireOption(label: 'A "blocked" or "stuck" sensation', value: 7),
          QuestionnaireOption(label: 'Needed to change position', value: 8),
          QuestionnaireOption(label: 'Needed to strain or sit for a long time', value: 9),
          QuestionnaireOption(label: 'Needed to press on the abdomen or use other assistance', value: 10),
          QuestionnaireOption(label: 'Interrupted by external factors', value: 11),
        ],
      );
    case QuestionId.q101:
      return const QuestionnaireSpec(
        title: 'Aside from the bowel movement, any other discomfort today? (Select all that apply)',
        isMultiSelect: true,
        options: [
          QuestionnaireOption(label: 'No other noticeable discomfort', value: 1),
          QuestionnaireOption(label: 'Bloating', value: 2),
          QuestionnaireOption(label: 'Nausea', value: 3),
          QuestionnaireOption(label: 'Vomiting', value: 4),
          QuestionnaireOption(label: 'Fever or chills', value: 5),
          QuestionnaireOption(label: 'Dizziness or fatigue', value: 6),
          QuestionnaireOption(label: 'Loss of appetite', value: 7),
          QuestionnaireOption(label: 'Unintentional weight loss', value: 8),
          QuestionnaireOption(label: 'Not sure', value: 9),
        ],
      );
    case QuestionId.q102:
      return const QuestionnaireSpec(
        title: '(Optional) Would you like to add any related background factors?',
        isMultiSelect: true,
        options: [
          QuestionnaireOption(label: 'Drank less water today', value: 1),
          QuestionnaireOption(label: 'Ate less than usual', value: 2),
          QuestionnaireOption(label: 'Ate a lot of greasy food', value: 3),
          QuestionnaireOption(label: 'Ate spicy or irritating food', value: 4),
          QuestionnaireOption(label: 'Had coffee or alcohol', value: 5),
          QuestionnaireOption(label: 'Currently on menstrual period', value: 6),
          QuestionnaireOption(label: 'Felt very stressed or anxious today', value: 7),
          QuestionnaireOption(label: 'Poor sleep recently', value: 8),
          QuestionnaireOption(label: 'Change in bathroom environment', value: 9),
          QuestionnaireOption(label: 'Change in daily routine', value: 10),
          QuestionnaireOption(label: 'Took laxatives', value: 11),
          QuestionnaireOption(label: 'Took iron supplements or new medication', value: 12),
          QuestionnaireOption(label: 'Not sure', value: 13),
        ],
      );
  }
}
