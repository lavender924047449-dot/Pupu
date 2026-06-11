import 'package:flutter_test/flutter_test.dart';
import 'package:pupu/features/archive/status_scoring.dart';
import 'package:pupu/models/bowel_record.dart';

BowelRecord _record({
  required String id,
  required Map<String, List<int>> questionnaireAnswers,
}) {
  return BowelRecord(
    id: id,
    dateTime: DateTime(2026, 4, 12, 8, 30),
    questionnaireAnswers: questionnaireAnswers,
  );
}

void main() {
  test('computeIssueBreakdown scores the confirmed branches correctly', () {
    final record = _record(
      id: 'valid-1',
      questionnaireAnswers: {
        'q1': [1],
        'q2': [4],
        'q3': [3],
        'q4': [5],
        'q7': [6, 7, 11],
        'q81': [1],
        'q82': [2, 3],
        'q101': [2, 7],
        'q102': [6, 7, 11],
      },
    );

    final result = StatusScoring.computeIssueBreakdown(record);
    expect(result, isNotNull);
    expect(result!.physical, closeTo(10.0, 0.0001));
    expect(result.psychological, closeTo(4.0, 0.0001));
    expect(result.externalLifestyle, closeTo(3.5, 0.0001));
    expect(result.physicalCoefficient, closeTo(1.0, 0.0001));
  });

  test('q7 option 7 contributes to physical score', () {
    final record = _record(
      id: 'probe-q7',
      questionnaireAnswers: {
        'q1': [1],
        'q7': [7],
      },
    );

    final result = StatusScoring.computeIssueBreakdown(record);
    expect(result, isNotNull);
    expect(result!.physical, closeTo(3.0, 0.0001));
  });

  test('scoreRecord exposes tied primary and secondary labels', () {
    final record = _record(
      id: 'probe-status-tie',
      questionnaireAnswers: {
        'q1': [2],
        'q2': [4],
        'q3': [3],
        'q4': [5, 6],
        'q7': [4],
      },
    );

    final result = StatusScoring.scoreRecord(record);
    expect(result, isNotNull);
    expect(result!.primaryLabels, containsAll([
      StatusLabel.dryHard,
      StatusLabel.softUrgent,
    ]));
    expect(result.secondaryLabels, contains(StatusLabel.incompleteNotSmooth));
  });

  test('resolveDistributionLabel excludes contradictory tie', () {
    final record = _record(
      id: 'probe-status-contradictory',
      questionnaireAnswers: {
        'q1': [2],
        'q2': [4],
        'q3': [3],
        'q4': [5, 6],
        'q7': [4],
      },
    );
    final score = StatusScoring.scoreRecord(record);
    expect(score, isNotNull);
    expect(score!.includeInTrends, isFalse);
    expect(StatusScoring.resolveDistributionLabel(score), isNull);
  });

  test('resolveDistributionLabel picks highest-severity primary', () {
    final custom = const StatusScoreResult(
      scores: {
        StatusLabel.ideal: 2,
        StatusLabel.dryHard: 2,
        StatusLabel.incompleteNotSmooth: 2,
        StatusLabel.softUrgent: 2,
        StatusLabel.unsuccessful: 0,
      },
      primaryLabels: [StatusLabel.dryHard, StatusLabel.incompleteNotSmooth],
      secondaryLabels: [],
      includeInTrends: true,
    );
    expect(
      StatusScoring.resolveDistributionLabel(custom),
      StatusLabel.incompleteNotSmooth,
    );
  });

  test('computeTrendBreakdown excludes contradictory sessions', () {
    final record = _record(
      id: 'trend-contradictory',
      questionnaireAnswers: {
        'q1': [2],
        'q2': [4],
        'q3': [3],
        'q4': [5, 6],
        'q7': [4],
      },
    );
    expect(StatusScoring.computeTrendBreakdown(record), isNull);
  });

  test('q7 and q8 core items combine in one physical record', () {
    final record = _record(
      id: 'probe-combined-core',
      questionnaireAnswers: {
        'q1': [1],
        'q2': [4],
        'q3': [3],
        'q4': [5],
        'q7': [7],
        'q81': [1],
      },
    );

    final result = StatusScoring.computeIssueBreakdown(record);
    expect(result, isNotNull);
    expect(result!.physical, closeTo(8.5, 0.0001));
  });

  test('computeIssueBreakdown rejects q1=3 with q81 option 2', () {
    final record = _record(
      id: 'invalid-1',
      questionnaireAnswers: {
        'q1': [3],
        'q81': [2],
        'q82': [1],
        'q102': [1, 3],
      },
    );

    expect(StatusScoring.computeIssueBreakdown(record), isNull);
  });

  test('q82 contributes to psychological and external companion scores', () {
    final psychologicalRecord = _record(
      id: 'probe-q82-psychological',
      questionnaireAnswers: {
        'q1': [1],
        'q82': [2],
      },
    );
    final externalRecord = _record(
      id: 'probe-q82-external',
      questionnaireAnswers: {
        'q1': [1],
        'q82': [1, 3],
      },
    );

    final psychological = StatusScoring.computeIssueBreakdown(psychologicalRecord);
    final external = StatusScoring.computeIssueBreakdown(externalRecord);

    expect(psychological, isNotNull);
    expect(psychological!.psychological, closeTo(1.0, 0.0001));
    expect(external, isNotNull);
    expect(external!.externalLifestyle, closeTo(2.0, 0.0001));
  });

  test('computeIssueBreakdownDaily aggregates multiple records with weighting', () {
    final records = [
      _record(
        id: 'daily-1',
        questionnaireAnswers: {
          'q1': [1],
          'q2': [4],
          'q3': [3],
          'q4': [5],
          'q7': [7],
          'q81': [1],
        },
      ),
      _record(
        id: 'daily-2',
        questionnaireAnswers: {
          'q1': [1],
          'q2': [2],
          'q3': [2],
          'q7': [7],
        },
      ),
    ];

    final daily = StatusScoring.computeIssueBreakdownDaily(records);
    expect(daily, isNotNull);
    expect(daily!.recordCount, 2);
    expect(daily.physicalPercent + daily.psychologicalPercent + daily.externalLifestylePercent,
        closeTo(100.0, 0.0001));
  });

  test('computeIssueBreakdownWeekly calculates 7-day average', () {
    final baseDateTime = DateTime(2026, 4, 10);
    final records = <BowelRecord>[
      for (int i = 0; i < 3; i++)
        _record(
          id: 'week-$i',
          questionnaireAnswers: {
            'q1': [1],
            'q2': [4],
            'q3': [3],
            'q4': [5],
            'q7': [1],
            'q81': [1],
          },
        ).copyWith(dateTime: baseDateTime.add(Duration(days: i))),
    ];

    final weekly = StatusScoring.computeIssueBreakdownWeekly(records);
    expect(weekly, isNotNull);
    expect(weekly!.daysWithRecords, 3);
    expect(weekly.dailyData.length, 3);
    // 每天的三维度百分比总和=100，3天的平均也应该=100
    expect(weekly.physicalAverage + weekly.psychologicalAverage + weekly.externalLifestyleAverage,
        closeTo(100.0, 0.1));
  });

  test('computeIssueBreakdownWeekly flags limited data when < 3 days', () {
    final baseDateTime = DateTime(2026, 4, 10);
    final records = <BowelRecord>[
      for (int i = 0; i < 2; i++)
        _record(
          id: 'limited-$i',
          questionnaireAnswers: {
            'q1': [1],
            'q2': [4],
            'q3': [3],
            'q4': [5],
            'q7': [1],
            'q81': [1],
          },
        ).copyWith(dateTime: baseDateTime.add(Duration(days: i))),
    ];

    final weekly = StatusScoring.computeIssueBreakdownWeekly(records);
    expect(weekly, isNotNull);
    expect(weekly!.hasLimitedData, true);
  });

  test('computeIssueBreakdownMonthly calculates monthly radar values', () {
    final baseDateTime = DateTime(2026, 4, 1);
    final records = <BowelRecord>[
      for (int i = 0; i < 5; i++)
        _record(
          id: 'month-$i',
          questionnaireAnswers: {
            'q1': [1],
            'q2': [4],
            'q3': [3],
            'q4': [5],
            'q7': [1],
            'q81': [1],
          },
        ).copyWith(dateTime: baseDateTime.add(Duration(days: i * 6))),
    ];

    final monthly = StatusScoring.computeIssueBreakdownMonthly(records);
    expect(monthly, isNotNull);
    expect(monthly!.daysWithRecords, 5);
    // 30天雷达轴值总和应该=100
    expect(monthly.physicalRadarValue + monthly.psychologicalRadarValue + monthly.externalLifestyleRadarValue,
        closeTo(100.0, 0.1));
  });

  test('computeIssueBreakdownTimeSeries returns valid time series', () {
    final baseDateTime = DateTime(2026, 4, 1);
    final records = <BowelRecord>[
      for (int i = 0; i < 4; i++)
        _record(
          id: 'ts-$i',
          questionnaireAnswers: {
            'q1': [1],
            'q2': [4],
            'q3': [3],
            'q4': [5],
            'q7': [1],
            'q81': [1],
          },
        ).copyWith(dateTime: baseDateTime.add(Duration(days: i))),
    ];

    final timeSeries = StatusScoring.computeIssueBreakdownTimeSeries(records);
    expect(timeSeries, isNotNull);
    expect(timeSeries!.points.length, 4);
    
    // 验证时间序列按时间排序
    for (int i = 1; i < timeSeries.points.length; i++) {
      expect(timeSeries.points[i].$1.isAfter(timeSeries.points[i - 1].$1), true);
    }
  });
}