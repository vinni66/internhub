import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:internhub_app/core/theme/app_colors.dart';
import 'package:internhub_app/features/exam/presentation/providers/exam_notifier.dart';

class ExamResultScreen extends ConsumerWidget {
  final String sessionId;
  const ExamResultScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final examState = ref.watch(examNotifierProvider);
    final session = examState.session;

    if (session == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final score = session.percentage ?? 0;
    final integrity = session.integrityScore ?? 100;
    final passed = score >= 50;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ─── Result Hero ─────────────────────────────────────────
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: passed
                        ? [AppColors.success, const Color(0xFF00B894)]
                        : [AppColors.error, const Color(0xFFE17055)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      passed
                          ? Icons.emoji_events_rounded
                          : Icons.sentiment_dissatisfied_rounded,
                      size: 80,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      passed ? 'Great Job!' : 'Better Luck Next Time',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      passed
                          ? 'You passed the exam!'
                          : 'You did not meet the cutoff.',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ─── Score Cards ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: _ScoreCard(
                        label: 'Score',
                        value: '${score.toStringAsFixed(1)}%',
                        icon: Icons.grade_rounded,
                        color: passed ? AppColors.success : AppColors.error,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ScoreCard(
                        label: 'Integrity',
                        value: '$integrity%',
                        icon: Icons.verified_rounded,
                        color: AppColors.integrityScoreColor(integrity),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ScoreCard(
                        label: 'Warnings',
                        value: '${examState.warningsCount}',
                        icon: Icons.warning_amber_rounded,
                        color: examState.warningsCount > 0
                            ? AppColors.warning
                            : AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ─── Score Breakdown ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Score Breakdown',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    _BreakdownRow(
                        'Total Questions', '${session.questionCount}'),
                    _BreakdownRow('Answered', '${examState.answeredCount}'),
                    _BreakdownRow(
                        'Correct',
                        passed
                            ? '~${(score / 100 * session.questionCount).round()}'
                            : 'N/A'),
                    _BreakdownRow('Duration', '${session.durationMinutes} min'),
                    if (session.integrityScore != null)
                      _BreakdownRow('Integrity Score', '$integrity / 100'),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ─── Action Buttons ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        ref.read(examNotifierProvider.notifier).reset();
                        context.go('/internships');
                      },
                      icon: const Icon(Icons.work_rounded),
                      label: const Text('Browse More Internships'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => context.go('/analytics'),
                      icon: const Icon(Icons.bar_chart_rounded),
                      label: const Text('View My Analytics'),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _ScoreCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(label,
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ],
        ),
      );
}

class _BreakdownRow extends StatelessWidget {
  final String label, value;
  const _BreakdownRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textSecondary)),
            Text(value,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

