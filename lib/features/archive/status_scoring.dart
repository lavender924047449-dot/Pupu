import 'dart:math' as math;

import 'package:pupu/models/bowel_record.dart';

enum StatusLabel {
  ideal,
  dryHard,
  incompleteNotSmooth,
  softUrgent,
  unsuccessful
}

class StatusScoreResult {
  final Map<StatusLabel, int> scores;
  final List<StatusLabel> primaryLabels;
  final List<StatusLabel> secondaryLabels;
  final bool includeInTrends;

  const StatusScoreResult({
    required this.scores,
    required this.primaryLabels,
    required this.secondaryLabels,
    required this.includeInTrends,
  });
}

class TrendScoreBreakdown {
  final double total;
  final double resultWeighted;
  final double strainingWeighted;
  final double evacuationWeighted;
  final double consistencyWeighted;
  final double painDiscomfortWeighted;

  const TrendScoreBreakdown({
    required this.total,
    required this.resultWeighted,
    required this.strainingWeighted,
    required this.evacuationWeighted,
    required this.consistencyWeighted,
    required this.painDiscomfortWeighted,
  });
}

class IssueBreakdownResult {
  final double physical;
  final double psychological;
  final double externalLifestyle;
  final double physicalCoefficient;

  const IssueBreakdownResult({
    required this.physical,
    required this.psychological,
    required this.externalLifestyle,
    required this.physicalCoefficient,
  });
}

/// 单天的加权聚合结果（支持多次记录）
class IssueBreakdownDaily {
  /// 当天所有有效记录数
  final int recordCount;

  /// 生理维度的原始加权分（未归一化）
  final double physicalWeighted;

  /// 心理维度的原始加权分（未归一化）
  final double psychologicalWeighted;

  /// 外在维度的原始加权分（未归一化）
  final double externalLifestyleWeighted;

  /// 三维度归一化百分比（总和=100）
  final double physicalPercent;
  final double psychologicalPercent;
  final double externalLifestylePercent;

  const IssueBreakdownDaily({
    required this.recordCount,
    required this.physicalWeighted,
    required this.psychologicalWeighted,
    required this.externalLifestyleWeighted,
    required this.physicalPercent,
    required this.psychologicalPercent,
    required this.externalLifestylePercent,
  });
}

/// 7天数据（用于周视图，每天一条数据）
class IssueBreakdownWeekly {
  /// 有记录的天数（< 3天时应显示"数据有限"提示）
  final int daysWithRecords;

  /// 每天的维度百分比数据（按日期排序）
  /// List<(DateTime, IssueBreakdownDaily)>
  final List<(DateTime, IssueBreakdownDaily)> dailyData;

  /// 7天的平均值（仅计算有记录的天）
  final double physicalAverage;
  final double psychologicalAverage;
  final double externalLifestyleAverage;

  const IssueBreakdownWeekly({
    required this.daysWithRecords,
    required this.dailyData,
    required this.physicalAverage,
    required this.psychologicalAverage,
    required this.externalLifestyleAverage,
  });

  bool get hasLimitedData => daysWithRecords < 3;
}

/// 30天数据（用于月雷达图）
class IssueBreakdownMonthly {
  /// 有记录的天数
  final int daysWithRecords;

  /// 每天的维度百分比数据
  final List<(DateTime, IssueBreakdownDaily)> dailyData;

  /// 30天雷达轴值：Σ(所有有记录天的维度%) / 有记录天数
  final double physicalRadarValue;
  final double psychologicalRadarValue;
  final double externalLifestyleRadarValue;

  const IssueBreakdownMonthly({
    required this.daysWithRecords,
    required this.dailyData,
    required this.physicalRadarValue,
    required this.psychologicalRadarValue,
    required this.externalLifestyleRadarValue,
  });
}

/// 时间序列数据（用于折线图）
class IssueBreakdownTimeSeries {
  /// 按日期排序的数据点
  /// 无记录的天不包含在列表中
  final List<(DateTime, IssueBreakdownDaily)> points;

  const IssueBreakdownTimeSeries({
    required this.points,
  });
}

