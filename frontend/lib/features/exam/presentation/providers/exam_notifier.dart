import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:internhub_app/features/auth/presentation/providers/auth_notifier.dart';
import 'package:internhub_app/features/exam/data/repositories/exam_repository.dart';
import 'package:internhub_app/features/exam/domain/entities/exam_entities.dart';

// ─── Providers ──────────────────────────────────────────────────────────
final examRepositoryProvider = Provider<ExamRepository>((ref) {
  return ExamRepository(ref.watch(dioClientProvider));
});

final examNotifierProvider =
    StateNotifierProvider<ExamNotifier, ExamState>((ref) {
  return ExamNotifier(ref.watch(examRepositoryProvider));
});

// ─── State ──────────────────────────────────────────────────────────────
class ExamState {
  final ExamSessionInfo? session;
  final List<ExamQuestion> questions;
  final Map<String, StudentAnswer> answers;
  final int currentIndex;
  final int remainingSeconds;
  final bool isLoading;
  final String? error;
  final bool submitted;
  final int warningsCount;

  const ExamState({
    this.session,
    this.questions = const [],
    this.answers = const {},
    this.currentIndex = 0,
    this.remainingSeconds = 3600,
    this.isLoading = false,
    this.error,
    this.submitted = false,
    this.warningsCount = 0,
  });

  ExamState copyWith({
    ExamSessionInfo? session,
    List<ExamQuestion>? questions,
    Map<String, StudentAnswer>? answers,
    int? currentIndex,
    int? remainingSeconds,
    bool? isLoading,
    String? error,
    bool? submitted,
    int? warningsCount,
  }) =>
      ExamState(
        session: session ?? this.session,
        questions: questions ?? this.questions,
        answers: answers ?? this.answers,
        currentIndex: currentIndex ?? this.currentIndex,
        remainingSeconds: remainingSeconds ?? this.remainingSeconds,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        submitted: submitted ?? this.submitted,
        warningsCount: warningsCount ?? this.warningsCount,
      );

  ExamQuestion? get currentQuestion =>
      questions.isNotEmpty && currentIndex < questions.length
          ? questions[currentIndex]
          : null;

  int get answeredCount => answers.values.where((a) => a.isAnswered).length;

  double get progressFraction =>
      questions.isEmpty ? 0 : answeredCount / questions.length;

  String get formattedTime {
    final m = remainingSeconds ~/ 60;
    final s = remainingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  bool get isTimeCritical => remainingSeconds <= 300; // last 5 min
}

// ─── Notifier ───────────────────────────────────────────────────────────
class ExamNotifier extends StateNotifier<ExamState> {
  final ExamRepository _repo;
  Timer? _timer;

  ExamNotifier(this._repo) : super(const ExamState());

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> startExam(String internshipId) async {
    state = state.copyWith(isLoading: true);
    try {
      final session = await _repo.startSession(internshipId);
      final questions = await _repo.getSessionQuestions(session.id);

      // Initialize answer slots
      final answers = <String, StudentAnswer>{
        for (final q in questions) q.id: StudentAnswer(questionId: q.id),
      };

      state = state.copyWith(
        session: session,
        questions: questions,
        answers: answers,
        remainingSeconds: session.durationMinutes * 60,
        isLoading: false,
      );

      _startTimer();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.remainingSeconds <= 0) {
        _timer?.cancel();
        submitExam();
      } else {
        state = state.copyWith(
          remainingSeconds: state.remainingSeconds - 1,
        );
      }
    });
  }

  void selectAnswer(String questionId, int optionIndex) {
    final updated = Map<String, StudentAnswer>.from(state.answers);
    updated[questionId] = StudentAnswer(
      questionId: questionId,
      selectedIndex: optionIndex,
    );
    state = state.copyWith(answers: updated);

    // Fire-and-forget to API
    final sessionId = state.session?.id;
    if (sessionId != null) {
      _repo
          .submitAnswer(
            sessionId: sessionId,
            questionId: questionId,
            selectedOptionIndex: optionIndex,
          )
          .catchError((_) {}); // Ignore errors — retry on final submit
    }
  }

  void goToQuestion(int index) {
    if (index >= 0 && index < state.questions.length) {
      state = state.copyWith(currentIndex: index);
    }
  }

  void nextQuestion() => goToQuestion(state.currentIndex + 1);
  void prevQuestion() => goToQuestion(state.currentIndex - 1);

  Future<void> reportProctorEvent(String eventType, {int severity = 1}) async {
    final sessionId = state.session?.id;
    if (sessionId == null) return;

    state = state.copyWith(warningsCount: state.warningsCount + 1);
    _repo
        .logProctorEvent(
          sessionId: sessionId,
          eventType: eventType,
          severity: severity,
        )
        .catchError((_) {});
  }

  Future<void> submitExam() async {
    final sessionId = state.session?.id;
    if (sessionId == null) return;

    _timer?.cancel();
    state = state.copyWith(isLoading: true);

    try {
      // Submit all unanswered questions first
      final unanswered = state.answers.values.where((a) => a.isAnswered);
      for (final answer in unanswered) {
        await _repo.submitAnswer(
          sessionId: sessionId,
          questionId: answer.questionId,
          selectedOptionIndex: answer.selectedIndex,
          answerText: answer.answerText,
        );
      }

      final result = await _repo.submitSession(sessionId);
      state = state.copyWith(
        session: result,
        isLoading: false,
        submitted: true,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void reset() {
    _timer?.cancel();
    state = const ExamState();
  }
}
