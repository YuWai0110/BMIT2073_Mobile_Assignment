import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

const supabaseAuthRedirectUrl = 'bnmsme://login-callback';

class AuthRepository {
  final SupabaseService _service;

  const AuthRepository(this._service);

  User? get currentUser => _service.auth.currentUser;
  Session? get currentSession => _service.auth.currentSession;
  Stream<AuthState> get authStateChanges => _service.auth.onAuthStateChange;

  Future<User?> restoreUser() => _service.restoreUser();

  Future<AuthResponse> signUp({
    required String fullName,
    required String email,
    required String password,
    required String companyName,
    required String phone,
  }) {
    return _service.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: supabaseAuthRedirectUrl,
      data: {
        'full_name': fullName,
        'company_name': companyName,
        'phone': phone,
      },
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _service.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() => _service.auth.signOut();

  Future<void> sendPasswordReset(String email) {
    return _service.auth
        .resetPasswordForEmail(email, redirectTo: supabaseAuthRedirectUrl)
        .timeout(const Duration(seconds: 20));
  }

  Future<UserResponse> updatePassword(String password) {
    return _service.auth.updateUser(UserAttributes(password: password));
  }

  bool isBanker(User user) => user.appMetadata['role'] == 'banker';
}