class StatusScoring {
  /// Distribution 的单条记录归类（session 口径）：
  /// - `null`：无问卷 / 无主标签 / 矛盾标签（`includeInTrends=false`）→ 整条跳过
  /// - 非 `null`：返回单一主标签（并列时取最高严重度）
  static StatusLabel? resolveDistributionLabel(StatusScoreResult? score) {
    if (score == null) return null;
    if (!score.includeInTrends) return null;
    if (score.primaryLabels.isEmpty) return null;
    var chosen = score.primaryLabels.first;
    for (final label in score.primaryLabels.skip(1)) {
      if (_statusOrder(label) > _statusOrder(chosen)) {
        chosen = label;
      }
    }
    return chosen;
  }

  static int _statusOrder(StatusLabel label) {
    switch (label) {
      case StatusLabel.ideal:
        return 0;
      case StatusLabel.dryHard:
        return 1;
      case StatusLabel.incompleteNotSmooth:
        return 2;
      case StatusLabel.softUrgent:
        return 3;
      case StatusLabel.unsuccessful:
        return 4;
    }
  }

  static StatusScoreResult? scoreRecord(BowelRecord record) {
    final answers = record.questionnaireAnswers;
    if (answers == null || answers.isEmpty) return null;

    final q1 = answers['q1'] ?? const <int>[];
    final q2 = answers['q2'] ?? const <int>[];
    final q3 = answers['q3'] ?? const <int>[];
    final q4 = answers['q4'] ?? const <int>[];
    final q52 = answers['q52'] ?? const <int>[];
    final q7 = answers['q7'] ?? const <int>[];

    final scores = <StatusLabel, int>{
      StatusLabel.ideal: 0,
      StatusLabel.dryHard: 0,
      StatusLabel.incompleteNotSmooth: 0,
      StatusLabel.softUrgent: 0,
      StatusLabel.unsuccessful: 0,
    };

    if (q1.contains(3)) {
      scores[StatusLabel.unsuccessful] = 1;
      return const StatusScoreResult(
        scores: {
          StatusLabel.ideal: 0,
          StatusLabel.dryHard: 0,
          StatusLabel.incompleteNotSmooth: 0,
          StatusLabel.softUrgent: 0,
          StatusLabel.unsuccessful: 1,
        },
        primaryLabels: [StatusLabel.unsuccessful],
        secondaryLabels: [],
        includeInTrends: true,
      );
    }

    // A: Ideal
    if (q1.contains(1)) {
      scores[StatusLabel.ideal] = scores[StatusLabel.ideal]! + 2;
    }
    if (q2.contains(1)) {
      scores[StatusLabel.ideal] = scores[StatusLabel.ideal]! + 2;
    }
    if (q3.contains(1)) {
      scores[StatusLabel.ideal] = scores[StatusLabel.ideal]! + 2;
    }
    if (q4.contains(1)) {
      scores[StatusLabel.ideal] = scores[StatusLabel.ideal]! + 2;
    }
    if (q7.contains(1)) {
      scores[StatusLabel.ideal] = scores[StatusLabel.ideal]! + 2;
    }
    if (q52.contains(1)) {
      scores[StatusLabel.ideal] = scores[StatusLabel.ideal]! + 1;
    }

    // B: Dry / Hard
    if (q2.contains(3) || q2.contains(4)) {
      scores[StatusLabel.dryHard] = scores[StatusLabel.dryHard]! + 2;
    }
    if (q4.contains(4) || q4.contains(5)) {
      scores[StatusLabel.dryHard] = scores[StatusLabel.dryHard]! + 2;
    }
    if (q2.contains(2)) {
      scores[StatusLabel.dryHard] = scores[StatusLabel.dryHard]! + 1;
    }
    if (q4.contains(2)) {
      scores[StatusLabel.dryHard] = scores[StatusLabel.dryHard]! + 1;
    }
    if (q7.contains(9)) {
      scores[StatusLabel.dryHard] = scores[StatusLabel.dryHard]! + 1;
    }
    if (q7.contains(10)) {
      scores[StatusLabel.dryHard] = scores[StatusLabel.dryHard]! + 1;
    }

    // C: Incomplete / Not Smooth
    if (q3.contains(3)) {
      scores[StatusLabel.incompleteNotSmooth] =
          scores[StatusLabel.incompleteNotSmooth]! + 2;
    }
    if (q7.contains(7)) {
      scores[StatusLabel.incompleteNotSmooth] =
          scores[StatusLabel.incompleteNotSmooth]! + 2;
    }
    if (q7.contains(8)) {
      scores[StatusLabel.incompleteNotSmooth] =
          scores[StatusLabel.incompleteNotSmooth]! + 2;
    }
    if (q7.contains(10)) {
      scores[StatusLabel.incompleteNotSmooth] =
          scores[StatusLabel.incompleteNotSmooth]! + 2;
    }
    if (q3.contains(2)) {
      scores[StatusLabel.incompleteNotSmooth] =
          scores[StatusLabel.incompleteNotSmooth]! + 1;
    }
    if (q1.contains(2)) {
      scores[StatusLabel.incompleteNotSmooth] =
          scores[StatusLabel.incompleteNotSmooth]! + 1;
    }

    // D: Soft / Urgent
    if (q4.contains(6)) {
      scores[StatusLabel.softUrgent] = scores[StatusLabel.softUrgent]! + 2;
    }
    if (q7.contains(4)) {
      scores[StatusLabel.softUrgent] = scores[StatusLabel.softUrgent]! + 2;
    }
    if (q7.contains(5)) {
      scores[StatusLabel.softUrgent] = scores[StatusLabel.softUrgent]! + 2;
    }
    if (q4.contains(3)) {
      scores[StatusLabel.softUrgent] = scores[StatusLabel.softUrgent]! + 1;
    }

    // A 否决：Q2/Q3/Q4 不是 1，或 Q7 不是仅 1
    final q2IsOne = q2.length == 1 && q2.first == 1;
    final q3IsOne = q3.length == 1 && q3.first == 1;
    final q4IsOne = q4.length == 1 && q4.first == 1;
    final q7IsOneOnly = q7.length == 1 && q7.first == 1;
    if (!q2IsOne || !q3IsOne || !q4IsOne || !q7IsOneOnly) {
      scores[StatusLabel.ideal] = 0;
    }

    final maxScore = scores.entries
        .where((e) => e.key != StatusLabel.unsuccessful)
        .map((e) => e.value)
        .fold<int>(0, (max, v) => v > max ? v : max);

    final primary = <StatusLabel>[];
    if (maxScore > 0) {
      for (final entry in scores.entries) {
        if (entry.key == StatusLabel.unsuccessful) continue;
        if (entry.value == maxScore) primary.add(entry.key);
      }
    }

    final secondaryMaxScore = scores.entries
        .where((e) =>
            e.key != StatusLabel.unsuccessful &&
            !primary.contains(e.key) &&
            e.value > 0)
        .map((e) => e.value)
        .fold<int>(0, (max, v) => v > max ? v : max);

    final secondary = <StatusLabel>[];
    if (secondaryMaxScore > 0) {
      for (final entry in scores.entries) {
        if (entry.key == StatusLabel.unsuccessful) continue;
        if (primary.contains(entry.key)) continue;
        if (entry.value == secondaryMaxScore) secondary.add(entry.key);
      }
    }

    final includeInTrends = !((scores[StatusLabel.dryHard] ?? 0) >= 3 &&
        (scores[StatusLabel.softUrgent] ?? 0) >= 3);

    return StatusScoreResult(
      scores: scores,
      primaryLabels: primary,
      secondaryLabels: secondary,
      includeInTrends: includeInTrends,
    );
  }

