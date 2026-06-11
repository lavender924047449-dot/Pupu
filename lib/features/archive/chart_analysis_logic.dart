import 'dart:math' as math;

import 'package:intl/intl.dart' show DateFormat;
import 'package:pupu/features/archive/logs_day_utils.dart';
import 'package:pupu/features/archive/status_scoring.dart';
import 'package:pupu/models/bowel_record.dart';

class ChartDateWindow {
  final int days;
  final int offsetDays;
  final DateTime start;
  final DateTime end;
  final String title;
  final bool canGoOlder;
  final bool canGoNewer;

  const ChartDateWindow({
    required this.days,
    required this.offsetDays,
    required this.start,
    required this.end,
    required this.title,
    required this.canGoOlder,
    required this.canGoNewer,
  });
}

class ChartTrendPoint {
  final int dayIndex;
  final String label;
  final double score;
  final TrendScoreBreakdown breakdown;

  const ChartTrendPoint({
    required this.dayIndex,
    required this.label,
    required this.score,
    required this.breakdown,
  });
}

class ChartTrendSeries {
  final List<ChartTrendPoint> points;
  final List<String> labels;
  final int totalDays;

  const ChartTrendSeries({
    required this.points,
    required this.labels,
    required this.totalDays,
  });
}

class ChartIssuePercentPoint {
  final String label;
  final double physicalPercent;
  final double psychologicalPercent;
  final double externalPercent;
  final bool hasData;

  const ChartIssuePercentPoint({
    required this.label,
    required this.physicalPercent,
    required this.psychologicalPercent,
    required this.externalPercent,
    required this.hasData,
  });
}

class ChartIssuePeriodData {
  final int days;
  final int validRecords;
  final int daysWithRecords;
  final List<ChartIssuePercentPoint> points;
  final double physicalAveragePercent;
  final double psychologicalAveragePercent;
  final double externalAveragePercent;

  const ChartIssuePeriodData({
    required this.days,
    required this.validRecords,
    required this.daysWithRecords,
    required this.points,
    required this.physicalAveragePercent,
    required this.psychologicalAveragePercent,
    required this.externalAveragePercent,
  });

  /// Fewer than 3 days with questionnaire data in the selected window.
  bool get hasLimitedData => daysWithRecords < 3;
}

DateTime chartToday({DateTime? now}) => normalizeDay(now ?? DateTime.now());

DateTime chartWindowEnd({
  required int offsetDays,
  DateTime? now,
}) {
  return chartToday(now: now).subtract(Duration(days: offsetDays));
}

DateTime chartWindowStart({
  required DateTime end,
  required int days,
}) {
  return end.subtract(Duration(days: days - 1));
}

DateTime earliestRecordDay(List<BowelRecord> records, {DateTime? now}) {
  if (records.isEmpty) return chartToday(now: now);
  return records
      .map((r) => normalizeDay(r.dateTime))
      .reduce((a, b) => a.isBefore(b) ? a : b);
}

int maxChartOffsetDays({
  required List<BowelRecord> records,
  required int days,
  DateTime? now,
}) {
  final today = chartToday(now: now);
  final earliest = earliestRecordDay(records, now: now);
  final spanDays = today.difference(earliest).inDays;
  if (spanDays <= 0) return 0;
  return (spanDays ~/ days) * days;
}

ChartDateWindow resolveChartWindow({
  required List<BowelRecord> records,
  required int days,
  required int offsetDays,
  DateTime? now,
}) {
  final maxOffset = maxChartOffsetDays(records: records, days: days, now: now);
  final safeOffset = offsetDays.clamp(0, maxOffset);
  final end = chartWindowEnd(offsetDays: safeOffset, now: now);
  final start = chartWindowStart(end: end, days: days);
  return ChartDateWindow(
    days: days,
    offsetDays: safeOffset,
    start: start,
    end: end,
    title:
        '${DateFormat('MMM d').format(start)} - ${DateFormat('MMM d, yyyy').format(end)}',
    canGoOlder: safeOffset < maxOffset,
    canGoNewer: safeOffset > 0,
  );
}

Map<StatusLabel, int> computeStatusDistributionSession({
  required List<BowelRecord> records,
  required int days,
  required int offsetDays,
  DateTime? now,
}) {
  final window = resolveChartWindow(
    records: records,
    days: days,
    offsetDays: offsetDays,
    now: now,
  );
  final distribution = <StatusLabel, int>{
    StatusLabel.ideal: 0,
    StatusLabel.dryHard: 0,
    StatusLabel.incompleteNotSmooth: 0,
    StatusLabel.softUrgent: 0,
    StatusLabel.unsuccessful: 0,
  };
  for (final record in records) {
    final day = normalizeDay(record.dateTime);
    if (day.isBefore(window.start) || day.isAfter(window.end)) continue;
    final score = StatusScoring.scoreRecord(record);
    final label = StatusScoring.resolveDistributionLabel(score);
    if (label == null) continue;
    distribution[label] = (distribution[label] ?? 0) + 1;
  }
  return distribution;
}

