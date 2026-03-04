import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:internhub_app/core/theme/app_colors.dart';
import 'package:internhub_app/features/exam/presentation/providers/exam_notifier.dart';

class ExamScreen extends ConsumerStatefulWidget {
  final String internshipId;
  final String internshipTitle;
  const ExamScreen({
    super.key,
    required this.internshipId,
    required this.internshipTitle,
  });

  @override
  ConsumerState<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends ConsumerState<ExamScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Start the exam
    Future.microtask(() =>
        ref.read(examNotifierProvider.notifier).startExam(widget.internshipId));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Anti-cheat: detect when user backgrounded the app
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      ref.read(examNotifierProvider.notifier).reportProctorEvent(
            'tab_switch',
            severity: 2,
          );
      _showWarningDialog('Tab Switch Detected',
          'Switching apps during exam is recorded and may affect your integrity score.');
    }
  }

  void _showWarningDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(color: AppColors.textPrimary)),
        ]),
        content: Text(message,
            style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('I Understand'),
          ),
        ],
      ),
    );
  }

  Future<bool> _onWillPop() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('Leave Exam?'),
        content: const Text(
          'Your progress is saved. The timer will continue running. '
          'You can return to the exam from the internship page.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Stay')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Leave')),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final examState = ref.watch(examNotifierProvider);

    // Navigate to result when submitted
    if (examState.submitted && examState.session != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/exam-result/${examState.session!.id}');
      });
    }

    if (examState.isLoading && examState.questions.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Preparing your exam...'),
            ],
          ),
        ),
      );
    }

    if (examState.error != null && examState.questions.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 64),
            const SizedBox(height: 16),
            Text(examState.error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref
                  .read(examNotifierProvider.notifier)
                  .startExam(widget.internshipId),
              child: const Text('Retry'),
            ),
          ]),
        ),
      );
    }

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: AppColors.bgDark,
        appBar: _buildAppBar(context, examState),
        body: Column(
          children: [
            _TimerProgressBar(examState: examState),
            Expanded(
              child: Row(
                children: [
                  // ─── Question Panel ──────────────────────────
                  Expanded(
                    flex: 3,
                    child: _QuestionPanel(examState: examState),
                  ),
                  // ─── Navigator Panel (wide screen) ──────────
                  if (MediaQuery.of(context).size.width > 800)
                    SizedBox(
                      width: 180,
                      child: _QuestionNavigatorPanel(examState: examState),
                    ),
                ],
              ),
            ),
            _NavigationBar(examState: examState),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, ExamState state) {
    return AppBar(
      automaticallyImplyLeading: false,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.internshipTitle,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textSecondary)),
          Text(
            '${state.answeredCount}/${state.questions.length} answered',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      actions: [
        // Warning counter
        if (state.warningsCount > 0)
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
            ),
            child: Row(children: [
              const Icon(Icons.warning_amber_rounded,
                  color: AppColors.warning, size: 16),
              const SizedBox(width: 4),
              Text('${state.warningsCount}',
                  style: const TextStyle(
                      color: AppColors.warning, fontWeight: FontWeight.bold)),
            ]),
          ),
        // Submit button
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onPressed: state.isLoading ? null : () => _confirmSubmit(context),
            child: const Text('Submit', style: TextStyle(color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmSubmit(BuildContext context) async {
    final state = ref.read(examNotifierProvider);
    final unanswered = state.questions.length - state.answeredCount;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('Submit Exam?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Answered: ${state.answeredCount} / ${state.questions.length}'),
            if (unanswered > 0)
              Text('$unanswered unanswered question(s)',
                  style: const TextStyle(color: AppColors.warning)),
            const SizedBox(height: 8),
            const Text('Once submitted, you cannot change your answers.',
                style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Review'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child:
                const Text('Submit Now', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(examNotifierProvider.notifier).submitExam();
    }
  }
}

// ─── Timer Progress Bar ──────────────────────────────────────────────────
class _TimerProgressBar extends StatelessWidget {
  final ExamState examState;
  const _TimerProgressBar({required this.examState});

  @override
  Widget build(BuildContext context) {
    final total = examState.session?.durationMinutes ?? 60;
    final progress = examState.remainingSeconds / (total * 60);
    final barColor =
        examState.isTimeCritical ? AppColors.error : AppColors.primary;

    return Container(
      color: AppColors.bgCard,
      child: Column(
        children: [
          LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.bgElevated,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
            minHeight: 4,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Icon(Icons.timer_rounded,
                      size: 16,
                      color: examState.isTimeCritical
                          ? AppColors.error
                          : AppColors.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    examState.formattedTime,
                    style: TextStyle(
                      color: examState.isTimeCritical
                          ? AppColors.error
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ]),
                // Progress fraction
                Text(
                  '${(progress * 100).toStringAsFixed(0)}% time remaining',
                  style:
                      const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Question Panel ──────────────────────────────────────────────────────
class _QuestionPanel extends ConsumerWidget {
  final ExamState examState;
  const _QuestionPanel({required this.examState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final question = examState.currentQuestion;
    if (question == null) return const SizedBox();

    final answer = examState.answers[question.id];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question metadata
          Row(
            children: [
              _Badge('Q ${examState.currentIndex + 1}', AppColors.primary),
              const SizedBox(width: 8),
              _Badge(question.difficulty.toUpperCase(),
                  _difficultyColor(question.difficulty)),
              const SizedBox(width: 8),
              _Badge('${question.marks} mark${question.marks > 1 ? "s" : ""}',
                  AppColors.textMuted),
            ],
          ),
          const SizedBox(height: 16),

          // Question text
          SelectableText(
            question.questionText,
            style: const TextStyle(
                fontSize: 17, height: 1.6, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 24),

          // MCQ Options
          if (question.isMcq && question.options != null) ...[
            ...question.options!.asMap().entries.map((entry) {
              final i = entry.key;
              final opt = entry.value;
              final selected = answer?.selectedIndex == i;

              return GestureDetector(
                onTap: () => ref
                    .read(examNotifierProvider.notifier)
                    .selectAnswer(question.id, i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : AppColors.bgCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.border,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected
                              ? AppColors.primary
                              : AppColors.bgElevated,
                          border: Border.all(
                            color:
                                selected ? AppColors.primary : AppColors.border,
                          ),
                        ),
                        child: Center(
                          child: selected
                              ? const Icon(Icons.check,
                                  color: Colors.white, size: 16)
                              : Text(
                                  String.fromCharCode(65 + i),
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(opt.text,
                            style: TextStyle(
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.textPrimary,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            )),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],

          // Essay / Fill blank
          if (!question.isMcq)
            TextField(
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: 'Type your answer here...',
              ),
              onChanged: (v) {
                // TODO: debounced text answer saving
              },
            ),
        ],
      ),
    );
  }

  Color _difficultyColor(String d) => switch (d.toLowerCase()) {
        'easy' => AppColors.success,
        'hard' => AppColors.error,
        _ => AppColors.warning,
      };
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge(this.text, this.color);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(text,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      );
}

// ─── Question Navigator Panel ────────────────────────────────────────────
class _QuestionNavigatorPanel extends ConsumerWidget {
  final ExamState examState;
  const _QuestionNavigatorPanel({required this.examState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.border)),
        color: AppColors.bgCard,
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Questions',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 1,
              ),
              itemCount: examState.questions.length,
              itemBuilder: (ctx, i) {
                final q = examState.questions[i];
                final answered = examState.answers[q.id]?.isAnswered ?? false;
                final isCurrent = examState.currentIndex == i;

                return GestureDetector(
                  onTap: () =>
                      ref.read(examNotifierProvider.notifier).goToQuestion(i),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? AppColors.primary
                          : answered
                              ? AppColors.success.withValues(alpha: 0.2)
                              : AppColors.bgElevated,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isCurrent
                            ? AppColors.primary
                            : answered
                                ? AppColors.success
                                : AppColors.border,
                      ),
                    ),
                    child: Center(
                      child: Text('${i + 1}',
                          style: TextStyle(
                            color: answered
                                ? AppColors.success
                                : AppColors.textSecondary,
                            fontWeight:
                                isCurrent ? FontWeight.bold : FontWeight.normal,
                            fontSize: 11,
                          )),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(children: [
              _LegendItem(AppColors.success, 'Answered'),
              const SizedBox(height: 4),
              _LegendItem(AppColors.border, 'Not answered'),
            ]),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem(this.color, this.label);
  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
        ],
      );
}

// ─── Navigation Bar ──────────────────────────────────────────────────────
class _NavigationBar extends ConsumerWidget {
  final ExamState examState;
  const _NavigationBar({required this.examState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(examNotifierProvider.notifier);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed:
                examState.currentIndex > 0 ? notifier.prevQuestion : null,
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('Previous'),
          ),
          const Spacer(),
          Text(
            '${examState.currentIndex + 1} / ${examState.questions.length}',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: examState.currentIndex < examState.questions.length - 1
                ? notifier.nextQuestion
                : null,
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: const Text('Next'),
          ),
        ],
      ),
    );
  }
}

