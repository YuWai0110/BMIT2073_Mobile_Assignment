import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'profile_manager.dart';

import '../../services/supabase/auth_repository.dart';
import '../../services/supabase/profile_repository.dart';
import '../../services/supabase/supabase_service.dart';

class UserAccount {
  final String id;
  String fullName;
  final String email;
  String companyName;
  String phone;

  UserAccount({
    required this.id,
    required this.fullName,
    required this.email,
    this.companyName = '',
    this.phone = '',
  });

  factory UserAccount.fromProfile(User user, Map<String, dynamic>? profile) {
    return UserAccount(
      id: user.id,
      fullName:
          profile?['full_name'] as String? ??
          user.userMetadata?['full_name'] as String? ??
          'SME User',
      email: profile?['email'] as String? ?? user.email ?? '',
      companyName:
          profile?['company_name'] as String? ??
          user.userMetadata?['company_name'] as String? ??
          '',
      phone:
          profile?['phone'] as String? ??
          user.userMetadata?['phone'] as String? ??
          '',
    );
  }

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
  }
}

class AuthManager extends ChangeNotifier {
  ProfileManager? _profileManager;
  ProfileManager get profileManager => _profileManager ??= ProfileManager(this);
  final AuthRepository? _authRepository;
  final ProfileRepository? _profileRepository;
  final Future<void> Function(UserAccount?)? _authChangedCallback;
  StreamSubscription<AuthState>? _authSubscription;
  UserAccount? _currentUser;
  bool _isBanker = false;
  bool _isInitialized = false;
  int _profileLoads = 0;
  bool _isAuthenticating = false;
  bool _isPasswordRecovery = false;
  String? _notice;

  AuthManager(
    this._authRepository,
    this._profileRepository, {
    Future<void> Function(UserAccount?)? onAuthenticationChanged,
  }) : _authChangedCallback = onAuthenticationChanged;

  AuthManager.forTesting({bool loggedIn = false, bool banker = false})
    : _authRepository = null,
      _profileRepository = null,
      _authChangedCallback = null {
    if (loggedIn) {
      _currentUser = UserAccount(
        id: banker ? 'banker_test' : 'sme_test',
        fullName: banker ? 'BNM Banker' : 'Test SME User',
        email: banker ? 'banker@example.com' : 'sme@example.com',
        companyName: banker ? 'Bank Negara Malaysia' : 'Test Company',
        phone: '+60-12-345-6789',
      );
      _isBanker = banker;
    }
  }

  UserAccount? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isBanker => _isBanker;
  bool get isInitialized => _isInitialized;
  bool get isProfileLoading => _profileLoads > 0;
  bool get isPasswordRecovery => _isPasswordRecovery;

  String? takeNotice() {
    final notice = _notice;
    _notice = null;
    return notice;
  }

  Future<void> initialize() async {
    final repository = _authRepository;
    if (repository == null) {
      _isInitialized = true;
      return;
    }

    try {
      final user = await repository.restoreUser();
      if (user != null) {
        await _loadUser(user);
      }
    } catch (error) {
      _notice = _messageFor(error);
      _currentUser = null;
      _isBanker = false;
    }

    _authSubscription = repository.authStateChanges.listen((state) {
      unawaited(_handleAuthState(state));
    });
    _isInitialized = true;
    notifyListeners();
  }

  Future<String?> signUp({
    required String fullName,
    required String email,
    required String password,
    String companyName = '',
    String phone = '',
  }) async {
    final repository = _authRepository;
    if (repository == null) return 'Supabase is not configured.';

    _isAuthenticating = true;
    try {
      final response = await repository.signUp(
        fullName: fullName.trim(),
        email: email.trim().toLowerCase(),
        password: password,
        companyName: companyName.trim(),
        phone: phone.trim(),
      );
      if (response.session != null && response.user != null) {
        await _loadUser(response.user!);
        await _notifyAuthenticationChanged();
      }
      return null;
    } catch (error) {
      return _messageFor(error);
    } finally {
      _isAuthenticating = false;
    }
  }

  Future<String?> login({
    required String email,
    required String password,
  }) async {
    final repository = _authRepository;
    if (repository == null) return 'Supabase is not configured.';

    _isAuthenticating = true;
    try {
      final response = await repository.signIn(
        email: email.trim().toLowerCase(),
        password: password,
      );
      final user = response.user;
      if (user == null) return 'Unable to sign in. Please try again.';
      await _loadUser(user);
      await _notifyAuthenticationChanged();
      return null;
    } catch (error) {
      return _messageFor(error);
    } finally {
      _isAuthenticating = false;
    }
  }

