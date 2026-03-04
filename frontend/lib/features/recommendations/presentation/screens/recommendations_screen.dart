import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:internhub_app/core/constants/api_constants.dart';
import 'package:internhub_app/core/theme/app_colors.dart';
import 'package:internhub_app/features/auth/presentation/providers/auth_notifier.dart';

// ─── Provider ─────────────────────────────────────────────────────────────
final recommendationsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final client = ref.watch(dioClientProvider);
  try {
    final internshipsResp = await client.dio.get(ApiConstants.recommendations);
    final gapsResp = await client.dio.get(ApiConstants.skillGaps);
    final roadmapResp = await client.dio.get(ApiConstants.careerRoadmap);
    return {
      'recommendations': internshipsResp.data,
      'gaps': gapsResp.data,
      'roadmap': roadmapResp.data,
    };
  } catch (_) {
    // Demo data when API not connected
    return {
      'recommendations': [
        {
          'title': 'Flutter Developer Intern',
          'company_name': 'TechCorp India',
          'mode': 'remote',
          'match_score': 87.5,
          'skill_overlap': ['Flutter', 'Dart'],
          'missing_skills': ['Firebase'],
        },
        {
          'title': 'ML Engineer Intern',
          'company_name': 'AI Innovations',
          'mode': 'hybrid',
          'match_score': 64.0,
          'skill_overlap': ['Python'],
          'missing_skills': ['TensorFlow', 'NLP'],
        },
      ],
      'gaps': {
        'student_skills': ['Flutter', 'Dart', 'Python'],
        'top_missing_skills': [
          {'skill': 'Firebase', 'demand': 8},
          {'skill': 'TensorFlow', 'demand': 6},
          {'skill': 'Docker', 'demand': 5},
        ],
        'readiness_score': 65,
      },
      'roadmap': {
        'current_readiness': 65,
        'phases': [
          {
            'phase': 1,
            'skill': 'Firebase',
            'recommended_resources': [
              'Coursera: Firebase Fundamentals',
              'YouTube: Firebase Crash Course'
            ],
            'estimated_weeks': 2,
          },
          {
            'phase': 2,
            'skill': 'TensorFlow',
            'recommended_resources': [
              'Coursera: TensorFlow in Practice',
              'YouTube: ML with TF'
            ],
            'estimated_weeks': 4,
          }
        ],
        'total_weeks': 6
      }
    };
  }
});

class RecommendationsScreen extends ConsumerWidget {
  const RecommendationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recAsync = ref.watch(recommendationsProvider);

    return Scaffold(
      body: DefaultTabController(
        length: 2,
        child: NestedScrollView(
          headerSliverBuilder: (context, bool innerBoxIsScrolled) {
            return [
              SliverAppBar(
                title: const Text('AI Career Center',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                backgroundColor: AppColors.bgSurface,
                elevation: 0,
                pinned: true,
                bottom: const TabBar(
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 3,
                  tabs: [
                    Tab(text: "Matches & Gaps"),
                    Tab(text: "Career Roadmap"),
                  ],
                ),
              ),
            ];
          },
          body: recAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (data) {
              final recs = List<Map<String, dynamic>>.from(
                  data['recommendations'] as List<dynamic>? ?? []);
              final gaps = data['gaps'] as Map<String, dynamic>?;
              final roadmap = data['roadmap'] as Map<String, dynamic>?;
              final readiness =
                  (gaps?['readiness_score'] as num?)?.toInt() ?? 0;
              final missingSkills = List<Map<String, dynamic>>.from(
                  gaps?['top_missing_skills'] as List<dynamic>? ?? []);

              return TabBarView(
                children: [
                  // Tab 1: Matches & Gaps
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ReadinessCard(score: readiness),
                        const SizedBox(height: 24),
                        const Text('Best Matches For You',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        if (recs.isEmpty)
                          const Text(
                              'No matches found for your current skills.')
                        else
                          ...recs.map((r) => _RecommendationCard(data: r)),
                        const SizedBox(height: 24),
                        const Text('Top Skills to Learn',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        const Text(
                            'Skills with high demand across open internships',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 13)),
                        const SizedBox(height: 16),
                        ...missingSkills.map((g) => _SkillGapRow(
                              skill: g['skill'] as String,
                              demand: (g['demand'] as num).toInt(),
                              maxDemand: (missingSkills.isNotEmpty)
                                  ? (missingSkills.first['demand'] as num)
                                      .toInt()
                                  : 1,
                            )),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),

                  // Tab 2: Career Roadmap
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                                color: AppColors.bgElevated,
                                borderRadius: BorderRadius.circular(12)),
                            child: Row(children: [
                              const Icon(Icons.route,
                                  color: AppColors.primary, size: 32),
                              const SizedBox(width: 16),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    const Text('Your AI Focus Path',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16)),
                                    Text(
                                        '${roadmap?['total_weeks'] ?? 0} Weeks to higher competitiveness',
                                        style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 13)),
                                  ]))
                            ])),
                        const SizedBox(height: 24),
                        ...?roadmap?['phases']?.map<Widget>((phaseData) {
                          return _TimelineItem(phase: phaseData);
                        })
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final Map<String, dynamic> phase;
  const _TimelineItem({required this.phase});

