import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:internhub_app/core/constants/api_constants.dart';
import 'package:internhub_app/core/theme/app_colors.dart';
import 'package:internhub_app/features/auth/presentation/providers/auth_notifier.dart';

// ─── Providers ────────────────────────────────────────────────────────────────
final facultyInternshipsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(dioClientProvider);
  try {
    final resp = await client.dio.get(ApiConstants.facultyInternships);
    return List<Map<String, dynamic>>.from(resp.data as List);
  } catch (_) {
    return [];
  }
});

// ─── Screen ───────────────────────────────────────────────────────────────────
class FacultyDashboardScreen extends ConsumerWidget {
  const FacultyDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final internshipsAsync = ref.watch(facultyInternshipsProvider);

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
              IconButton(
                icon: const Icon(Icons.add, color: Colors.white),
                onPressed: () => context.push('/faculty/create-internship'),
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
                        Text('Faculty Portal',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold)),
                        Text('Manage Your Internship Postings',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          internshipsAsync.when(
            loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator())),
            error: (e, _) =>
                SliverFillRemaining(child: Center(child: Text('Error: $e'))),
            data: (internships) => internships.isEmpty
                ? SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.work_off_rounded,
                              size: 64, color: AppColors.textMuted),
                          const SizedBox(height: 16),
                          const Text('No internships yet',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          const Text('Tap + to create your first posting',
                              style: TextStyle(color: AppColors.textSecondary)),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () =>
                                context.push('/faculty/create-internship'),
                            icon: const Icon(Icons.add),
                            label: const Text('Create Internship'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) =>
                            _InternshipCard(data: internships[i], ref: ref),
                        childCount: internships.length,
                      ),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/faculty/create-internship'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Post Internship'),
      ),
    );
  }
}

class _InternshipCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final WidgetRef ref;
  const _InternshipCard({required this.data, required this.ref});

  @override
  Widget build(BuildContext context) {
    final isPublished = data['is_published'] as bool? ?? false;
    final appCount = data['applications_count'] as int? ?? 0;
    final skills = List<String>.from(data['required_skills'] as List? ?? []);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPublished
              ? AppColors.success.withValues(alpha: 0.5)
              : AppColors.border,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['title'] as String? ?? '',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(data['company_name'] as String? ?? '',
                          style: const TextStyle(
                              color: AppColors.primary, fontSize: 13)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPublished
                        ? AppColors.success.withValues(alpha: 0.12)
                        : AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    isPublished ? 'Live' : 'Draft',
                    style: TextStyle(
                      color:
                          isPublished ? AppColors.success : AppColors.warning,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (skills.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 6,
                children: skills
                    .take(4)
                    .map((s) => Chip(
                          label: Text(s, style: const TextStyle(fontSize: 11)),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: AppColors.bgElevated,
                          side: BorderSide.none,
                          padding: EdgeInsets.zero,
                        ))
                    .toList(),
              ),
            ),
          ],
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () async {
                    final id = data['id'] as String;
                    await ref
                        .read(dioClientProvider)
                        .dio
                        .post(ApiConstants.togglePublish(id));
                    ref.invalidate(facultyInternshipsProvider);
                  },
                  icon: Icon(
                    isPublished ? Icons.unpublished : Icons.publish,
                    size: 16,
                  ),
                  label: Text(isPublished ? 'Unpublish' : 'Publish'),
                ),
                TextButton.icon(
                  onPressed: () {
                    final id = data['id'] as String;
                    context.push('/faculty/internship/$id/applications');
                  },
                  icon: const Icon(Icons.people, size: 16),
                  label: Text('$appCount Applicants'),
                ),
                if (isPublished)
                  TextButton.icon(
                    onPressed: () {
                      final id = data['id'] as String;
                      context.push('/faculty/internship/$id/monitor');
                    },
                    icon: const Icon(Icons.videocam_outlined, size: 16),
                    label: const Text('Live Monitor'),
                  ),
                IconButton(
                  icon: const Icon(Icons.edit,
                      size: 18, color: AppColors.textSecondary),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
