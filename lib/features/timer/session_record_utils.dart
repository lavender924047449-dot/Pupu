import 'package:pupu/models/bowel_record.dart';
import 'package:pupu/services/local_storage.dart';

class SessionSummaryStats {
  final int todayCount;
  final int hoursSinceLastLog;
  final int weekCount;

  const SessionSummaryStats({
    required this.todayCount,
    required this.hoursSinceLastLog,
    required this.weekCount,
  });
}

Future<BowelRecord> commitTimerSession({
  required DateTime startedAt,
  required Duration elapsed,
}) async {
  final record = BowelRecord.fromTimerSession(
    startedAt: startedAt,
    elapsed: elapsed,
  );
  await LocalStorage.saveRecord(record);
  return record;
}

Future<BowelRecord> mergeQuestionnaireAnswers({
  required String recordId,
  required Map<String, List<int>> answers,
}) async {
  final existing = LocalStorage.getRecord(recordId);
  if (existing == null) {
    throw StateError('Record not found: $recordId');
  }
  final updated = existing.copyWith(questionnaireAnswers: answers);
  await LocalStorage.saveRecord(updated);
  return updated;
}

SessionSummaryStats computeSummaryStats({
  required List<BowelRecord> all,
  required String currentRecordId,
  required int firstDayOfWeekIndex,
  required DateTime now,
}) {
  final records = List<BowelRecord>.from(all)
    ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

  final currentIndex = records.indexWhere((record) => record.id == currentRecordId);
  final currentRecord = currentIndex == -1 ? null : records[currentIndex];

  final todayCount = records.where((record) => _isSameDay(record.dateTime, now)).length;
  final weekRange = _weekRangeForLocale(
    now: now,
    firstDayOfWeekIndex: firstDayOfWeekIndex,
  );
  final weekCount = records.where((record) {
    return !record.dateTime.isBefore(weekRange.start) &&
        !record.dateTime.isAfter(weekRange.end);
  }).length;

  var hoursSinceLastLog = 0;
  if (currentRecord != null) {
    for (var i = currentIndex + 1; i < records.length; i++) {
      final olderRecord = records[i];
      final diff = currentRecord.dateTime.difference(olderRecord.dateTime);
      if (diff.isNegative) continue;
      hoursSinceLastLog = diff.inHours;
      break;
    }
  }

  return SessionSummaryStats(
    todayCount: todayCount,
    hoursSinceLastLog: hoursSinceLastLog,
    weekCount: weekCount,
  );
}

({DateTime start, DateTime end}) _weekRangeForLocale({
  required DateTime now,
  required int firstDayOfWeekIndex,
}) {
  final startOfToday = DateTime(now.year, now.month, now.day);
  final normalizedWeekday = now.weekday % 7; // Sun=0, Mon=1 ... Sat=6
  final delta = (normalizedWeekday - firstDayOfWeekIndex + 7) % 7;
  final start = startOfToday.subtract(Duration(days: delta));
  final end = start.add(const Duration(days: 7)).subtract(const Duration(microseconds: 1));
  return (start: start, end: end);
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
