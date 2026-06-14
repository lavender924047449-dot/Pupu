/// 排便 session 记录模型（新版）
/// 数据来自 timer 计时时长 + 问卷答案
library;

import 'package:uuid/uuid.dart';

class BowelRecord {
  final String id;
  final DateTime dateTime;
  final int durationMinutes;
  final int durationSeconds;
  final Map<String, List<int>>? questionnaireAnswers;
  final DateTime createdAt;

  BowelRecord({
    required this.id,
    required this.dateTime,
    this.durationMinutes = 0,
    this.durationSeconds = 0,
    this.questionnaireAnswers,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory BowelRecord.fromTimerSession({
    required DateTime startedAt,
    required Duration elapsed,
  }) {
    final totalSeconds = elapsed.inSeconds;
    return BowelRecord(
      id: const Uuid().v4(),
      dateTime: startedAt,
      durationMinutes: totalSeconds ~/ 60,
      durationSeconds: totalSeconds,
      questionnaireAnswers: null,
    );
  }

  int get displayMinutes => durationSeconds ~/ 60;

  int get displaySeconds => durationSeconds % 60;

  factory BowelRecord.fromJson(Map<String, dynamic> json) {
    Map<String, List<int>>? answers;
    final raw = json['questionnaire_answers'];
    if (raw is Map) {
      answers = raw.map(
        (key, value) => MapEntry(
          key.toString(),
          (value as List<dynamic>).map((e) => (e as num).toInt()).toList(),
        ),
      );
    }

    return BowelRecord(
      id: json['id'] as String,
      dateTime: DateTime.parse(json['date_time'] as String),
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 0,
      durationSeconds:
          (json['duration_seconds'] as num?)?.toInt() ??
              (((json['duration_minutes'] as num?)?.toInt() ?? 0) * 60),
      questionnaireAnswers: answers,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date_time': dateTime.toIso8601String(),
      'duration_minutes': durationSeconds ~/ 60,
      'duration_seconds': durationSeconds,
      if (questionnaireAnswers != null)
        'questionnaire_answers': questionnaireAnswers,
      'created_at': createdAt.toIso8601String(),
    };
  }

  BowelRecord copyWith({
    String? id,
    DateTime? dateTime,
    int? durationMinutes,
    int? durationSeconds,
    Map<String, List<int>>? questionnaireAnswers,
  }) {
    return BowelRecord(
      id: id ?? this.id,
      dateTime: dateTime ?? this.dateTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      questionnaireAnswers: questionnaireAnswers ?? this.questionnaireAnswers,
      createdAt: createdAt,
    );
  }
}
