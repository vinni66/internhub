import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:internhub_app/core/constants/api_constants.dart';
import 'package:internhub_app/core/network/dio_client.dart';
import 'package:internhub_app/core/security/secure_storage.dart';
import 'package:internhub_app/features/auth/domain/entities/user.dart';

class AuthException implements Exception {
  final String message;
  final int? statusCode;
  AuthException(this.message, {this.statusCode});

  @override
  String toString() => 'AuthException: $message';
}

class AuthRepository {
  final DioClient _client;

  AuthRepository(this._client);

  // ─── Login ──────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final resp = await _client.dio.post(
        ApiConstants.login,
        data: {'email': email, 'password': password},
      );
      final data = resp.data as Map<String, dynamic>;

      // Persist tokens
      if (data['access_token'] != null) {
        await SecureStorageService.saveAccessToken(
            data['access_token'] as String);
      }
      if (data['refresh_token'] != null) {
        await SecureStorageService.saveRefreshToken(
            data['refresh_token'] as String);
      }
      if (data['user'] != null) {
        await SecureStorageService.saveUser(jsonEncode(data['user']));
      }
      return data;
    } on DioException catch (e) {
      throw AuthException(
        _mapErrorCode(e.response?.data?['code'] as String?),
        statusCode: e.response?.statusCode,
      );
    }
  }

  // ─── Register ───────────────────────────────────────────────────────
  Future<void> register({
    required String email,
    required String password,
    required String fullName,
    String role = 'student',
    String? usn,
  }) async {
    try {
      await _client.dio.post(
        ApiConstants.register,
        data: {
          'email': email,
          'password': password,
          'full_name': fullName,
          'role': role,
          if (usn != null) 'usn': usn,
        },
      );
    } on DioException catch (e) {
      throw AuthException(
        _mapErrorCode(e.response?.data?['code'] as String?),
        statusCode: e.response?.statusCode,
      );
    }
  }

  // ─── Logout ─────────────────────────────────────────────────────────
  Future<void> logout() async {
    try {
      final refreshToken = await SecureStorageService.getRefreshToken();
      if (refreshToken != null) {
        await _client.dio.post(
          ApiConstants.logout,
          data: {'refresh_token': refreshToken},
        );
      }
    } catch (_) {
      // Ignore logout API errors — always clear local storage
    } finally {
      await SecureStorageService.clearAll();
    }
  }

  // ─── Forgot Password ─────────────────────────────────────────────────
  Future<void> forgotPassword(String email) async {
    try {
      await _client.dio.post(
        ApiConstants.forgotPassword,
        data: {'email': email},
      );
    } on DioException catch (e) {
      throw AuthException(
        _mapErrorCode(e.response?.data?['code'] as String?),
      );
    }
  }

  // ─── Session helpers ─────────────────────────────────────────────────
  Future<bool> hasValidSession() async {
    final token = await SecureStorageService.getAccessToken();
    return token != null && token.isNotEmpty;
  }

  Future<User?> getCurrentUser() async {
    final json = await SecureStorageService.getUser();
    if (json == null) return null;
    try {
      return User.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  // ─── Error mapper ────────────────────────────────────────────────────
  String _mapErrorCode(String? code) => switch (code) {
        'USER_NOT_FOUND' => 'No account found with this email.',
        'INVALID_PASSWORD' => 'Incorrect password. Please try again.',
        'EMAIL_EXISTS' => 'An account with this email already exists.',
        'EMAIL_NOT_VERIFIED' => 'Please verify your email before logging in.',
        'ACCOUNT_DISABLED' => 'Your account has been suspended.',
        'INVALID_TOKEN' => 'Your session has expired. Please log in again.',
        _ => 'Something went wrong. Please try again.',
      };
}