  static TrendScoreBreakdown? computeTrendBreakdown(BowelRecord record) {
    final score = scoreRecord(record);
    if (score == null || !score.includeInTrends) return null;
    final answers = record.questionnaireAnswers!;

    final q1 = answers['q1'] ?? const <int>[];
    final q2 = answers['q2'] ?? const <int>[];
    final q3 = answers['q3'] ?? const <int>[];
    final q4 = answers['q4'] ?? const <int>[];
    final q7 = answers['q7'] ?? const <int>[];

    if (q1.isEmpty || q2.isEmpty || q3.isEmpty || q4.isEmpty) {
      return null;
    }
    if (q1.contains(3)) {
      return null;
    }

    final q1Score = _q1Score(q1.first);
    final q2Score = _q2Score(q2.first);
    final q3Score = _q3Score(q3.first);
    final q4Score = _q4Score(q4.first);
    final q7Penalty = _q7Penalty(q7);

    final resultWeighted = q1Score * 0.20;
    final strainingWeighted = q2Score * 0.15;
    final evacuationWeighted = q3Score * 0.20;
    final consistencyWeighted = q4Score * 0.20;
    final painDiscomfortWeighted = (100 - q7Penalty) * 0.25;

    return TrendScoreBreakdown(
      total: resultWeighted +
          strainingWeighted +
          evacuationWeighted +
          consistencyWeighted +
          painDiscomfortWeighted,
      resultWeighted: resultWeighted,
      strainingWeighted: strainingWeighted,
      evacuationWeighted: evacuationWeighted,
      consistencyWeighted: consistencyWeighted,
      painDiscomfortWeighted: painDiscomfortWeighted,
    );
  }