  Future<String?> bankerLogin({
    required String email,
    required String password,
  }) async {
    final repository = _authRepository;
    if (repository == null) return 'Supabase is not configured.';

    _isAuthenticating = true;
    try {
      final response = await repository.signIn(
        email: email.trim().toLowerCase(),
        password: password,
      );
      final user = response.user;
      if (user == null) return 'Unable to sign in. Please try again.';
      if (!repository.isBanker(user)) {
        await repository.signOut();
        return 'This account does not have banker access.';
      }
      await _loadUser(user);
      await _notifyAuthenticationChanged();
      return null;
    } catch (error) {
      return _messageFor(error);
    } finally {
      _isAuthenticating = false;
    }
  }

  Future<void> logout() async {
    final repository = _authRepository;
    _isAuthenticating = true;
    try {
      if (repository != null) {
        await repository.signOut();
      }
      _currentUser = null;
      _isBanker = false;
      notifyListeners();
      await _notifyAuthenticationChanged();
    } finally {
      _isAuthenticating = false;
    }
  }

  Future<String?> updateProfile({
    String? fullName,
    String? companyName,
    String? phone,
  }) async {
    final user = _currentUser;
    final repository = _profileRepository;
    if (user == null || repository == null) {
      return 'Profile is not available.';
    }
    if (_isBanker) return 'Banker profiles cannot be edited in the app.';

    try {
      final profile = await repository.update(
        userId: user.id,
        fullName: fullName?.trim() ?? user.fullName,
        companyName: companyName?.trim() ?? user.companyName,
        phone: phone?.trim() ?? user.phone,
      );
      _currentUser = UserAccount(
        id: user.id,
        fullName: profile['full_name'] as String? ?? user.fullName,
        email: profile['email'] as String? ?? user.email,
        companyName: profile['company_name'] as String? ?? user.companyName,
        phone: profile['phone'] as String? ?? user.phone,
      );
      notifyListeners();
      return null;
    } catch (error) {
      return _messageFor(error);
    }
  }

  Future<void> refreshProfile() async {
    final user = _authRepository?.currentUser;
    if (user == null) return;
    await _loadUser(user);
  }

  Future<String?> resetPassword({required String email}) async {
    final repository = _authRepository;
    if (repository == null) return 'Supabase is not configured.';

    try {
      await repository.sendPasswordReset(email.trim().toLowerCase());
      return null;
    } catch (error) {
      return friendlyPasswordResetError(error);
    }
  }

  Future<String?> updateRecoveredPassword(String password) async {
    final repository = _authRepository;
    if (repository == null) return 'Supabase is not configured.';
    if (!_isPasswordRecovery || repository.currentSession == null) {
      return 'This password reset link is invalid or has expired.';
    }

    _isAuthenticating = true;
    try {
      await repository.updatePassword(password);
      return null;
    } catch (error) {
      return _messageFor(error);
    } finally {
      _isAuthenticating = false;
    }
  }

  Future<void> completePasswordRecovery() async {
    final repository = _authRepository;
    _isAuthenticating = true;
    try {
      if (repository != null) {
        await repository.signOut();
      }
      _isPasswordRecovery = false;
      _currentUser = null;
      _isBanker = false;
      notifyListeners();
      await _notifyAuthenticationChanged();
    } finally {
      _isAuthenticating = false;
    }
  }

  Future<void> _handleAuthState(AuthState state) async {
    if (state.event == AuthChangeEvent.passwordRecovery) {
      _isPasswordRecovery = true;
      notifyListeners();
      return;
    }
    if (_isAuthenticating) return;
    final user = _authRepository?.currentUser;
    if (user == null) {
      if (_currentUser != null) {
        _isPasswordRecovery = false;
        _currentUser = null;
        _isBanker = false;
        notifyListeners();
        await _notifyAuthenticationChanged();
      }
      return;
    }

    if (_currentUser?.id != user.id) {
      try {
        await _loadUser(user);
        await _notifyAuthenticationChanged();
      } catch (error) {
        _notice = _messageFor(error);
        _currentUser = null;
        _isBanker = false;
        notifyListeners();
        await _notifyAuthenticationChanged();
      }
    }
  }

  Future<void> _loadUser(User user) async {
    _profileLoads++;
    notifyListeners();
    try {
      Map<String, dynamic>? profile;
      final repository = _profileRepository;
      if (repository != null) {
        profile = await repository.findById(user.id);
        profile ??= await repository.save(
          id: user.id,
          fullName: user.userMetadata?['full_name'] as String? ?? 'SME User',
          companyName: user.userMetadata?['company_name'] as String? ?? '',
          phone: user.userMetadata?['phone'] as String? ?? '',
          email: user.email ?? '',
        );
      }
      _currentUser = UserAccount.fromProfile(user, profile);
      _isBanker = _authRepository?.isBanker(user) ?? false;
      notifyListeners();
    } finally {
      _profileLoads--;
      notifyListeners();
    }
  }

  Future<void> _notifyAuthenticationChanged() async {
    await _authChangedCallback?.call(_currentUser);
  }

  String _messageFor(Object error) {
    return friendlySupabaseError(error);
  }

  @override
  void dispose() {
    _profileManager?.dispose();
    unawaited(_authSubscription?.cancel());
    super.dispose();
  }
}
