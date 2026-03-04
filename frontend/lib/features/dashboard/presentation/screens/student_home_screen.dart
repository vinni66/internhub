import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:internhub_app/core/router/app_router.dart';
import 'package:internhub_app/core/theme/app_colors.dart';
import 'package:internhub_app/core/constants/api_constants.dart';
import 'package:internhub_app/features/auth/presentation/providers/auth_notifier.dart';
import 'package:internhub_app/features/internship/presentation/screens/internship_list_screen.dart';

// ─── Stats Provider ───────────────────────────────────────────────────────────
final homeStatsProvider =
    FutureProvider.autoDispose<Map<String, int>>((ref) async {
  final client = ref.watch(dioClientProvider);
  try {
    final results = await Future.wait([
      client.dio
          .get(ApiConstants.internships, queryParameters: {'page_size': 1}),
      client.dio.get(ApiConstants.myApplications),
    ]);
    final internshipTotal = (results[0].data['total'] as int?) ?? 0;
    final appData = results[1].data;
    final appCount = appData is List
        ? appData.length
        : (appData['items'] as List?)?.length ?? 0;
    return {'internships': internshipTotal, 'applications': appCount};
  } catch (_) {
    return {'internships': 0, 'applications': 0};
  }
});

// ─── Screen ───────────────────────────────────────────────────────────────────
class StudentHomeScreen extends ConsumerStatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  ConsumerState<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends ConsumerState<StudentHomeScreen> {
  final PageController _pageController = PageController();
  int _currentBannerIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final firstName = authState is AuthStateAuthenticated
        ? (authState.user.email.split('@')[0])
        : 'there';
    final greeting = _greeting();
    final listAsync = ref.watch(internshipListProvider);
    final statsAsync = ref.watch(homeStatsProvider);

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: CustomScrollView(
        slivers: [
          // ── Greeting Header ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.bgDark],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.5],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 52, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$greeting,',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  Text(
                    firstName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Find your perfect internship today 🚀',
                    style: TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // ── Live Stats Row ────────────────────────────────────────────
          SliverToBoxAdapter(
            child: statsAsync.when(
              data: (stats) => _StatsRow(
                internshipCount: stats['internships'] ?? 0,
                appCount: stats['applications'] ?? 0,
              ),
              loading: () => _shimmerStats(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),

          // ── Hero Banner (Sliding) ─────────────────────────────────────
          SliverToBoxAdapter(
            child: listAsync.when(
              data: (internships) {
                if (internships.isEmpty) return const SizedBox.shrink();
                final featured = internships.take(3).toList();
                return Column(
                  children: [
                    SizedBox(
                      height: 170,
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: featured.length,
                        onPageChanged: (idx) =>
                            setState(() => _currentBannerIndex = idx),
                        itemBuilder: (_, i) =>
                            _HeroBannerCard(internship: featured[i]),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        featured.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentBannerIndex == index ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentBannerIndex == index
                                ? AppColors.primary
                                : AppColors.primary.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                );
              },
              loading: () => _shimmerBanner(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),

          // ── Action Grid ───────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _ActionCard(
                          title: 'Apply\nInternship',
                          icon: Icons.school_rounded,
                          color: AppColors.primary,
                          textColor: Colors.white,
                          iconColor: AppColors.secondary,
                          onTap: () => context.go(AppRoutes.internships),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionCard(
                          title: 'Attend\nTest',
                          icon: Icons.assignment_rounded,
                          color: AppColors.secondary,
                          textColor: AppColors.primary,
                          iconColor: AppColors.primary,
                          onTap: () => context.go(
                              '${AppRoutes.exam}/00000000-0000-0000-0000-000000000001?title=AI+Proctored+Exam'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionCard(
                          title: 'My\nResults',
                          icon: Icons.bar_chart_rounded,
                          color: AppColors.secondary,
                          textColor: AppColors.primary,
                          iconColor: AppColors.primary,
                          onTap: () => context.go(AppRoutes.analytics),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionCard(
                          title: 'AI\nSuggestions',
                          icon: Icons.lightbulb_outline_rounded,
                          color: AppColors.primary,
                          textColor: Colors.white,
                          iconColor: AppColors.secondary,
                          onTap: () => context.go(AppRoutes.recommendations),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),

          // ── Recent Openings ───────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Recent Openings',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary)),
                  GestureDetector(
                    onTap: () => context.go(AppRoutes.internships),
                    child: const Text('See all',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          // ── Internship Cards ──────────────────────────────────────────
          listAsync.when(
            data: (internships) {
              if (internships.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: const [
                        Icon(Icons.work_off_rounded,
                            size: 48, color: AppColors.textMuted),
                        SizedBox(height: 8),
                        Text('No internships posted yet',
                            style: TextStyle(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _RecommendedCard(
                      internship: internships[i],
                      onTap: () =>
                          context.go('/internships/${internships[i].id}'),
                    ),
                    childCount: internships.take(5).length,
                  ),
                ),
              );
            },
            loading: () => SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, __) => _shimmerCard(),
                  childCount: 3,
                ),
              ),
            ),
            error: (e, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  Widget _shimmerStats() {
    return Shimmer.fromColors(
      baseColor: AppColors.bgElevated,
      highlightColor: AppColors.bgCard,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: List.generate(
            2,
            (_) => Expanded(
              child: Container(
                height: 56,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _shimmerBanner() {
    return Shimmer.fromColors(
      baseColor: AppColors.bgElevated,
      highlightColor: AppColors.bgCard,
      child: Container(
        height: 170,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _shimmerCard() {
    return Shimmer.fromColors(
      baseColor: AppColors.bgElevated,
      highlightColor: AppColors.bgCard,
      child: Container(
        height: 72,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// ─── Stats Row ────────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final int internshipCount;
  final int appCount;
  const _StatsRow({required this.internshipCount, required this.appCount});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Row(
        children: [
          _StatChip(
            icon: Icons.work_outline_rounded,
            value: '$internshipCount',
            label: 'Live Openings',
            color: AppColors.primary,
          ),
          const SizedBox(width: 12),
          _StatChip(
            icon: Icons.send_rounded,
            value: '$appCount',
            label: 'Applied',
            color: AppColors.success,
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _StatChip(
      {required this.icon,
      required this.value,
      required this.label,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                Text(label,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Hero Banner Card (Real Data) ─────────────────────────────────────────────
class _HeroBannerCard extends StatelessWidget {
  final InternshipModel internship;
  const _HeroBannerCard({required this.internship});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/internships/${internship.id}'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.secondary, Color(0xFFFFE0A5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              bottom: -10,
              child: Icon(Icons.computer_rounded,
                  size: 120, color: AppColors.primary.withValues(alpha: 0.08)),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    internship.companyName,
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    internship.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 20,
                        fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () =>
                            context.go('/internships/${internship.id}'),
                        child: const Text('View Details'),
                      ),
                      if (internship.stipendRange != null) ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            internship.stipendRange!,
                            style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Action Card ──────────────────────────────────────────────────────────────
class _ActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Color textColor;
  final Color iconColor;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.textColor,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    height: 1.2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Recent Internship Card ───────────────────────────────────────────────────
class _RecommendedCard extends StatelessWidget {
  final InternshipModel internship;
  final VoidCallback onTap;

  const _RecommendedCard({required this.internship, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: AppColors.gradientPrimary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  internship.companyName.isNotEmpty
                      ? internship.companyName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(internship.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 3),
                  Text(
                    '${internship.companyName}${internship.location != null ? ' · ${internship.location}' : ''}',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (internship.stipendRange != null)
                  Text(
                    internship.stipendRange!,
                    style: const TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                        fontSize: 11),
                  ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    internship.mode.toUpperCase(),
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }
}
