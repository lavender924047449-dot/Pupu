import 'package:pupu/models/bowel_record.dart';

DateTime normalizeDay(DateTime value) => DateTime(value.year, value.month, value.day);

DateTime defaultDayFromRecords(List<BowelRecord> all) {
  if (all.isEmpty) return normalizeDay(DateTime.now());
  final latest = all.reduce(
    (a, b) => a.dateTime.isAfter(b.dateTime) ? a : b,
  );
  return normalizeDay(latest.dateTime);
}

List<BowelRecord> recordsForDay(List<BowelRecord> all, DateTime day) {
  final normalized = normalizeDay(day);
  final matched = all.where((record) {
    final date = record.dateTime;
    return date.year == normalized.year &&
        date.month == normalized.month &&
        date.day == normalized.day;
  }).toList();
  matched.sort((a, b) => a.dateTime.compareTo(b.dateTime));
  return matched;
}

bool hasQuestionnaireAnswers(BowelRecord record) {
  final answers = record.questionnaireAnswers;
  return answers != null && answers.isNotEmpty;
}

/// Days that have at least one bowel record (same rule as Log Calendar).
Set<DateTime> recordDaysFromRecords(Iterable<BowelRecord> records) {
  return records.map((r) => normalizeDay(r.dateTime)).toSet();
}