  @override
  Widget build(BuildContext context) {
    final resources =
        List<String>.from(phase['recommended_resources'] as List? ?? []);

    return IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Timeline visual indicator
      SizedBox(
        width: 40,
        child: Column(children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.bgSurface, width: 3),
            ),
            child: Center(
                child: Text('${phase['phase']}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold))),
          ),
          Expanded(
            child: Container(
              width: 2,
              color: AppColors.primary.withValues(alpha: 0.3),
            ),
          )
        ]),
      ),
      const SizedBox(width: 12),
      // Content Card
      Expanded(
          child: Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 4,
                        offset: const Offset(0, 2))
                  ]),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Master ${phase['skill']}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('${phase['estimated_weeks']} Wks',
                              style: const TextStyle(
                                  color: AppColors.secondary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12))
                        ]),
                    const SizedBox(height: 12),
                    const Text('AI Recommended Resources:',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                    const SizedBox(height: 8),
                    ...resources.map((r) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.play_circle_outline,
                                  size: 14, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Expanded(
                                  child: Text(r,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textPrimary))),
                            ],
                          ),
                        )),
                  ])))
    ]));
  }
}

class _ReadinessCard extends StatelessWidget {
  final int score;
  const _ReadinessCard({required this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          gradient: AppColors.gradientPrimary,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ]),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 70,
                height: 70,
                child: CircularProgressIndicator(
                  value: score / 100,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 6,
                ),
              ),
              Text('$score%',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ],
          ),
          const SizedBox(width: 20),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Career Readiness Score',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                SizedBox(height: 4),
                Text('Based on your skills and exam performance',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _RecommendationCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final score = (data['match_score'] as num).toDouble();
    final overlaps =
        List<String>.from(data['skill_overlap'] as List<dynamic>? ?? []);
    final missing =
        List<String>.from(data['missing_skills'] as List<dynamic>? ?? []);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['title'] as String,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                    Text(data['company_name'] as String,
                        style: const TextStyle(
                            color: AppColors.primary, fontSize: 13)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: score >= 70
                      ? AppColors.success.withValues(alpha: 0.15)
                      : AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '${score.round()}% match',
                  style: TextStyle(
                    color: score >= 70 ? AppColors.success : AppColors.warning,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          if (overlaps.isNotEmpty) ...[
            const Text('✓ You have:',
                style: TextStyle(color: AppColors.success, fontSize: 12)),
            const SizedBox(height: 4),
            Wrap(
                spacing: 6,
                children:
                    overlaps.map((s) => _Chip(s, AppColors.success)).toList()),
            const SizedBox(height: 8),
          ],
          if (missing.isNotEmpty) ...[
            const Text('Learn to improve match:',
                style: TextStyle(color: AppColors.warning, fontSize: 12)),
            const SizedBox(height: 4),
            Wrap(
                spacing: 6,
                children:
                    missing.map((s) => _Chip(s, AppColors.warning)).toList()),
          ],
        ],
      ),
    );
  }
}

class _SkillGapRow extends StatelessWidget {
  final String skill;
  final int demand;
  final int maxDemand;
  const _SkillGapRow(
      {required this.skill, required this.demand, required this.maxDemand});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(skill,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                Text('$demand internships',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: maxDemand > 0 ? demand / maxDemand : 0,
                backgroundColor: AppColors.bgElevated,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.primary),
                minHeight: 6,
              ),
            ),
          ],
        ),
      );
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 11)),
      );
}
