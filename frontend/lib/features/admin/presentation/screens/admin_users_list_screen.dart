import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:internhub_app/core/constants/api_constants.dart';
import 'package:internhub_app/core/theme/app_colors.dart';
import 'package:internhub_app/features/admin/presentation/screens/admin_dashboard_screen.dart'; // import for the users list provider if possible
import 'package:internhub_app/features/auth/presentation/providers/auth_notifier.dart';
import 'package:intl/intl.dart';

// ─── Provider ─────────────────────────────────────────────────────────────────
final adminUsersListProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(dioClientProvider);
  try {
    final resp = await client.dio.get(ApiConstants.adminUsers);
    return List<Map<String, dynamic>>.from(resp.data['users'] as List);
  } catch (_) {
    return [];
  }
});

class AdminUsersListScreen extends ConsumerWidget {
  const AdminUsersListScreen({super.key});

  Future<void> _updateStatus(BuildContext context, WidgetRef ref, String userId,
      bool? isActive, bool? isVerified) async {
    try {
      final client = ref.read(dioClientProvider);

      final Map<String, dynamic> payload = {};
      if (isActive != null) payload['is_active'] = isActive;
      if (isVerified != null) payload['is_verified'] = isVerified;

      await client.dio.patch(
        ApiConstants.adminUserStatus(userId),
        data: payload,
      );

      ref.invalidate(adminUsersListProvider);
      // Also invalidate stats to keep the dashboard fresh when going back
      ref.invalidate(adminStatsProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('User status updated successfully'),
              backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error updating status: $e'),
              backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _updateRole(BuildContext context, WidgetRef ref, String userId,
      String newRole) async {
    try {
      final client = ref.read(dioClientProvider);
      await client.dio.patch(
        ApiConstants.adminUserRole(userId),
        data: {'role': newRole},
      );

      ref.invalidate(adminUsersListProvider);
      ref.invalidate(adminStatsProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('User role updated successfully'),
              backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error updating role: $e'),
              backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(adminUsersListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Users'),
        backgroundColor: AppColors.bgSurface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(adminUsersListProvider),
          )
        ],
      ),
      body: usersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (users) {
          if (users.isEmpty) {
            return const Center(child: Text('No users found.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            separatorBuilder: (context, index) => const Divider(height: 16),
            itemBuilder: (context, index) {
              final val = users[index];
              final String id = val['id'];
              final String email = val['email'];
              final String role = val['role'] ?? 'student';
              final bool isActive = val['is_active'] == true;
              final bool isVerified = val['is_verified'] == true;

              String dateText = 'Unknown';
              if (val['created_at'] != null) {
                try {
                  dateText = DateFormat('MMM dd, yyyy')
                      .format(DateTime.parse(val['created_at']).toLocal());
                } catch (_) {}
              }

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Header: Email + Joined date
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(email,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                                const SizedBox(height: 4),
                                Text('Joined: $dateText',
                                    style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getRoleColor(role).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              role.toUpperCase(),
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _getRoleColor(role)),
                            ),
                          )
                        ],
                      ),
                      const Divider(height: 24),
                      // Controls
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Account Active'),
                          Switch(
                            value: isActive,
                            activeColor: AppColors.success,
                            onChanged: (val) =>
                                _updateStatus(context, ref, id, val, null),
                          )
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Verified Status'),
                          Switch(
                            value: isVerified,
                            activeColor: AppColors.primary,
                            onChanged: (val) =>
                                _updateStatus(context, ref, id, null, val),
                          )
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Assign Role:'),
                          DropdownButton<String>(
                            value: role,
                            underline: const SizedBox(),
                            icon:
                                const Icon(Icons.keyboard_arrow_down, size: 20),
                            items: const [
                              DropdownMenuItem(
                                  value: 'student', child: Text('Student')),
                              DropdownMenuItem(
                                  value: 'faculty', child: Text('Faculty')),
                              DropdownMenuItem(
                                  value: 'admin', child: Text('Admin')),
                            ],
                            onChanged: (newRole) {
                              if (newRole != null && newRole != role) {
                                _updateRole(context, ref, id, newRole);
                              }
                            },
                          )
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _getRoleColor(String role) {
    if (role == 'admin') return AppColors.primary;
    if (role == 'faculty') return AppColors.info;
    return AppColors.success;
  }
}
