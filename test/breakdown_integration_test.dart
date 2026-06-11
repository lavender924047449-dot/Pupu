import 'package:flutter_test/flutter_test.dart';
import 'package:pupu/features/archive/status_scoring.dart';
import 'package:pupu/models/bowel_record.dart';

BowelRecord _createRecord({
  required String id,
  required DateTime dateTime,
  required Map<String, List<int>> questionnaireAnswers,
}) {
  return BowelRecord(
    id: id,
    dateTime: dateTime,
    questionnaireAnswers: questionnaireAnswers,
  );
}

void main() {
  test('Integration: Daily aggregation with multiple records', () {
    // Simulating a day with 3 records
    final baseDate = DateTime(2026, 4, 12);
    final records = [
      _createRecord(
        id: 'record-1',
        dateTime: baseDate.add(const Duration(hours: 8)),
        questionnaireAnswers: {
          'q1': [1],
          'q2': [4],
          'q3': [3],
          'q4': [5],
          'q7': [7],
          'q81': [1],
        },
      ),
      _createRecord(
        id: 'record-2',
        dateTime: baseDate.add(const Duration(hours: 14)),
        questionnaireAnswers: {
          'q1': [1],
          'q2': [2],
          'q3': [2],
          'q7': [7],
        },
      ),
      _createRecord(
        id: 'record-3',
        dateTime: baseDate.add(const Duration(hours: 20)),
        questionnaireAnswers: {
          'q1': [1],
          'q2': [3],
          'q3': [3],
          'q4': [4],
          'q7': [7],
          'q81': [1],
        },
      ),
    ];

    final daily = StatusScoring.computeIssueBreakdownDaily(records);
    expect(daily, isNotNull);
    expect(daily!.recordCount, 3);
    expect(daily.physicalPercent + daily.psychologicalPercent + daily.externalLifestylePercent,
        closeTo(100.0, 0.01));
    expect(daily.physicalPercent, greaterThan(0.0));
    expect(daily.psychologicalPercent, greaterThanOrEqualTo(0.0));
  });

  test('Integration: Weekly aggregation with sparse data', () {
    // 7 days with only 3 days having records
    final baseDate = DateTime(2026, 4, 10);
    final records = <BowelRecord>[];

    // Day 1
    records.add(_createRecord(
      id: 'week-1',
      dateTime: baseDate,
      questionnaireAnswers: {
        'q1': [1],
        'q2': [4],
        'q3': [3],
        'q4': [5],
        'q7': [1],
        'q81': [1],
      },
    ));

    // Day 3 (skip day 2)
    records.add(_createRecord(
      id: 'week-3',
      dateTime: baseDate.add(const Duration(days: 2)),
      questionnaireAnswers: {
        'q1': [1],
        'q2': [2],
        'q3': [2],
        'q7': [1],
      },
    ));

    // Day 5 (skip day 4)
    records.add(_createRecord(
      id: 'week-5',
      dateTime: baseDate.add(const Duration(days: 4)),
      questionnaireAnswers: {
        'q1': [2],
        'q2': [3],
        'q3': [3],
        'q4': [4],
        'q7': [1],
        'q81': [1],
      },
    ));

    final weekly = StatusScoring.computeIssueBreakdownWeekly(records);
    expect(weekly, isNotNull);
    expect(weekly!.daysWithRecords, 3);
    expect(weekly.hasLimitedData, false); // >= 3 days
    expect(weekly.physicalAverage + weekly.psychologicalAverage + weekly.externalLifestyleAverage,
        closeTo(100.0, 0.1));
    expect(weekly.dailyData.length, 3);
  });

  test('Integration: Monthly radar aggregation', () {
    // 30 days with 5 records spread across different days
    final baseDate = DateTime(2026, 4, 1);
    final records = <BowelRecord>[];

    for (int i = 0; i < 5; i++) {
      records.add(_createRecord(
        id: 'month-$i',
        dateTime: baseDate.add(Duration(days: i * 6)),
        questionnaireAnswers: {
          'q1': [1],
          'q2': [3 + i],
          'q3': [2],
          'q4': [4],
          'q7': [1],
          'q81': [1],
        },
      ));
    }

    final monthly = StatusScoring.computeIssueBreakdownMonthly(records);
    expect(monthly, isNotNull);
    expect(monthly!.daysWithRecords, 5);
    expect(
      monthly.physicalRadarValue + monthly.psychologicalRadarValue + monthly.externalLifestyleRadarValue,
      closeTo(100.0, 0.1),
    );
  });

  test('Integration: Time series with proper ordering', () {
    // Time series across 10 days with some days having multiple records
    final baseDate = DateTime(2026, 4, 1);
    final records = <BowelRecord>[];

    // Day 1: 2 records
    records.add(_createRecord(
      id: 'ts-1a',
      dateTime: baseDate.add(const Duration(hours: 8)),
      questionnaireAnswers: {
        'q1': [1],
        'q2': [3],
        'q3': [2],
        'q4': [4],
        'q7': [1],
        'q81': [1],
      },
    ));
    records.add(_createRecord(
      id: 'ts-1b',
      dateTime: baseDate.add(const Duration(hours: 18)),
      questionnaireAnswers: {
        'q1': [1],
        'q2': [2],
        'q3': [2],
        'q7': [1],
      },
    ));

    // Day 3
    records.add(_createRecord(
      id: 'ts-3',
      dateTime: baseDate.add(const Duration(days: 2)),
      questionnaireAnswers: {
        'q1': [1],
        'q2': [4],
        'q3': [3],
        'q4': [5],
        'q7': [1],
        'q81': [1],
      },
    ));

    // Day 6
    records.add(_createRecord(
      id: 'ts-6',
      dateTime: baseDate.add(const Duration(days: 5)),
      questionnaireAnswers: {
        'q1': [2],
        'q2': [2],
        'q3': [2],
        'q4': [3],
        'q7': [1],
      },
    ));

    final timeSeries = StatusScoring.computeIssueBreakdownTimeSeries(records);
    expect(timeSeries, isNotNull);
    expect(timeSeries!.points.length, 3); // 3 unique days
    
    // Verify ordering
    for (int i = 1; i < timeSeries.points.length; i++) {
      expect(timeSeries.points[i].$1.isAfter(timeSeries.points[i - 1].$1), true);
    }

    // Verify each point has valid percentages
    for (final point in timeSeries.points) {
      expect(point.$2.physicalPercent + point.$2.psychologicalPercent + point.$2.externalLifestylePercent,
          closeTo(100.0, 0.01));
    }
  });

  test('Integration: UI layer simulation with sample data', () {
    // Simulate what the UI layer (_computeIssuePeriodData) does
    final baseDate = DateTime(2026, 4, 10);
    final records = <BowelRecord>[];

    // Generate 10 days of sample data
    for (int day = 0; day < 7; day++) {
      final dayDate = baseDate.add(Duration(days: day));
      final recordsPerDay = day % 2 == 0 ? 2 : 1; // Some days have 2 records

      for (int rec = 0; rec < recordsPerDay; rec++) {
        records.add(_createRecord(
          id: 'ui-sample-$day-$rec',
          dateTime: dayDate.add(Duration(hours: 8 + rec * 8)),
          questionnaireAnswers: {
            'q1': [1],
            'q2': [2 + (day % 3)],
            'q3': [2],
            'q4': [3 + (day % 2)],
            'q7': [1],
            'q81': [1],
          },
        ));
      }
    }

    // Simulate UI layer behavior: compute daily aggregation for 7-day view
    final dayBuckets = <DateTime, List<BowelRecord>>{};
    for (final r in records) {
      final day = DateTime(r.dateTime.year, r.dateTime.month, r.dateTime.day);
      dayBuckets.putIfAbsent(day, () => <BowelRecord>[]).add(r);
    }

    double totalPhysical = 0.0;
    double totalPsychological = 0.0;
    double totalExternal = 0.0;
    int daysWithData = 0;

    for (final dayRecords in dayBuckets.values) {
      final daily = StatusScoring.computeIssueBreakdownDaily(dayRecords);
      if (daily != null) {
        totalPhysical += daily.physicalPercent;
        totalPsychological += daily.psychologicalPercent;
        totalExternal += daily.externalLifestylePercent;
        daysWithData++;
      }
    }

    // Compute averages
    final avgPhysical = daysWithData > 0 ? totalPhysical / daysWithData : 0.0;
    final avgPsychological = daysWithData > 0 ? totalPsychological / daysWithData : 0.0;
    final avgExternal = daysWithData > 0 ? totalExternal / daysWithData : 0.0;

    expect(daysWithData, greaterThan(0));
    expect(avgPhysical + avgPsychological + avgExternal, closeTo(100.0, 0.1));
  });
}
