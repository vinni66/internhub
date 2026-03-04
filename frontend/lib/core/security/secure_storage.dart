import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:internhub_app/core/constants/api_constants.dart';

/// On mobile/desktop     → flutter_secure_storage (encrypted keychain/keystore)
/// On web (Chrome etc.)  → SharedPreferences (localStorage) as a fallback
///                         since flutter_secure_storage silently returns null on web.
class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ─── Low-level read/write ──────────────────────────────────────────────

  static Future<void> _write(String key, String value) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } else {
      await _storage.write(key: key, value: value);
    }
  }

  static Future<String?> _read(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    } else {
      return _storage.read(key: key);
    }
  }

  static Future<void> _deleteAll() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } else {
      await _storage.deleteAll();
    }
  }

  // ─── Tokens ──────────────────────────────────────────────────────────

  static Future<void> saveAccessToken(String token) =>
      _write(ApiConstants.kAccessToken, token);

  static Future<String?> getAccessToken() => _read(ApiConstants.kAccessToken);

  static Future<void> saveRefreshToken(String token) =>
      _write(ApiConstants.kRefreshToken, token);

  static Future<String?> getRefreshToken() => _read(ApiConstants.kRefreshToken);

  // ─── User ─────────────────────────────────────────────────────────────

  static Future<void> saveUser(String userJson) =>
      _write(ApiConstants.kUserData, userJson);

  static Future<String?> getUser() => _read(ApiConstants.kUserData);

  // ─── Clear ────────────────────────────────────────────────────────────

  static Future<void> clearAll() => _deleteAll();
}