  static double? computeTrendScore(BowelRecord record) {
    return computeTrendBreakdown(record)?.total;
  }

  static IssueBreakdownResult? computeIssueBreakdown(BowelRecord record) {
    final answers = record.questionnaireAnswers;
    if (answers == null || answers.isEmpty) return null;

    final q1 = _singleAnswer(answers, ['q1']);
    final q81 = _singleAnswer(answers, ['q81']);
    if (q1 == null) return null;

    if (q1 == 3 && q81 == 2) {
      return null;
    }

    final physicalCore = <double>[];
    final physicalCompanion = <double>[];
    final psychologicalCore = <double>[];
    final psychologicalCompanion = <double>[];
    final externalCore = <double>[];
    final externalCompanion = <double>[];

    _collectSingleSelectScore(
      answers,
      ['q2'],
      {2: 1, 3: 2, 4: 3},
      physicalCore,
    );
    _collectSingleSelectScore(
      answers,
      ['q3'],
      {2: 1, 3: 2},
      physicalCore,
    );
    _collectSingleSelectScore(
      answers,
      ['q4'],
      {2: 1, 3: 0.5, 4: 2, 5: 3, 6: 2},
      physicalCore,
    );
    _collectSingleSelectScore(
      answers,
      ['q81'],
      {1: 3},
      physicalCore,
    );
    _collectSelectedScores(
      answers,
      ['q7', 'q9'],
      {7: 3},
      physicalCore,
    );

    _collectSelectedScores(
      answers,
      ['q7', 'q9'],
      {2: 2, 3: 2, 4: 2, 5: 3, 8: 1, 9: 2, 10: 3},
      physicalCompanion,
    );
    _collectSelectedScores(
      answers,
      ['q101'],
      {2: 1, 7: 1},
      physicalCompanion,
    );
    _collectSelectedScores(
      answers,
      ['q102'],
      {6: 1},
      physicalCompanion,
    );

    _collectSelectedScores(
      answers,
      ['q7', 'q9'],
      {6: 2},
      psychologicalCore,
    );
    _collectSelectedScores(
      answers,
      ['q81'],
      {3: 2},
      psychologicalCore,
    );
    _collectSelectedScores(
      answers,
      ['q82'],
      {2: 2},
      psychologicalCompanion,
    );
    _collectSelectedScores(
      answers,
      ['q102'],
      {7: 2},
      psychologicalCompanion,
    );

    _collectSelectedScores(
      answers,
      ['q81'],
      {4: 3, 5: 3, 6: 3},
      externalCore,
    );
    _collectSelectedScores(
      answers,
      ['q7', 'q9'],
      {11: 2},
      externalCompanion,
    );
    _collectSelectedScores(
      answers,
      ['q82'],
      {1: 2, 3: 2},
      externalCompanion,
    );
    _collectSelectedScores(
      answers,
      ['q102'],
      {1: 1, 2: 1, 3: 1, 4: 1, 5: 1, 8: 1, 9: 1, 10: 1, 11: 3, 12: 1},
      externalCompanion,
    );

    final physical = _dimensionScore(
      coreScores: physicalCore,
      companionScores: physicalCompanion,
      cap: 15,
      coefficient: _physicalCoefficient(q1: q1, q81: q81),
    );
    final psychological = _dimensionScore(
      coreScores: psychologicalCore,
      companionScores: psychologicalCompanion,
      cap: 10,
    );
    final externalLifestyle = _dimensionScore(
      coreScores: externalCore,
      companionScores: externalCompanion,
      cap: 10,
    );

    return IssueBreakdownResult(
      physical: physical,
      psychological: psychological,
      externalLifestyle: externalLifestyle,
      physicalCoefficient: _physicalCoefficient(q1: q1, q81: q81),
    );
  }

