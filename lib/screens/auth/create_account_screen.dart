import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../main.dart';
import '../../services/auth_service.dart';
import '../../services/translations.dart';
import '../../theme/app_theme.dart';
import '../user/home_screen.dart';
import 'otp_screen.dart';

/// Sign-up screen — dark "Gold Century" theme matching the dashboard.
class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _auth = AuthService();
  bool _loading = false;
  bool _obscure = true;

  late final TapGestureRecognizer _signInTapRecognizer =
      TapGestureRecognizer()..onTap = () => Navigator.of(context).pop();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _signInTapRecognizer.dispose();
    super.dispose();
  }

  String _normalizedEmail() => _emailCtrl.text.trim();

  String _normalizedPhone() {
    var raw = _phoneCtrl.text.trim().replaceAll(RegExp(r'[\s\-()]'), '');
    if (raw.isEmpty) return '';
    if (raw.startsWith('+')) return raw;
    if (raw.length == 10) return '+91$raw';
    return '+$raw';
  }

  bool _isEmailValid(String email) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);

  bool _isPhoneValid(String phone) =>
      RegExp(r'^\+\d{8,15}$').hasMatch(phone);

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _submit() async {
    final email = _normalizedEmail();
    final phone = _normalizedPhone();
    final name = _nameCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (name.isEmpty) {
      _toast(Translations.of('auth.fullName') + ' required');
      return;
    }
    if (email.isEmpty && phone.isEmpty) {
      _toast('Enter your email or phone number to continue');
      return;
    }
    if (email.isNotEmpty && !_isEmailValid(email)) {
      _toast('That email address looks invalid');
      return;
    }
    if (phone.isNotEmpty && !_isPhoneValid(phone)) {
      _toast(
          'Enter a valid phone with country code (e.g. +919876543210)');
      return;
    }
    if (password.isNotEmpty && password.length < 6) {
      _toast('Password must be at least 6 characters');
      return;
    }
    if (password.isNotEmpty && email.isEmpty) {
      _toast('Email is required when setting a password');
      return;
    }

    setState(() => _loading = true);
    try {
      if (email.isNotEmpty && password.isNotEmpty) {
        final res = await _auth.signUpWithPassword(
          email: email,
          password: password,
          metadata: {'full_name': name},
        );

        if (res.session == null) {
          _toast(
              Translations.of('auth.accountCreated') + ' '
              'then sign in.');
          if (!mounted) return;
          Navigator.of(context).pop();
          return;
        }

        await _persistProfile(name: name, email: email, phone: phone);
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (_) => false,
        );
        return;
      }

      if (email.isNotEmpty) {
        await _auth.sendEmailOtp(email);
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OtpScreen(
              email: email,
              fullName: name,
              phoneToSave: phone.isNotEmpty ? phone : null,
            ),
          ),
        );
        return;
      }

      await _auth.sendPhoneOtp(phone);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OtpScreen(phone: phone, fullName: name),
        ),
      );
    } catch (e) {
      await _handleSignupError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleSignupError(Object e) async {
    final msg = e.toString().toLowerCase();
    final alreadyExists = msg.contains('already registered') ||
        msg.contains('user_already_exists') ||
        msg.contains('already exists') ||
        msg.contains('user already');

    if (alreadyExists) {
      if (!mounted) return;
      final goToLogin = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(Translations.of('auth.alreadyAccount')),
          content: Text(
            'An account with ${_emailCtrl.text.trim()} already exists. '
            + Translations.of('auth.signInInstead'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(Translations.of('common.cancel')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(Translations.of('auth.goToSignIn')),
            ),
          ],
        ),
      );
      if (goToLogin == true && mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    if (msg.contains('invalid email') ||
        msg.contains('email_address_invalid')) {
      _toast('That email address is invalid. Try a different one.');
      return;
    }
    if (msg.contains('weak password') ||
        msg.contains('password_too_short')) {
      _toast('Password is too weak. Use at least 6 characters.');
      return;
    }
    if (msg.contains('failed host lookup') ||
        msg.contains('socketexception')) {
      _toast('Cannot reach the server. Check your internet connection.');
      return;
    }
    _toast('Sign-up failed: $e');
  }

  Future<void> _persistProfile({
    required String name,
    required String email,
    required String phone,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      await supabase.from('profiles').upsert({
        'id': user.id,
        'full_name': name,
        'email': email,
        if (phone.isNotEmpty) 'phone': phone,
      });
    } catch (_) {
      // Non-fatal.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.charcoal,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ---- Header ----
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back,
                            color: AppColors.gold),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.diamond,
                          color: AppColors.gold, size: 24),
                      const SizedBox(width: 8),
                      Container(
                        height: 32,
                        width: 1,
                        color: AppColors.gold.withOpacity(0.5),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Gold\nCentury',
                        style: GoogleFonts.inter(
                          color: AppColors.gold,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(
                    Translations.of('auth.createAccount'),
                    style: GoogleFonts.inter(
                      color: AppColors.gold,
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    height: 2,
                    width: 64,
                    color: AppColors.gold,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    Translations.of('auth.createSubtitle'),
                    style: GoogleFonts.inter(
                      color: AppColors.muted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ---- Gold card with form ----
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFF1D689),
                          Color(0xFFD9B556),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label(Translations.of('auth.fullName')),
                          _underlineField(
                            controller: _nameCtrl,
                            hint: Translations.of('auth.fullNameHint'),
                            keyboardType: TextInputType.name,
                            textCapitalization: TextCapitalization.words,
                          ),
                          const SizedBox(height: 18),
                          _label(Translations.of('auth.email')),
                          _underlineField(
                            controller: _emailCtrl,
                            hint: Translations.of('auth.emailHint'),
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color:
                                      AppColors.textOnGold.withOpacity(0.3),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10),
                                child: Text(Translations.of('common.or'),
                                    style: GoogleFonts.inter(
                                      color: AppColors.textOnGold
                                          .withOpacity(0.6),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    )),
                              ),
                              Expanded(
                                child: Divider(
                                  color:
                                      AppColors.textOnGold.withOpacity(0.3),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _label(Translations.of('auth.phoneNumber')),
                          _underlineField(
                            controller: _phoneCtrl,
                            hint: Translations.of('auth.phoneHint'),
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[\d+\-\s()]')),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _label(Translations.of('auth.passwordOpt')),
                          _underlineField(
                            controller: _passwordCtrl,
                            hint: Translations.of('auth.passwordOptHint'),
                            obscure: _obscure,
                            suffix: IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: AppColors.textOnGold.withOpacity(0.7),
                                size: 20,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Already have account link
                          Center(
                            child: Text.rich(
                              TextSpan(
                                style: GoogleFonts.inter(fontSize: 12),
                                children: [
                                  TextSpan(
                                    text: Translations.of('auth.alreadySignedUp'),
                                    style: TextStyle(
                                        color: AppColors.textOnGold
                                            .withOpacity(0.7)),
                                  ),
                                  TextSpan(
                                    text: Translations.of('auth.signInInstead'),
                                    style: const TextStyle(
                                      color: AppColors.textOnGold,
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.underline,
                                    ),
                                    recognizer: _signInTapRecognizer,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ---- Submit row ----
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _loading ? null : _submit,
                          child: Text(Translations.of('auth.createAccount')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _circleArrowButton(
                        onTap: _loading ? null : _submit,
                        loading: _loading,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          text,
          style: GoogleFonts.inter(
            color: AppColors.textOnGold.withOpacity(0.8),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      );

  Widget _underlineField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool obscure = false,
    Widget? suffix,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      style: GoogleFonts.inter(
        color: AppColors.textOnGold,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        filled: false,
        hintText: hint,
        hintStyle: GoogleFonts.inter(
          color: AppColors.textOnGold.withOpacity(0.4),
          fontSize: 17,
        ),
        contentPadding: EdgeInsets.zero,
        border: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.textOnGold),
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(
              color: AppColors.textOnGold.withOpacity(0.6)),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide:
              BorderSide(color: AppColors.textOnGold, width: 1.5),
        ),
        suffixIcon: suffix,
      ),
    );
  }
}

class _circleArrowButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool loading;

  const _circleArrowButton({
    required this.onTap,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(40),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                Translations.of('common.continue'),
                style: GoogleFonts.inter(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [AppColors.gold, AppColors.darkGold],
                  ),
                ),
                alignment: Alignment.center,
                child: loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: AppColors.textOnGold,
                        ),
                      )
                    : const Icon(Icons.arrow_forward,
                        color: AppColors.textOnGold, size: 26),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
