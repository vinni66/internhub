import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:internhub_app/core/router/app_router.dart';
import 'package:internhub_app/core/theme/app_colors.dart';
import 'package:internhub_app/core/constants/api_constants.dart';
import 'package:internhub_app/features/auth/presentation/providers/auth_notifier.dart';
import 'package:internhub_app/features/internship/presentation/screens/internship_list_screen.dart';

// ─── Stats Provider ────────────────────────────────────────────────────────────
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

// ─── Screen ────────────────────────────────────────────────────────────────────
class StudentHomeScreen extends ConsumerStatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  ConsumerState<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends ConsumerState<StudentHomeScreen> {
  final PageController _pageController = PageController();
  int _currentBannerIndex = 0;
  int _bannerCount = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_bannerCount > 1 && _pageController.hasClients) {
        int next = (_currentBannerIndex + 1) % _bannerCount;
        _pageController.animateToPage(
          next,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final firstName = authState is AuthStateAuthenticated
        ? authState.user.email.split('@')[0]
        : 'there';
    final greeting = _greeting();
    final listAsync = ref.watch(internshipListProvider);
    final statsAsync = ref.watch(homeStatsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final surf = Theme.of(context).colorScheme.surface;

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          // ── Hero Greeting Header ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF061824), const Color(0xFF050D1A)]
                      : [const Color(0xFFE0FFFE), const Color(0xFFF0FEFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                      color: AppColors.primary,
                                      blurRadius: 6,
                                      spreadRadius: 1),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              greeting,
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Hello, $firstName 👋',
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF001820),
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your next opportunity awaits.',
                    style: TextStyle(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.45)
                          : const Color(0xFF005D6B).withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Stats Row ────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: statsAsync.when(
              data: (stats) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: Row(
                  children: [
                    _StatCard(
                      value: '${stats['internships'] ?? 0}',
                      label: 'Live Openings',
                      icon: Icons.work_outline_rounded,
                      accentColor: AppColors.primary,
                    ),
                    const SizedBox(width: 12),
                    _StatCard(
                      value: '${stats['applications'] ?? 0}',
                      label: 'Applied',
                      icon: Icons.send_rounded,
                      accentColor: AppColors.secondary,
                    ),
                  ],
                ),
              ),
              loading: () => _shimmerStats(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),

          // ── Hero Banner Slider ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: listAsync.when(
              data: (internships) {
                if (internships.isEmpty) return const SizedBox.shrink();
                final featured = internships.take(3).toList();
                _bannerCount = featured.length;
                return Column(
                  children: [
                    SizedBox(
                      height: 180,
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: featured.length,
                        onPageChanged: (idx) =>
                            setState(() => _currentBannerIndex = idx),
                        itemBuilder: (_, i) =>
                            _HeroBannerCard(internship: featured[i]),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        featured.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: _currentBannerIndex == index ? 20 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _currentBannerIndex == index
                                ? AppColors.primary
                                : AppColors.primary.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(3),
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

          // ── Quick Actions ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : const Color(0xFF001820),
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(
                    child: _QuickAction(
                      title: 'Apply\nInternship',
                      icon: Icons.school_rounded,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00F7FF), Color(0xFF0096A0)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      onTap: () => context.go(AppRoutes.internships),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickAction(
                      title: 'Take\nTest',
                      icon: Icons.assignment_turned_in_rounded,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF0087), Color(0xFF8B004A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      onTap: () => context.go(
                          '${AppRoutes.exam}/00000000-0000-0000-0000-000000000001?title=AI+Proctored+Exam'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickAction(
                      title: 'My\nResults',
                      icon: Icons.bar_chart_rounded,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7C3AED), Color(0xFF4C1D95)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      onTap: () => context.go(AppRoutes.analytics),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickAction(
                      title: 'AI\nAdvise',
                      icon: Icons.auto_awesome_rounded,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF059669), Color(0xFF064E3B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      onTap: () => context.go(AppRoutes.recommendations),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 28)),

          // ── Recent Openings header ─────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Openings',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white70 : const Color(0xFF001820),
                      letterSpacing: 0.3,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.go(AppRoutes.internships),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        'See all',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          // ── Internship Cards ───────────────────────────────────────────
          listAsync.when(
            data: (internships) {
              if (internships.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.work_off_rounded,
                            size: 48,
                            color: isDark ? Colors.white24 : Colors.black26),
                        const SizedBox(height: 8),
                        Text(
                          'No internships posted yet',
                          style: TextStyle(
                              color: isDark ? Colors.white38 : Colors.black38),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _InternshipCard(
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
    if (hour < 12) return 'GOOD MORNING';
    if (hour < 17) return 'GOOD AFTERNOON';
    return 'GOOD EVENING';
  }

  Widget _shimmerStats() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Shimmer.fromColors(
        baseColor: AppColors.bgElevated,
        highlightColor: AppColors.bgCard,
        child: Row(
          children: List.generate(
            2,
            (_) => Expanded(
              child: Container(
                height: 72,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16)),
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
        height: 180,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Widget _shimmerCard() {
    return Shimmer.fromColors(
      baseColor: AppColors.bgElevated,
      highlightColor: AppColors.bgCard,
      child: Container(
        height: 76,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

// ─── Stat Card ─────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color accentColor;

  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accentColor.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: accentColor, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: isDark ? Colors.white38 : Colors.black45,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Quick Action Tile ─────────────────────────────────────────────────────────
class _QuickAction extends StatelessWidget {
  final String title;
  final IconData icon;
  final LinearGradient gradient;
  final VoidCallback onTap;

  const _QuickAction({
    required this.title,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradient.colors.first.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 26),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Hero Banner Card ──────────────────────────────────────────────────────────
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
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFF0A1F35), Color(0xFF071526)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.25), width: 1),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
          image: internship.posterUrl != null
              ? DecorationImage(
                  image: NetworkImage(
                      '${ApiConstants.baseUrl.replaceAll('/api/v1', '')}${internship.posterUrl}'),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                      Colors.black.withValues(alpha: 0.55), BlendMode.darken),
                )
              : null,
        ),
        child: Stack(
          children: [
            // Cyan glow top-right
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      internship.companyName.toUpperCase(),
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    internship.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () =>
                            context.go('/internships/${internship.id}'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'View Details',
                            style: TextStyle(
                              color: Color(0xFF001820),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      if (internship.stipendRange != null) ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          child: Text(
                            internship.stipendRange!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
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

// ─── Internship List Card ──────────────────────────────────────────────────────
class _InternshipCard extends StatelessWidget {
  final InternshipModel internship;
  final VoidCallback onTap;

  const _InternshipCard({required this.internship, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final modeColors = {
      'remote': AppColors.success,
      'onsite': AppColors.secondary,
      'hybrid': AppColors.primary,
    };
    final modeColor =
        modeColors[internship.mode.toLowerCase()] ?? AppColors.primary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.07),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.8),
                    AppColors.primaryDark.withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  internship.companyName.isNotEmpty
                      ? internship.companyName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Color(0xFF001820),
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    internship.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isDark ? Colors.white : const Color(0xFF001820),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${internship.companyName}${internship.location != null ? ' · ${internship.location}' : ''}',
                    style: TextStyle(
                      color: isDark ? Colors.white38 : Colors.black45,
                      fontSize: 12,
                    ),
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
                    style: TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: modeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: modeColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    internship.mode.toUpperCase(),
                    style: TextStyle(
                      color: modeColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: isDark ? Colors.white24 : Colors.black26,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}