  /// 计算单天的加权聚合结果
  /// 支持当日多次记录，基于公式：
  /// W_i = max(Max_Core_Physical_i, 1)
  /// 当日_维度_加权分 = Σ(维度_分_i × W_i) / Σ(W_i)
  /// 当日维度百分比 = 加权分 / Σ(三维度加权分) × 100%
  static IssueBreakdownDaily? computeIssueBreakdownDaily(
    Iterable<BowelRecord> recordsForDay,
  ) {
    final records = recordsForDay.toList();
    if (records.isEmpty) return null;

    final breakdowns = <IssueBreakdownResult>[];
    final weights = <double>[];

    // 第一步：计算每条记录的分值和权重
    for (final record in records) {
      final result = computeIssueBreakdown(record);
      if (result == null) continue;

      breakdowns.add(result);

      // 计算该条记录的权重 W_i = max(Max_Core_Physical_i, 1)
      final maxCorePhysical = _calculateMaxCoreScore(record);
      final weight = math.max(maxCorePhysical, 1.0);
      weights.add(weight);
    }

    if (breakdowns.isEmpty) return null;

    // 第二步：计算加权分
    double physicalSum = 0.0;
    double psychologicalSum = 0.0;
    double externalSum = 0.0;
    double weightSum = 0.0;

    for (int i = 0; i < breakdowns.length; i++) {
      final w = weights[i];
      final b = breakdowns[i];
      physicalSum += b.physical * w;
      psychologicalSum += b.psychological * w;
      externalSum += b.externalLifestyle * w;
      weightSum += w;
    }

    final physicalWeighted = physicalSum / weightSum;
    final psychologicalWeighted = psychologicalSum / weightSum;
    final externalWeighted = externalSum / weightSum;

    // 第三步：计算百分比（归一化）
    final totalWeighted =
        physicalWeighted + psychologicalWeighted + externalWeighted;
    final physicalPercent = totalWeighted == 0 ? 0.0 : (physicalWeighted / totalWeighted) * 100;
    final psychologicalPercent =
        totalWeighted == 0 ? 0.0 : (psychologicalWeighted / totalWeighted) * 100;
    final externalPercent =
        totalWeighted == 0 ? 0.0 : (externalWeighted / totalWeighted) * 100;

    return IssueBreakdownDaily(
      recordCount: breakdowns.length,
      physicalWeighted: physicalWeighted,
      psychologicalWeighted: psychologicalWeighted,
      externalLifestyleWeighted: externalWeighted,
      physicalPercent: physicalPercent,
      psychologicalPercent: psychologicalPercent,
      externalLifestylePercent: externalPercent,
    );
  }

  /// 计算7天的数据（有记录的天数 < 3时应显示"数据有限"提示）
  static IssueBreakdownWeekly? computeIssueBreakdownWeekly(
    Iterable<BowelRecord> recordsForWeek,
  ) {
    final records = recordsForWeek.toList();
    if (records.isEmpty) return null;

    // 按日期分组
    final groupedByDate = <DateTime, List<BowelRecord>>{};
    for (final record in records) {
      final date =
          DateTime(record.dateTime.year, record.dateTime.month, record.dateTime.day);
      groupedByDate.putIfAbsent(date, () => []).add(record);
    }

    // 计算每天的数据
    final dailyDataList = <(DateTime, IssueBreakdownDaily)>[];
    double totalPhysical = 0.0;
    double totalPsychological = 0.0;
    double totalExternal = 0.0;

    final sortedDates = groupedByDate.keys.toList()..sort();
    for (final date in sortedDates) {
      final daily = computeIssueBreakdownDaily(groupedByDate[date]!);
      if (daily != null) {
        dailyDataList.add((date, daily));
        totalPhysical += daily.physicalPercent;
        totalPsychological += daily.psychologicalPercent;
        totalExternal += daily.externalLifestylePercent;
      }
    }

    if (dailyDataList.isEmpty) return null;

    final daysCount = dailyDataList.length;
    return IssueBreakdownWeekly(
      daysWithRecords: daysCount,
      dailyData: dailyDataList,
      physicalAverage: totalPhysical / daysCount,
      psychologicalAverage: totalPsychological / daysCount,
      externalLifestyleAverage: totalExternal / daysCount,
    );
  }

