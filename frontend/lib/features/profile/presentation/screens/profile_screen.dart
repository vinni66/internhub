import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:internhub_app/core/theme/app_colors.dart';
import 'package:internhub_app/features/auth/presentation/providers/auth_notifier.dart';
import 'package:internhub_app/features/profile/presentation/providers/profile_notifier.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState is AuthStateAuthenticated ? authState.user : null;
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              if (profileAsync.valueOrNull != null) {
                _showEditSheet(context, ref, profileAsync.valueOrNull!);
              }
            },
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (profile) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              // ─── Avatar ──────────────────────────────────────────────
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: AppColors.gradientPrimary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    (profile.fullName.isNotEmpty
                            ? profile.fullName
                            : (user?.email ?? 'U'))
                        .substring(0, 1)
                        .toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                profile.fullName.isEmpty
                    ? 'Set up your profile'
                    : profile.fullName,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  (user?.role ?? 'student').toUpperCase(),
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12),
                ),
              ),
              const SizedBox(height: 28),

              // ─── Info Cards ───────────────────────────────────────────
              _ProfileSection(
                title: 'Account',
                items: [
                  _ProfileItem(
                      icon: Icons.email_outlined,
                      label: 'Email',
                      value: user?.email ?? '-'),
                  _ProfileItem(
                      icon: Icons.verified_outlined,
                      label: 'Verified',
                      value: user?.isVerified == true ? 'Yes' : 'No'),
                  _ProfileItem(
                      icon: Icons.badge_outlined,
                      label: 'Role',
                      value: user?.role ?? 'Student'),
                ],
              ),
              const SizedBox(height: 16),

              _ProfileSection(
                title: 'Academic',
                items: [
                  _ProfileItem(
                      icon: Icons.badge_outlined,
                      label: 'USN',
                      value: profile.usn ?? 'Not set'),
                  _ProfileItem(
                      icon: Icons.business_outlined,
                      label: 'Department',
                      value: profile.department ?? 'Not set'),
                  _ProfileItem(
                      icon: Icons.grade_outlined,
                      label: 'CGPA',
                      value: profile.cgpa?.toString() ?? 'Not set'),
                ],
              ),
              const SizedBox(height: 16),

              _ProfileSection(
                title: 'Skills',
                items: [
                  _ProfileItem(
                      icon: Icons.code_rounded,
                      label: 'Top Skills',
                      value: profile.skills.isNotEmpty
                          ? profile.skills.join(', ')
                          : 'Not set'),
                ],
              ),
              const SizedBox(height: 32),

              // ─── Logout ───────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: AppColors.bgCard,
                        title: const Text('Sign Out?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.error),
                            child: const Text('Sign Out',
                                style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await ref.read(authNotifierProvider.notifier).logout();
                    }
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Sign Out'),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditSheet(
      BuildContext context, WidgetRef ref, StudentProfileData currentData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (ctx, scroll) => _EditProfileForm(
            data: currentData,
            scrollController: scroll,
          ),
        ),
      ),
    );
  }
}

class _EditProfileForm extends ConsumerStatefulWidget {
  final StudentProfileData data;
  final ScrollController scrollController;
  const _EditProfileForm({required this.data, required this.scrollController});

  @override
  ConsumerState<_EditProfileForm> createState() => _EditProfileFormState();
}

class _EditProfileFormState extends ConsumerState<_EditProfileForm> {
  late TextEditingController _nameCtrl;
  late TextEditingController _usnCtrl;
  late TextEditingController _deptCtrl;
  late TextEditingController _cgpaCtrl;
  late TextEditingController _skillsCtrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.data.fullName);
    _usnCtrl = TextEditingController(text: widget.data.usn ?? '');
    _deptCtrl = TextEditingController(text: widget.data.department ?? '');
    _cgpaCtrl = TextEditingController(text: widget.data.cgpa?.toString() ?? '');
    _skillsCtrl = TextEditingController(text: widget.data.skills.join(', '));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usnCtrl.dispose();
    _deptCtrl.dispose();
    _cgpaCtrl.dispose();
    _skillsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    final skillsList = _skillsCtrl.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final cgpa = double.tryParse(_cgpaCtrl.text);

    final success = await ref.read(profileProvider.notifier).update({
      'full_name': _nameCtrl.text.trim(),
      'usn': _usnCtrl.text.trim(),
      'department': _deptCtrl.text.trim(),
      if (cgpa != null) 'cgpa': cgpa,
      'skills': skillsList,
    });

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: AppColors.success,
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to update profile'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Edit Profile',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _nameCtrl,
          decoration: const InputDecoration(labelText: 'Full Name'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _usnCtrl,
          decoration: const InputDecoration(labelText: 'USN (Roll Number)'),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: _deptCtrl,
                decoration: const InputDecoration(labelText: 'Department'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 1,
              child: TextField(
                controller: _cgpaCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'CGPA'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _skillsCtrl,
          decoration: const InputDecoration(
            labelText: 'Skills (comma separated)',
            hintText: 'e.g. Flutter, Dart, Python',
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _save,
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save Changes'),
          ),
        ),
      ],
    );
  }
}

class _ProfileSection extends StatelessWidget {
  final String title;
  final List<_ProfileItem> items;
  const _ProfileSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Text(
                title,
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8),
              ),
            ),
            ...items.map((item) => _InfoRow(item: item)),
          ],
        ),
      );
}

class _ProfileItem {
  final IconData icon;
  final String label;
  final String value;
  const _ProfileItem(
      {required this.icon, required this.label, required this.value});
}

class _InfoRow extends StatelessWidget {
  final _ProfileItem item;
  const _InfoRow({required this.item});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          children: [
            Icon(item.icon, color: AppColors.textMuted, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.label,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(item.value,
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      );
}
