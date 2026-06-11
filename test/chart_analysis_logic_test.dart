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
    expect(window.end, DateTime(2026, 5, 15));
    expect(window.start, DateTime(2026, 5, 9));
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