  /// 计算30天的数据（用于月雷达图）
  static IssueBreakdownMonthly? computeIssueBreakdownMonthly(
    Iterable<BowelRecord> recordsForMonth,
  ) {
    final records = recordsForMonth.toList();
    if (records.isEmpty) return null;

    // 按日期分组
    final groupedByDate = <DateTime, List<BowelRecord>>{};
    for (final record in records) {
      final date =
          DateTime(record.dateTime.year, record.dateTime.month, record.dateTime.day);
      groupedByDate.putIfAbsent(date, () => []).add(record);
    }

    // 计算每天的数据
    final dailyDataList = <(DateTime, IssueBreakdownDaily)>[];
    double totalPhysical = 0.0;
    double totalPsychological = 0.0;
    double totalExternal = 0.0;

    final sortedDates = groupedByDate.keys.toList()..sort();
    for (final date in sortedDates) {
      final daily = computeIssueBreakdownDaily(groupedByDate[date]!);
      if (daily != null) {
        dailyDataList.add((date, daily));
        totalPhysical += daily.physicalPercent;
        totalPsychological += daily.psychologicalPercent;
        totalExternal += daily.externalLifestylePercent;
      }
    }

    if (dailyDataList.isEmpty) return null;

    final daysCount = dailyDataList.length;
    return IssueBreakdownMonthly(
      daysWithRecords: daysCount,
      dailyData: dailyDataList,
      physicalRadarValue: totalPhysical / daysCount,
      psychologicalRadarValue: totalPsychological / daysCount,
      externalLifestyleRadarValue: totalExternal / daysCount,
    );
  }

  /// 计算时间序列数据（用于折线图）
  static IssueBreakdownTimeSeries? computeIssueBreakdownTimeSeries(
    Iterable<BowelRecord> records,
  ) {
    if (records.isEmpty) return null;

    // 按日期分组
    final groupedByDate = <DateTime, List<BowelRecord>>{};
    for (final record in records) {
      final date =
          DateTime(record.dateTime.year, record.dateTime.month, record.dateTime.day);
      groupedByDate.putIfAbsent(date, () => []).add(record);
    }

    // 计算每天的数据
    final points = <(DateTime, IssueBreakdownDaily)>[];
    final sortedDates = groupedByDate.keys.toList()..sort();
    for (final date in sortedDates) {
      final daily = computeIssueBreakdownDaily(groupedByDate[date]!);
      if (daily != null) {
        points.add((date, daily));
      }
    }

    if (points.isEmpty) return null;

    return IssueBreakdownTimeSeries(points: points);
  }

  static int? _singleAnswer(
    Map<String, List<int>> answers,
    List<String> keys,
  ) {
    for (final key in keys) {
      final values = answers[key];
      if (values != null && values.isNotEmpty) {
        return values.first;
      }
    }
    return null;
  }

  /// 计算生理维度核心项的最高单项分
  /// 用于计算权重 W_i = max(Max_Core_Physical_i, 1)
  static double _calculateMaxCoreScore(BowelRecord record) {
    final answers = record.questionnaireAnswers;
    if (answers == null || answers.isEmpty) return 0.0;

    final physicalCore = <double>[];

    // Q2
    _collectSingleSelectScore(
      answers,
      ['q2'],
      {2: 1, 3: 2, 4: 3},
      physicalCore,
    );

    // Q3
    _collectSingleSelectScore(
      answers,
      ['q3'],
      {2: 1, 3: 2},
      physicalCore,
    );

    // Q4
    _collectSingleSelectScore(
      answers,
      ['q4'],
      {2: 1, 3: 0.5, 4: 2, 5: 3, 6: 2},
      physicalCore,
    );

    // Q81
    _collectSingleSelectScore(
      answers,
      ['q81'],
      {1: 3},
      physicalCore,
    );

    // Q7, Q9 (option 7)
    _collectSelectedScores(
      answers,
      ['q7', 'q9'],
      {7: 3},
      physicalCore,
    );

    if (physicalCore.isEmpty) return 0.0;

    return physicalCore.reduce((a, b) => a > b ? a : b);
  }


