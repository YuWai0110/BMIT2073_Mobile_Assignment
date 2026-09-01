import 'package:supabase_flutter/supabase_flutter.dart';

class SessionUnavailableException implements Exception {
  final String message;

  const SessionUnavailableException([
    this.message = 'Your session has expired. Please sign in again.',
  ]);

  @override
  String toString() => message;
}

class SupabaseService {
  final SupabaseClient client;

  const SupabaseService(this.client);

  GoTrueClient get auth => client.auth;
  SupabaseQueryBuilder get profiles => client.from('profiles');
  SupabaseQueryBuilder get loanApplications => client.from('loan_applications');

  Future<User?> restoreUser() async {
    final session = auth.currentSession;
    if (session == null) return null;
    if (!session.isExpired) return session.user;

    try {
      final response = await auth.refreshSession();
      final refreshedSession = response.session;
      if (refreshedSession == null) {
        throw const SessionUnavailableException();
      }
      return refreshedSession.user;
    } catch (_) {
      await _clearInvalidSession();
      throw const SessionUnavailableException();
    }
  }

  Future<T> withSessionRecovery<T>(Future<T> Function() operation) async {
    final session = auth.currentSession;
    if (session == null) {
      throw const SessionUnavailableException();
    }

    if (session.isExpired) {
      try {
        await auth.refreshSession();
      } catch (_) {
        await _clearInvalidSession();
        throw const SessionUnavailableException();
      }
    }

    try {
      return await operation();
    } on PostgrestException catch (error) {
      if (!isJwtSessionError(error)) rethrow;
      try {
        final response = await auth.refreshSession();
        if (response.session == null) {
          throw const SessionUnavailableException();
        }
      } catch (_) {
        await _clearInvalidSession();
        throw const SessionUnavailableException();
      }
      try {
        return await operation();
      } on PostgrestException catch (retryError) {
        if (!isJwtSessionError(retryError)) rethrow;
        await _clearInvalidSession();
        throw const SessionUnavailableException();
      }
    }
  }

  Future<void> _clearInvalidSession() async {
    try {
      await auth.signOut(scope: SignOutScope.local);
    } catch (_) {}
  }
}

bool isJwtSessionError(PostgrestException error) {
  final message = error.message.toLowerCase();
  return error.code == 'PGRST303' ||
      message.contains('jwt issued at future') ||
      message.contains('jwt expired') ||
      message.contains('invalid jwt');
}

String friendlySupabaseError(
  Object error, {
  String fallback = 'Unable to complete the request. Please try again.',
}) {
  if (error is SessionUnavailableException) return error.message;
  if (error is AuthException) {
    final message = error.message.toLowerCase();
    if (message.contains('invalid login credentials')) {
      return 'Email or password is incorrect.';
    }
    if (message.contains('email not confirmed')) {
      return 'Please confirm your email before signing in.';
    }
    if (message.contains('user already registered')) {
      return 'An account with this email already exists.';
    }
    if (message.contains('refresh token') || message.contains('jwt')) {
      return 'Your session has expired. Please sign in again.';
    }
    return 'Authentication failed. Please check your details and try again.';
  }
  if (error is PostgrestException) {
    if (isJwtSessionError(error)) {
      return 'Your session has expired. Please sign in again.';
    }
    return 'Unable to load cloud data right now. Please try again.';
  }
  return fallback;
}
