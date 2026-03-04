import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:internhub_app/core/theme/app_colors.dart';
import 'package:internhub_app/core/constants/api_constants.dart';
import 'package:internhub_app/features/auth/presentation/providers/auth_notifier.dart';
import 'package:internhub_app/features/internship/presentation/screens/internship_list_screen.dart';

class InternshipDetailScreen extends ConsumerWidget {
  final String internshipId;
  const InternshipDetailScreen({super.key, required this.internshipId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // In real implementation: fetch from API by ID
    final listAsync = ref.watch(internshipListProvider);

    return Scaffold(
      body: listAsync.when(
        data: (list) {
          final internship = list.firstWhere(
            (i) => i.id == internshipId,
            orElse: () => list.first,
          );
          return CustomScrollView(
            slivers: [
              _buildAppBar(context, internship),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(context, internship),
                      const SizedBox(height: 20),
                      _buildInfoCards(internship),
                      const SizedBox(height: 24),
                      _buildSection(
                        context,
                        'About the Role',
                        internship.description,
                      ),
                      const SizedBox(height: 20),
                      _buildSkillsSection(context, internship),
                      const SizedBox(height: 100), // Space for FAB
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: listAsync.isLoading ? null : () => _apply(context, ref),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.send_rounded, color: Colors.white),
        label: const Text(
          'Apply Now',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Future<void> _apply(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('Apply for Internship'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Write a quick cover letter (optional) explaining why you are a good fit.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'I believe my skills in...',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Submit Application',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(dioClientProvider).dio.post(
          '/api/v1/applications',
          data: {
            'internship_id': internshipId,
            if (ctrl.text.trim().isNotEmpty) 'cover_letter': ctrl.text.trim(),
          },
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Application submitted successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  SliverAppBar _buildAppBar(BuildContext context, InternshipModel internship) {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            color: AppColors.secondary,
            image: internship.posterUrl != null
                ? DecorationImage(
                    image: NetworkImage(
                        '${ApiConstants.baseUrl.replaceAll('/api/v1', '')}${internship.posterUrl}'),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(
                        Colors.black.withValues(alpha: 0.4), BlendMode.darken),
                  )
                : null,
            gradient: internship.posterUrl == null
                ? const LinearGradient(
                    colors: [AppColors.secondary, Color(0xFFFFE0A5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
          ),
          child: internship.posterUrl == null
              ? Center(
                  child: Text(
                    internship.companyName[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 72,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, InternshipModel i) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(i.title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 4),
        Text(
          i.companyName,
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCards(InternshipModel i) {
    final items = [
      if (i.location != null)
        _InfoItem(Icons.location_on_outlined, 'Location', i.location!),
      _InfoItem(Icons.work_outline_rounded, 'Mode', i.mode.toUpperCase()),
      if (i.stipendRange != null)
        _InfoItem(Icons.payments_outlined, 'Stipend', i.stipendRange!),
      if (i.minCgpa != null)
        _InfoItem(Icons.grade_outlined, 'Min CGPA', '${i.minCgpa}'),
      if (i.deadline != null)
        _InfoItem(Icons.calendar_today_rounded, 'Deadline', i.deadline!),
    ];

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.5,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: items.map((e) => _InfoCard(e)).toList(),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 10),
        Text(
          content,
          style: const TextStyle(
            color: AppColors.textSecondary,
            height: 1.6,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildSkillsSection(BuildContext context, InternshipModel i) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Required Skills',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: i.skills
              .map(
                (s) => Chip(
                  label: Text(s),
                  avatar: const Icon(
                    Icons.circle,
                    size: 8,
                    color: AppColors.primary,
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _InfoItem {
  final IconData icon;
  final String label;
  final String value;
  const _InfoItem(this.icon, this.label, this.value);
}

class _InfoCard extends StatelessWidget {
  final _InfoItem item;
  const _InfoCard(this.item);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(item.icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.label,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                  ),
                ),
                Text(
                  item.value,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
