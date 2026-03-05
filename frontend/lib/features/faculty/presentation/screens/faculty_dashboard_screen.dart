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
              // ── Send Notification ──────────────────────────────────────
              IconButton(
                icon: const Icon(Icons.campaign_rounded, color: Colors.white),
                tooltip: 'Send Notification to Students',
                onPressed: () => _showBroadcastSheet(context, ref),
              ),
              IconButton(
                icon: const Icon(Icons.add, color: Colors.white),
                onPressed: () => context.push('/faculty/create-internship'),
              ),
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

  // ─── Broadcast Sheet ────────────────────────────────────────────────────────
  void _showBroadcastSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BroadcastSheet(ref: ref),
    );
  }
}

// ─── Broadcast Bottom Sheet ────────────────────────────────────────────────────
class _BroadcastSheet extends StatefulWidget {
  final WidgetRef ref;
  const _BroadcastSheet({required this.ref});

  @override
  State<_BroadcastSheet> createState() => _BroadcastSheetState();
}

class _BroadcastSheetState extends State<_BroadcastSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  bool _sending = false;
  String? _result;
  bool _success = false;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _sending = true;
      _result = null;
    });
    try {
      final resp = await widget.ref.read(dioClientProvider).dio.post(
        ApiConstants.broadcastNotification,
        data: {
          'title': _titleController.text.trim(),
          'message': _messageController.text.trim(),
        },
      );
      final sent = resp.data['sent_to'] as int? ?? 0;
      setState(() {
        _success = true;
        _result = 'Notification sent to $sent student${sent == 1 ? '' : 's'}!';
      });
    } catch (e) {
      setState(() {
        _success = false;
        _result = 'Failed to send: ${e.toString().split(']:').last.trim()}';
      });
    } finally {
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF0D1F33) : Colors.white;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.all(12),
      padding: EdgeInsets.fromLTRB(20, 24, 20, 20 + bottom),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.campaign_rounded,
                      color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Push Notification',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color:
                              isDark ? Colors.white : const Color(0xFF001820),
                        ),
                      ),
                      Text(
                        'Broadcast to all students',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white38 : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close,
                      color: isDark ? Colors.white38 : Colors.black38),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Title field
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Title',
                hintText: 'e.g. New Internship Available!',
                prefixIcon: Icon(Icons.title_rounded, color: AppColors.primary),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Title is required' : null,
              enabled: !_sending,
            ),
            const SizedBox(height: 12),

            // Message field
            TextFormField(
              controller: _messageController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Message',
                hintText: 'Write your message to students...',
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(bottom: 44),
                  child: Icon(Icons.message_rounded, color: AppColors.primary),
                ),
                alignLabelWithHint: true,
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Message is required' : null,
              enabled: !_sending,
            ),
            const SizedBox(height: 16),

            // Result banner
            if (_result != null)
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: _success
                      ? AppColors.success.withValues(alpha: 0.12)
                      : AppColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _success
                        ? AppColors.success.withValues(alpha: 0.4)
                        : AppColors.error.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _success
                          ? Icons.check_circle_rounded
                          : Icons.error_rounded,
                      color: _success ? AppColors.success : AppColors.error,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _result!,
                        style: TextStyle(
                          color: _success ? AppColors.success : AppColors.error,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Send button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(_sending ? 'Sending...' : 'Send to All Students'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: const Color(0xFF001820),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Internship Card ──────────────────────────────────────────────────────────
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
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPublished
              ? AppColors.success.withValues(alpha: 0.5)
              : Theme.of(context).brightness == Brightness.dark
                  ? Colors.white12
                  : Colors.black12,
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
                          style: TextStyle(
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
                  icon: Icon(Icons.edit,
                      size: 18,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5)),
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
