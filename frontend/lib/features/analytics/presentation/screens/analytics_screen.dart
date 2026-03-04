import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:internhub_app/core/constants/api_constants.dart';

import 'package:internhub_app/core/theme/app_colors.dart';
import 'package:internhub_app/features/auth/presentation/providers/auth_notifier.dart';

// ─── Provider ─────────────────────────────────────────────────────────────
final analyticsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final client = ref.watch(dioClientProvider);
  try {
    final resp = await client.dio.get(ApiConstants.analyticsMe);
    return resp.data as Map<String, dynamic>;
  } catch (_) {
    // Return demo data when API not reachable
    return {
      'total_exams_taken': 3,
      'average_score': 72.4,
      'best_score': 88.0,
      'average_integrity_score': 95.0,
      'total_applications': 5,
      'applications_shortlisted': 2,
      'performance_trend': 'improving',
      'score_history': [
        {'percentage': 58.0, 'integrity_score': 95},
        {'percentage': 72.0, 'integrity_score': 98},
        {'percentage': 88.0, 'integrity_score': 92},
      ],
    };
  }
});

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(analyticsProvider);
    final user = ref.watch(authNotifierProvider);
    final email = user is AuthStateAuthenticated ? user.user.email : 'Student';

    return Scaffold(
      appBar: AppBar(title: const Text('My Analytics')),
      body: analyticsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Header ───────────────────────────────────────
              _GradientHeader(email: email),
              const SizedBox(height: 20),

              // ─── Stats Grid ───────────────────────────────────
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  _StatCard(
                    'Exams Taken',
                    '${data['total_exams_taken']}',
                    Icons.quiz_rounded,
                    AppColors.primary,
                  ),
                  _StatCard(
                    'Avg Score',
                    '${data['average_score']}%',
                    Icons.grade_rounded,
                    AppColors.secondary,
                  ),
                  _StatCard(
                    'Best Score',
                    '${data['best_score']}%',
                    Icons.emoji_events_rounded,
                    AppColors.warning,
                  ),
                  _StatCard(
                    'Integrity',
                    '${data['average_integrity_score']}%',
                    Icons.verified_rounded,
                    AppColors.success,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ─── Applications ─────────────────────────────────
              _SectionTitle('Applications'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      'Applied',
                      '${data['total_applications']}',
                      Icons.send_rounded,
                      AppColors.info,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      'Shortlisted',
                      '${data['applications_shortlisted']}',
                      Icons.checklist_rounded,
                      AppColors.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ─── Score History ────────────────────────────────
              _SectionTitle('Score History'),
              const SizedBox(height: 12),
              _ScoreHistoryChart(
                  history: List<Map<String, dynamic>>.from(
                data['score_history'] as List<dynamic>? ?? [],
              )),
              const SizedBox(height: 20),

              // ─── Trend Badge ──────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(children: [
                  Icon(
                    data['performance_trend'] == 'improving'
                        ? Icons.trending_up_rounded
                        : Icons.trending_flat_rounded,
                    color: data['performance_trend'] == 'improving'
                        ? AppColors.success
                        : AppColors.warning,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['performance_trend'] == 'improving'
                              ? 'Performance Improving'
                              : 'Performance Stable',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const Text(
                          'Keep taking exams to improve your ranking',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ]),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GradientHeader extends StatelessWidget {
  final String email;
  const _GradientHeader({required this.email});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppColors.gradientPrimary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white24,
            child: Text(
              email.isNotEmpty ? email[0].toUpperCase() : 'S',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Performance Overview',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
            Text(email,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ]),
        ]),
      );
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatCard(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 22, fontWeight: FontWeight.w700)),
            Text(label,
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);
  @override
  Widget build(BuildContext context) => Text(title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold));
}

class _ScoreHistoryChart extends StatelessWidget {
  final List<Map<String, dynamic>> history;
  const _ScoreHistoryChart({required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No exam history yet.',
              style: TextStyle(color: AppColors.textMuted)),
        ),
      );
    }
    return Container(
      height: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Recent Scores',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: history.asMap().entries.map((e) {
                final score = (e.value['percentage'] as num?)?.toDouble() ?? 0;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('${score.round()}%',
                            style: const TextStyle(
                                fontSize: 10, color: AppColors.textMuted)),
                        const SizedBox(height: 4),
                        FractionallySizedBox(
                          heightFactor: score / 100,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: AppColors.gradientPrimary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('Exam ${e.key + 1}',
                            style: const TextStyle(
                                fontSize: 10, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

