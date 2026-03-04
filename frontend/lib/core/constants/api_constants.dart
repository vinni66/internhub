import 'package:flutter/foundation.dart';

class ApiConstants {
  // ── Base ──────────────────────────────────────────────────────────────
  static String get baseUrl {
    if (kIsWeb) {
      return 'https://internhub-bn09.onrender.com/api/v1';
    }
    // Android emulator uses 10.0.2.2 to reach host machine.
    // Real physical Android/iOS devices must use the live server.
    return 'https://internhub-bn09.onrender.com/api/v1';
  }

  // ── Auth ──────────────────────────────────────────────────────────────
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String refreshToken = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String forgotPassword = '/auth/forgot-password';
  static const String getMe = '/auth/me';

  // ── Student / Profile ─────────────────────────────────────────────────
  static const String studentProfile = '/students/me';
  static const String updateProfile = '/students/me';

  // ── Internships ───────────────────────────────────────────────────────
  static const String internships = '/internships';
  static String internshipDetail(String id) => '/internships/$id';

  // ── Applications ──────────────────────────────────────────────────────
  static const String applyInternship = '/applications';
  static const String myApplications = '/applications/me';
  static String internshipApplications(String id) =>
      '/applications/internship/$id';
  static String updateApplicationStatus(String id) =>
      '/applications/$id/status';
  static String withdrawApplication(String id) => '/applications/$id/withdraw';

  // ── Faculty ───────────────────────────────────────────────────────────
  static const String facultyInternships = '/faculty/internships';
  static String facultyInternshipDetail(String id) =>
      '/faculty/internships/$id';
  static String togglePublish(String id) => '/faculty/internships/$id/publish';
  static String facultyApplicants(String id) =>
      '/faculty/internships/$id/applications';
  static String facultyActiveSessions(String id) =>
      '/faculty/internships/$id/sessions/active';
  static String facultySessionEvents(String id) =>
      '/faculty/sessions/$id/events';
  static String facultyOverrideFlag(String id) =>
      '/faculty/sessions/$id/override';

  // ── Admin ─────────────────────────────────────────────────────────────
  static const String adminStats = '/admin/stats';
  static const String adminUsers = '/admin/users';
  static String adminUserStatus(String id) => '/admin/users/$id/status';
  static String adminUserRole(String id) => '/admin/users/$id/role';
  static String adminModerateInternship(String id) =>
      '/admin/internships/$id/moderate';

  // ── Exam ──────────────────────────────────────────────────────────────
  static const String examSessions = '/exam/sessions';
  static String examSessionDetail(String id) => '/exam/sessions/$id';
  static String examQuestions(String id) => '/exam/sessions/$id/questions';
  static String submitAnswer(String id) => '/exam/sessions/$id/answers';
  static String submitExam(String id) => '/exam/sessions/$id/submit';
  static String proctorEvents(String id) => '/exam/sessions/$id/proctor-events';

  // ── Recommendations ───────────────────────────────────────────────────
  static const String recommendations = '/recommend/internships';
  static const String skillGaps = '/recommend/skill-gaps';
  static const String careerRoadmap = '/recommend/career-roadmap';

  // ── Analytics ─────────────────────────────────────────────────────────
  static const String analyticsMe = '/analytics/me';

  // ── External Jobs (Adzuna proxy) ────────────────────────────────
  static const String adzunaJobs = '/jobs/adzuna';

  // ── Secure Storage Keys ───────────────────────────────────────────────
  static const String kAccessToken = 'access_token';
  static const String kRefreshToken = 'refresh_token';
  static const String kUserData = 'user_data';

  // ── Exam constants ────────────────────────────────────────────────────
  static const int defaultExamDurationMinutes = 60;
  static const int maxProctorWarnings = 3;
}