List<int> formatDistributionPercents(
  List<double> ratios,
) {
  if (ratios.isEmpty) return const [];
  final raw = ratios.map((r) => (r.clamp(0.0, 1.0) * 100)).toList();
  final floored = raw.map((v) => v.floor()).toList();
  final totalFloor = floored.fold<int>(0, (sum, value) => sum + value);
  var remain = math.max(0, 100 - totalFloor);
  final indexedRemainders = List.generate(raw.length, (i) {
    return (idx: i, rem: raw[i] - floored[i]);
  })
    ..sort((a, b) {
      final cmp = b.rem.compareTo(a.rem);
      if (cmp != 0) return cmp;
      return a.idx.compareTo(b.idx);
    });
  for (final item in indexedRemainders) {
    if (remain <= 0) break;
    floored[item.idx] += 1;
    remain -= 1;
  }
  return floored;
}

List<String> buildTrendDateLabels(DateTime anchorDate, int days) {
  final anchor = normalizeDay(anchorDate);
  final start = anchor.subtract(Duration(days: days - 1));
  return List<String>.generate(days, (i) {
    final d = start.add(Duration(days: i));
    return DateFormat('MMM d').format(d);
  });
}

ChartTrendSeries computeTrendSeries({
  required List<BowelRecord> records,
  required int days,
  required int offsetDays,
  DateTime? now,
}) {
  final window = resolveChartWindow(
    records: records,
    days: days,
    offsetDays: offsetDays,
    now: now,
  );
  final labels = buildTrendDateLabels(window.end, days);

  final dayBuckets = <DateTime, List<BowelRecord>>{};
  for (final r in records) {
    final day = normalizeDay(r.dateTime);
    if (day.isBefore(window.start) || day.isAfter(window.end)) continue;
    dayBuckets.putIfAbsent(day, () => <BowelRecord>[]).add(r);
  }

  final series = <ChartTrendPoint>[];
  for (int i = 0; i < days; i++) {
    final day = window.start.add(Duration(days: i));
    final list = dayBuckets[day] ?? const <BowelRecord>[];
    var totalSum = 0.0;
    var valid = 0;
    var resultSum = 0.0;
    var strainingSum = 0.0;
    var evacuationSum = 0.0;
    var consistencySum = 0.0;
    var painSum = 0.0;

    for (final record in list) {
      final b = StatusScoring.computeTrendBreakdown(record);
      if (b == null) continue;
      valid++;
      totalSum += b.total;
      resultSum += b.resultWeighted;
      strainingSum += b.strainingWeighted;
      evacuationSum += b.evacuationWeighted;
      consistencySum += b.consistencyWeighted;
      painSum += b.painDiscomfortWeighted;
    }

    if (valid == 0) continue;
    final avg = TrendScoreBreakdown(
      total: totalSum / valid,
      resultWeighted: resultSum / valid,
      strainingWeighted: strainingSum / valid,
      evacuationWeighted: evacuationSum / valid,
      consistencyWeighted: consistencySum / valid,
      painDiscomfortWeighted: painSum / valid,
    );
    series.add(
      ChartTrendPoint(
        dayIndex: i,
        label: labels[i],
        score: avg.total,
        breakdown: avg,
      ),
    );
  }

  return ChartTrendSeries(points: series, labels: labels, totalDays: days);
}

ChartIssuePeriodData computeChartIssuePeriodData({
  required List<BowelRecord> records,
  required int days,
  required int offsetDays,
  DateTime? now,
}) {
  final window = resolveChartWindow(
    records: records,
    days: days,
    offsetDays: offsetDays,
    now: now,
  );
  final labels = buildTrendDateLabels(window.end, days);
  final windowRecords = records.where((record) {
    final day = normalizeDay(record.dateTime);
    return !day.isBefore(window.start) && !day.isAfter(window.end);
  }).toList();

  final dailyByDate = <DateTime, IssueBreakdownDaily>{};
  var effectiveRecordCount = 0;
  final groupedByDate = <DateTime, List<BowelRecord>>{};
  for (final record in windowRecords) {
    final day = normalizeDay(record.dateTime);
    groupedByDate.putIfAbsent(day, () => <BowelRecord>[]).add(record);
  }
  for (final entry in groupedByDate.entries) {
    final daily = StatusScoring.computeIssueBreakdownDaily(entry.value);
    if (daily == null) continue;
    dailyByDate[entry.key] = daily;
    effectiveRecordCount += daily.recordCount;
  }

  // 方案 A：雷达轴值按窗口内所有有效记录做一次加权聚合，而非“按天均值”。
  final windowWeighted = StatusScoring.computeIssueBreakdownDaily(windowRecords);
  final physicalAvg = windowWeighted?.physicalPercent ?? 0.0;
  final psychologicalAvg = windowWeighted?.psychologicalPercent ?? 0.0;
  final externalAvg = windowWeighted?.externalLifestylePercent ?? 0.0;

  final points = <ChartIssuePercentPoint>[];
  for (int i = 0; i < days; i++) {
    final day = window.start.add(Duration(days: i));
    final daily = dailyByDate[day];
    points.add(
      ChartIssuePercentPoint(
        label: labels[i],
        physicalPercent: daily?.physicalPercent ?? 0.0,
        psychologicalPercent: daily?.psychologicalPercent ?? 0.0,
        externalPercent: daily?.externalLifestylePercent ?? 0.0,
        hasData: daily != null,
      ),
    );
  }

  return ChartIssuePeriodData(
    days: days,
    validRecords: effectiveRecordCount,
    daysWithRecords: dailyByDate.length,
    points: points,
    physicalAveragePercent: physicalAvg,
    psychologicalAveragePercent: psychologicalAvg,
    externalAveragePercent: externalAvg,
  );
}
