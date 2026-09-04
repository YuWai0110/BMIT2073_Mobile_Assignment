import 'dart:async';
import 'dart:io';

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

String friendlySignUpError(Object error) {
  if (error is TimeoutException ||
      (error is AuthUnknownException &&
          error.originalError is TimeoutException)) {
    return 'The request timed out. Please check your connection and try again.';
  }
  if (error is SocketException ||
      error is AuthRetryableFetchException ||
      (error is AuthUnknownException &&
          error.originalError is SocketException)) {
    return 'Unable to connect. Please check your internet connection and try again.';
  }
  if (error is AuthException) {
    final code = error.code ?? '';
    final message = error.message.toLowerCase();
    if (error.statusCode == '429' ||
        code == 'over_email_send_rate_limit' ||
        message.contains('rate limit') ||
        message.contains('too many requests')) {
      return 'Too many verification email requests. Please try again later.';
    }
    if (code == 'user_already_exists' ||
        code == 'email_exists' ||
        message.contains('already registered')) {
      return 'An account with this email already exists.';
    }
    if (code == 'email_address_invalid' ||
        code == 'email_address_not_authorized' ||
        message.contains('invalid email') ||
        message.contains('email address is invalid')) {
      return 'Please enter a valid email address.';
    }
    if (code == 'weak_password' || message.contains('password')) {
      return 'Password must contain at least 8 characters, one uppercase letter, one lowercase letter, and one number.';
    }
  }
  return 'Unable to create your account. Please try again.';
}

String friendlyPasswordResetError(Object error) {
  if (error is TimeoutException) {
    return 'The request timed out. Please check your connection and try again.';
  }
  if (error is SocketException || error is AuthRetryableFetchException) {
    return 'Unable to connect. Please check your internet connection and try again.';
  }
  if (error is AuthUnknownException) {
    final originalError = error.originalError;
    if (originalError is TimeoutException) {
      return 'The request timed out. Please check your connection and try again.';
    }
    if (originalError is SocketException) {
      return 'Unable to connect. Please check your internet connection and try again.';
    }
  }
  if (error is AuthException) {
    final message = error.message.toLowerCase();
    final code = error.code?.toLowerCase() ?? '';
    if (message.contains('invalid email') ||
        code.contains('email_address_invalid')) {
      return 'Please enter a valid email address.';
    }
    if (error.statusCode == '429' ||
        message.contains('rate limit') ||
        message.contains('too many requests') ||
        code.contains('over_email_send_rate_limit')) {
      return 'Too many reset attempts. Please try again later.';
    }
  }
  return 'Unable to send the password reset email. Please try again.';
}
