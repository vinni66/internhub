class ExamQuestion {
  final String id;
  final String questionText;
  final String questionType;
  final String difficulty;
  final int marks;
  final List<QuestionOption>? options;
  final int? timeLimitSeconds;

  const ExamQuestion({
    required this.id,
    required this.questionText,
    required this.questionType,
    required this.difficulty,
    required this.marks,
    this.options,
    this.timeLimitSeconds,
  });

  factory ExamQuestion.fromJson(Map<String, dynamic> json) => ExamQuestion(
        id: json['id'] as String,
        questionText: json['question_text'] as String,
        questionType: json['question_type'] as String,
        difficulty: json['difficulty'] as String,
        marks: json['marks'] as int,
        options: (json['options'] as List<dynamic>?)
            ?.map((o) => QuestionOption.fromJson(o))
            .toList(),
        timeLimitSeconds: json['time_limit_seconds'] as int?,
      );

  bool get isMcq => questionType == 'mcq' || questionType == 'true_false';
}

class QuestionOption {
  final int index;
  final String text;

  const QuestionOption({required this.index, required this.text});

  factory QuestionOption.fromJson(Map<String, dynamic> json) => QuestionOption(
        index: json['index'] as int,
        text: json['text'] as String,
      );
}

class ExamSessionInfo {
  final String id;
  final String status;
  final String? startedAt;
  final String? expiresAt;
  final int durationMinutes;
  final int questionCount;
  final int warningsCount;
  final int? integrityScore;
  final double? percentage;

  const ExamSessionInfo({
    required this.id,
    required this.status,
    this.startedAt,
    this.expiresAt,
    required this.durationMinutes,
    required this.questionCount,
    required this.warningsCount,
    this.integrityScore,
    this.percentage,
  });

  factory ExamSessionInfo.fromJson(Map<String, dynamic> json) =>
      ExamSessionInfo(
        id: json['id'] as String,
        status: json['status'] as String,
        startedAt: json['started_at'] as String?,
        expiresAt: json['expires_at'] as String?,
        durationMinutes: json['duration_minutes'] as int,
        questionCount: json['question_count'] as int,
        warningsCount: json['warnings_count'] as int,
        integrityScore: json['integrity_score'] as int?,
        percentage: (json['percentage'] as num?)?.toDouble(),
      );

  bool get isCompleted => status == 'completed';
  bool get isActive => status == 'active';
}

class StudentAnswer {
  final String questionId;
  int? selectedIndex;
  String? answerText;
  int timeSpentSeconds;

  StudentAnswer({
    required this.questionId,
    this.selectedIndex,
    this.answerText,
    this.timeSpentSeconds = 0,
  });

  bool get isAnswered =>
      selectedIndex != null || (answerText?.isNotEmpty ?? false);
}
