import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:internhub_app/core/network/dio_client.dart';
import 'package:internhub_app/features/auth/data/repositories/auth_repository.dart';
import 'package:internhub_app/features/auth/domain/entities/user.dart';

// ─── State ───────────────────────────────────────────────────────────────
abstract class AuthState {
  const AuthState();
}

class AuthStateInitial extends AuthState {
  const AuthStateInitial();
}

class AuthStateLoading extends AuthState {
  const AuthStateLoading();
}

class AuthStateAuthenticated extends AuthState {
  final User user;
  const AuthStateAuthenticated(this.user);
}

class AuthStateUnauthenticated extends AuthState {
  const AuthStateUnauthenticated();
}

class AuthStateError extends AuthState {
  final String message;
  const AuthStateError(this.message);
}

class AuthStateRegistered extends AuthState {
  const AuthStateRegistered();
}

// ─── Providers ────────────────────────────────────────────────────────────
final dioClientProvider = Provider<DioClient>((ref) => DioClient());

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(dioClientProvider));
});

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref.watch(authRepositoryProvider)),
);

// ─── Notifier ─────────────────────────────────────────────────────────────
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo;

  AuthNotifier(this._repo) : super(const AuthStateInitial()) {
    _init();
  }

  Future<void> _init() async {
    final valid = await _repo.hasValidSession();
    if (valid) {
      final user = await _repo.getCurrentUser();
      if (user != null) {
        state = AuthStateAuthenticated(user);
        return;
      }
    }
    state = const AuthStateUnauthenticated();
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = const AuthStateLoading();
    try {
      final result = await _repo.login(email: email, password: password);
      final user = User.fromJson(result['user'] as Map<String, dynamic>);
      state = AuthStateAuthenticated(user);
    } on AuthException catch (e) {
      state = AuthStateError(e.message);
    } catch (e) {
      state = AuthStateError('Unexpected error: $e');
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String fullName,
    String role = 'student',
    String? usn,
  }) async {
    state = const AuthStateLoading();
    try {
      await _repo.register(
        email: email,
        password: password,
        fullName: fullName,
        role: role,
        usn: usn,
      );
      state = const AuthStateRegistered();
    } on AuthException catch (e) {
      state = AuthStateError(e.message);
    } catch (e) {
      state = AuthStateError('Unexpected error: $e');
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthStateUnauthenticated();
  }

  Future<void> forgotPassword(String email) async {
    state = const AuthStateLoading();
    try {
      await _repo.forgotPassword(email);
      state = const AuthStateUnauthenticated();
    } on AuthException catch (e) {
      state = AuthStateError(e.message);
    }
  }

  void clearError() {
    state = const AuthStateUnauthenticated();
  }

  /// Convenience getter: return the authenticated user or null
  User? get currentUser {
    final s = state;
    if (s is AuthStateAuthenticated) return s.user;
    return null;
  }
}
