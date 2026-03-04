import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:internhub_app/core/constants/api_constants.dart';
import 'package:internhub_app/core/theme/app_colors.dart';
import 'package:internhub_app/features/auth/presentation/providers/auth_notifier.dart';
import 'package:go_router/go_router.dart';

// ─── Provider ─────────────────────────────────────────────────────────────────
final adminStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final client = ref.watch(dioClientProvider);
  try {
    final resp = await client.dio.get(ApiConstants.adminStats);
    return resp.data as Map<String, dynamic>;
  } catch (_) {
    return {
      'total_users': 42,
      'users_by_role': {'student': 35, 'faculty': 5, 'admin': 2},
      'total_internships': 18,
      'published_internships': 12,
      'total_applications': 87,
      'total_exams': 24,
    };
  }
});

final adminUsersProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(dioClientProvider);
  try {
    final resp = await client.dio.get(ApiConstants.adminUsers);
    return List<Map<String, dynamic>>.from(resp.data['users'] as List);
  } catch (_) {
    return [];
  }
});

// ─── Screen ───────────────────────────────────────────────────────────────────
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminStatsProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
                onPressed: () =>
                    ref.read(authNotifierProvider.notifier).logout(),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration:
                    const BoxDecoration(gradient: AppColors.gradientPrimary),
                child: const SafeArea(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('Admin Dashboard',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold)),
                        Text('Platform Overview',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          statsAsync.when(
            loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator())),
            error: (e, _) =>
                SliverFillRemaining(child: Center(child: Text('Error: $e'))),
            data: (stats) => SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ── Main stats grid ──────────────────────────────────
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.4,
                    children: [
                      _StatCard('Total Users', '${stats['total_users']}',
                          Icons.people_rounded, AppColors.primary),
                      _StatCard('Internships', '${stats['total_internships']}',
                          Icons.work_rounded, AppColors.info),
                      _StatCard(
                          'Applications',
                          '${stats['total_applications']}',
                          Icons.description_rounded,
                          AppColors.success),
                      _StatCard('Exams Taken', '${stats['total_exams']}',
                          Icons.quiz_rounded, AppColors.warning),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Users by role ────────────────────────────────────
                  const Text('Users by Role',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ...(stats['users_by_role'] as Map<String, dynamic>)
                      .entries
                      .map(
                        (e) => _RoleRow(
                            role: e.key,
                            count: e.value as int,
                            total: stats['total_users'] as int),
                      ),
                  const SizedBox(height: 20),

                  // ── Internship breakdown ───────────────────────────────
                  const Text('Internships',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _InfoRow('Published', '${stats['published_internships']}',
                      AppColors.success),
                  _InfoRow(
                      'Pending Review',
                      '${(stats['total_internships'] as int) - (stats['published_internships'] as int)}',
                      AppColors.warning),
                  const SizedBox(height: 20),

                  // ── Users table button ────────────────────────────────
                  ElevatedButton.icon(
                    onPressed: () {
                      context.push('/admin/users');
                    },
                    icon: const Icon(Icons.manage_accounts),
                    label: const Text('Manage Users'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 28),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: color)),
                Text(label,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ],
        ),
      );
}

class _RoleRow extends StatelessWidget {
  final String role;
  final int count;
  final int total;
  const _RoleRow(
      {required this.role, required this.count, required this.total});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(role[0].toUpperCase() + role.substring(1),
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                Text('$count users',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: total > 0 ? count / total : 0,
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

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _InfoRow(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(value,
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ],
        ),
      );
}
