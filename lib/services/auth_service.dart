import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';

/// Wraps Supabase auth methods used by the UI.
class AuthService {
  // ---------- Email OTP ----------
  /// Send a 6-digit OTP to the user's email.
  Future<void> sendEmailOtp(String email) async {
    await supabase.auth.signInWithOtp(
      email: email.trim(),
      shouldCreateUser: true,
    );
  }

  /// Verify the email OTP code and complete sign-in.
  Future<AuthResponse> verifyEmailOtp({
    required String email,
    required String token,
  }) async {
    return supabase.auth.verifyOTP(
      email: email.trim(),
      token: token.trim(),
      type: OtpType.email,
    );
  }

  // ---------- Phone OTP ----------
  /// Send a 6-digit OTP to the user's phone (E.164 format, e.g. +919...).
  /// Requires Phone Auth + an SMS provider configured in Supabase.
  Future<void> sendPhoneOtp(String phone) async {
    await supabase.auth.signInWithOtp(
      phone: phone.trim(),
      shouldCreateUser: true,
    );
  }

  /// Verify the phone OTP code and complete sign-in.
  Future<AuthResponse> verifyPhoneOtp({
    required String phone,
    required String token,
  }) async {
    return supabase.auth.verifyOTP(
      phone: phone.trim(),
      token: token.trim(),
      type: OtpType.sms,
    );
  }

  // ---------- Email + Password ----------
  /// Sign up a new user with email + password.
  Future<AuthResponse> signUpWithPassword({
    required String email,
    required String password,
    Map<String, dynamic>? metadata,
  }) async {
    return supabase.auth.signUp(
      email: email.trim(),
      password: password,
      data: metadata,
    );
  }

  /// Sign in an existing user with email + password.
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    return supabase.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Send a password-reset email.
  Future<void> sendPasswordReset(String email) async {
    await supabase.auth.resetPasswordForEmail(email.trim());
  }

  /// Update the password for the currently signed-in user.
  Future<void> updatePassword(String newPassword) async {
    await supabase.auth.updateUser(UserAttributes(password: newPassword));
  }

  // ---------- General ----------
  Future<void> signOut() => supabase.auth.signOut();

  User? get currentUser => supabase.auth.currentUser;
  Stream<AuthState> authStateChanges() => supabase.auth.onAuthStateChange;
}