  static void _collectSingleSelectScore(
    Map<String, List<int>> answers,
    List<String> keys,
    Map<int, double> scoreMap,
    List<double> target,
  ) {
    final selected = _singleAnswer(answers, keys);
    if (selected == null) return;
    final score = scoreMap[selected];
    if (score != null) {
      target.add(score);
    }
  }

  static void _collectSelectedScores(
    Map<String, List<int>> answers,
    List<String> keys,
    Map<int, double> scoreMap,
    List<double> target,
  ) {
    final selected = <int>{};
    for (final key in keys) {
      selected.addAll(answers[key] ?? const <int>[]);
    }
    for (final value in selected) {
      final score = scoreMap[value];
      if (score != null) {
        target.add(score);
      }
    }
  }

  static double _dimensionScore({
    required List<double> coreScores,
    required List<double> companionScores,
    required double cap,
    double coefficient = 1.0,
  }) {
    if (coreScores.isEmpty && companionScores.isEmpty) {
      return 0.0;
    }

    final sortedCore = [...coreScores]..sort((a, b) => b.compareTo(a));
    final maxCore = sortedCore.isEmpty ? 0.0 : sortedCore.first;
    final remainingCore = sortedCore.length <= 1
        ? 0.0
        : sortedCore.skip(1).fold<double>(0.0, (sum, value) => sum + value);
    final companion = companionScores.fold<double>(0.0, (sum, value) => sum + value);
    final raw = (maxCore + (remainingCore + companion) * 0.5) * coefficient;
    return math.min(cap, raw);
  }

  static double _physicalCoefficient({required int? q1, required int? q81}) {
    if (q1 == 1) return 1.0;
    if (q1 == 2) return 1.1;
    if (q1 == 3 && q81 == 1) return 1.3;
    if (q1 == 3 && q81 == 2) return 0.0;
    return 1.0;
  }

  static double _q1Score(int value) {
    switch (value) {
      case 1:
        return 100;
      case 2:
        return 70;
      default:
        return 0;
    }
  }

  static double _q2Score(int value) {
    switch (value) {
      case 1:
        return 100;
      case 2:
        return 75;
      case 3:
        return 40;
      case 4:
        return 10;
      default:
        return 0;
    }
  }

  static double _q3Score(int value) {
    switch (value) {
      case 1:
        return 100;
      case 2:
        return 60;
      case 3:
        return 20;
      default:
        return 0;
    }
  }

  static double _q4Score(int value) {
    switch (value) {
      case 1:
        return 100;
      case 2:
        return 80;
      case 3:
        return 75;
      case 4:
        return 60;
      case 5:
        return 15;
      case 6:
        return 0;
      default:
        return 0;
    }
  }

  static double _q7Penalty(List<int> q7) {
    if (q7.isEmpty || q7.contains(1)) {
      return 0;
    }

    double pain = 0;
    if (q7.contains(2)) pain = 30;
    if (q7.contains(3)) pain = pain < 30 ? 30 : pain;
    if (pain > 40) pain = 40;

    double difficulty = 0;
    if (q7.contains(9) && difficulty < 30) difficulty = 30;
    if (q7.contains(7) && difficulty < 40) difficulty = 40;
    if (q7.contains(10) && difficulty < 70) difficulty = 70;
    if (difficulty > 60) difficulty = 60;

    double urgency = 0;
    if (q7.contains(4) && urgency < 35) urgency = 35;
    if (q7.contains(5) && urgency < 70) urgency = 70;
    if (urgency > 70) urgency = 70;

    final psychological = q7.contains(6) ? 40.0 : 0.0;
    final mildAction = q7.contains(8) ? 15.0 : 0.0;

    final total = pain + difficulty + urgency + psychological + mildAction;
    return total > 80 ? 80 : total;
  }
}
