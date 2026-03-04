import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:internhub_app/core/constants/api_constants.dart';

import 'package:internhub_app/features/auth/presentation/providers/auth_notifier.dart';

// ─── Models ───────────────────────────────────────────────────────────────────
class StudentProfileData {
  final String id;
  final String fullName;
  final String? usn;
  final String? department;
  final int? semester;
  final double? cgpa;
  final List<String> skills;
  final List<String> interests;
  final String? bio;
  final String? linkedinUrl;
  final String? githubUrl;
  final String? portfolioUrl;

  const StudentProfileData({
    required this.id,
    required this.fullName,
    this.usn,
    this.department,
    this.semester,
    this.cgpa,
    this.skills = const [],
    this.interests = const [],
    this.bio,
    this.linkedinUrl,
    this.githubUrl,
    this.portfolioUrl,
  });

  factory StudentProfileData.fromJson(Map<String, dynamic> j) =>
      StudentProfileData(
        id: j['id'] as String? ?? '',
        fullName: j['full_name'] as String? ?? '',
        usn: j['usn'] as String?,
        department: j['department'] as String?,
        semester: j['semester'] as int?,
        cgpa: (j['cgpa'] as num?)?.toDouble(),
        skills: List<String>.from(j['skills'] as List? ?? []),
        interests: List<String>.from(j['interests'] as List? ?? []),
        bio: j['bio'] as String?,
        linkedinUrl: j['linkedin_url'] as String?,
        githubUrl: j['github_url'] as String?,
        portfolioUrl: j['portfolio_url'] as String?,
      );
}

// ─── Provider ─────────────────────────────────────────────────────────────────
final profileProvider =
    StateNotifierProvider<ProfileNotifier, AsyncValue<StudentProfileData>>(
        (ref) {
  return ProfileNotifier(ref.watch(dioClientProvider));
});

class ProfileNotifier extends StateNotifier<AsyncValue<StudentProfileData>> {
  final dynamic _client;
  ProfileNotifier(this._client) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    try {
      final resp = await _client.dio.get(ApiConstants.studentProfile);
      state = AsyncValue.data(
          StudentProfileData.fromJson(resp.data as Map<String, dynamic>));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> update(Map<String, dynamic> data) async {
    try {
      final resp =
          await _client.dio.patch(ApiConstants.updateProfile, data: data);
      state = AsyncValue.data(
          StudentProfileData.fromJson(resp.data as Map<String, dynamic>));
      return true;
    } catch (_) {
      return false;
    }
  }
}
