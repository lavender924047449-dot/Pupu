import 'package:flutter_test/flutter_test.dart';
import 'package:pupu/features/archive/chart_analysis_logic.dart';
import 'package:pupu/features/archive/status_scoring.dart';
import 'package:pupu/models/bowel_record.dart';

BowelRecord _record({
  required String id,
  required DateTime dateTime,
  Map<String, List<int>>? answers,
}) {
  return BowelRecord(
    id: id,
    dateTime: dateTime,
    questionnaireAnswers: answers,
  );
}

void main() {
  test('formatDistributionPercents keeps integer sum at 100', () {
    final values = formatDistributionPercents(const [
      0.204,
      0.204,
      0.204,
      0.204,
      0.184,
    ]);
    expect(values.fold<int>(0, (sum, value) => sum + value), 100);
  });

  test('formatDistributionPercents returns zeros when all ratios are zero', () {
    final values = formatDistributionPercents(const [0.0, 0.0, 0.0, 0.0, 0.0]);
    expect(values, [0, 0, 0, 0, 0]);
  });

  test('resolveChartWindow anchors to today and clamps offset', () {
    final now = DateTime(2026, 6, 12, 10, 0);
    final records = [
      _record(id: '1', dateTime: DateTime(2026, 5, 12)),
    ];
    final window = resolveChartWindow(
      records: records,
      days: 7,
      offsetDays: 999,
      now: now,
    );
    // Picker range starts 2025-01-01; offset 999 clamps to aligned max block.
    expect(window.offsetDays, greaterThan(0));
    expect(window.end.isBefore(now), isTrue);
    expect(window.canGoNewer, isTrue);
  });

  test('maxChartOffsetDays spans picker min date to today', () {
    final now = DateTime(2026, 6, 12, 10, 0);
    final maxOffset = maxChartOffsetDays(days: 7, now: now);
    expect(maxOffset % 7, 0);
    expect(maxOffset, greaterThan(0));
  });

  test('offsetForSelectedDate sets window end to selected day', () {
    final now = DateTime(2026, 6, 12, 10, 0);
    expect(
      offsetForSelectedDate(
        selectedDate: DateTime(2026, 6, 12),
        now: now,
      ),
      0,
    );
    expect(
      offsetForSelectedDate(
        selectedDate: DateTime(2026, 6, 5),
        now: now,
      ),
      7,
    );
    expect(
      offsetForSelectedDate(
        selectedDate: DateTime(2026, 6, 4),
        now: now,
      ),
      8,
    );
    expect(
      offsetForSelectedDate(
        selectedDate: DateTime(2026, 6, 13),
        now: now,
      ),
      0,
    );
    expect(
      offsetForSelectedDate(
        selectedDate: DateTime(2026, 5, 12),
        now: now,
      ),
      31,
    );
  });

  test('logDaysFromRecords normalizes and deduplicates days', () {
    final records = [
      _record(id: 'a', dateTime: DateTime(2026, 6, 10, 8)),
      _record(id: 'b', dateTime: DateTime(2026, 6, 10, 20)),
      _record(id: 'c', dateTime: DateTime(2026, 6, 11)),
    ];
    final days = logDaysFromRecords(records);
    expect(days.length, 2);
    expect(days.contains(DateTime(2026, 6, 10)), isTrue);
    expect(days.contains(DateTime(2026, 6, 11)), isTrue);
  });

  test('resolveChartPickerDayStyle applies log, today, and selection rules', () {
    final today = DateTime(2026, 6, 12);
    final logDays = {DateTime(2026, 6, 10), DateTime(2026, 6, 12)};

    final plain = resolveChartPickerDayStyle(
      day: DateTime(2026, 6, 1),
      today: today,
      selected: today,
      logDays: logDays,
    );
    expect(plain.showLogBackground, isFalse);
    expect(plain.useTodayTextColor, isFalse);
    expect(plain.showSelectionRing, isFalse);

    final logDay = resolveChartPickerDayStyle(
      day: DateTime(2026, 6, 10),
      today: today,
      selected: today,
      logDays: logDays,
    );
    expect(logDay.showLogBackground, isTrue);
    expect(logDay.useTodayTextColor, isFalse);
    expect(logDay.showSelectionRing, isFalse);

    final todayStyle = resolveChartPickerDayStyle(
      day: today,
      today: today,
      selected: DateTime(2026, 6, 5),
      logDays: logDays,
    );
    expect(todayStyle.showLogBackground, isFalse);
    expect(todayStyle.useTodayTextColor, isTrue);
    expect(todayStyle.showSelectionRing, isFalse);

    final selectedLogDay = resolveChartPickerDayStyle(
      day: DateTime(2026, 6, 10),
      today: today,
      selected: DateTime(2026, 6, 10),
      logDays: logDays,
    );
    expect(selectedLogDay.showLogBackground, isTrue);
    expect(selectedLogDay.useTodayTextColor, isFalse);
    expect(selectedLogDay.showSelectionRing, isTrue);

    final todaySelected = resolveChartPickerDayStyle(
      day: today,
      today: today,
      selected: today,
      logDays: logDays,
    );
    expect(todaySelected.showLogBackground, isFalse);
    expect(todaySelected.useTodayTextColor, isTrue);
    expect(todaySelected.showSelectionRing, isTrue);
  });

  test('computeStatusDistributionSession counts by single resolved label', () {
    final now = DateTime(2026, 6, 12, 10, 0);
    final records = [
      _record(
        id: 'ideal',
        dateTime: DateTime(2026, 6, 10),
        answers: {
          'q1': [1],
          'q2': [1],
          'q3': [1],
          'q4': [1],
          'q7': [1],
          'q52': [1],
        },
      ),
      _record(
        id: 'conflict',
        dateTime: DateTime(2026, 6, 10),
        answers: {
          'q1': [2],
          'q2': [4],
          'q3': [3],
          'q4': [5, 6],
          'q7': [4],
        },
      ),
      _record(
        id: 'unsuccessful',
        dateTime: DateTime(2026, 6, 11),
        answers: {
          'q1': [3],
        },
      ),
    ];

    final map = computeStatusDistributionSession(
      records: records,
      days: 7,
      offsetDays: 0,
      now: now,
    );
    expect(map[StatusLabel.ideal], 1);
    expect(map[StatusLabel.unsuccessful], 1);
    expect(map[StatusLabel.dryHard], 0);
    expect(map[StatusLabel.softUrgent], 0);
  });

  test('computeTrendSeries filters contradictory record', () {
    final now = DateTime(2026, 6, 12);
    final records = [
      _record(
        id: 'ok',
        dateTime: DateTime(2026, 6, 11),
        answers: {
          'q1': [1],
          'q2': [1],
          'q3': [1],
          'q4': [1],
          'q7': [1],
        },
      ),
      _record(
        id: 'bad',
        dateTime: DateTime(2026, 6, 11, 1),
        answers: {
          'q1': [2],
          'q2': [4],
          'q3': [3],
          'q4': [5, 6],
          'q7': [4],
        },
      ),
    ];
    final trend = computeTrendSeries(
      records: records,
      days: 7,
      offsetDays: 0,
      now: now,
    );
    expect(trend.points.length, 1);
    expect(trend.points.first.label, 'Jun 11');
  });

  test('computeChartIssuePeriodData uses weighted-window radar', () {
    final now = DateTime(2026, 6, 12);
    final records = [
      _record(
        id: 'a',
        dateTime: DateTime(2026, 6, 11),
        answers: {
          'q1': [1],
          'q2': [4],
          'q3': [3],
          'q4': [5],
          'q7': [7],
          'q81': [1],
        },
      ),
      _record(
        id: 'b',
        dateTime: DateTime(2026, 6, 10),
        answers: {
          'q1': [1],
          'q2': [2],
          'q3': [2],
          'q7': [7],
        },
      ),
    ];
    final data = computeChartIssuePeriodData(
      records: records,
      days: 7,
      offsetDays: 0,
      now: now,
    );
    final total = data.physicalAveragePercent +
        data.psychologicalAveragePercent +
        data.externalAveragePercent;
    expect(total, closeTo(100.0, 0.0001));
    expect(data.validRecords, 2);
    expect(data.daysWithRecords, 2);
    expect(data.hasLimitedData, true);
  });
}
