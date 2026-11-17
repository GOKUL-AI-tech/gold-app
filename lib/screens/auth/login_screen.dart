import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/auth_service.dart';
import '../../services/translations.dart';
import '../../theme/app_theme.dart';
import '../user/home_screen.dart';
import 'create_account_screen.dart';
import 'otp_screen.dart';

/// "Gold Century" inspired login screen.
/// Charcoal background with a single oversized gold card containing the
/// inputs, plus a circular "Send OTP" arrow button below it.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _auth = AuthService();
  bool _loading = false;
  bool _obscure = true;
  String _partner = 'MMTC PAMP';

  @override
  void dispose() {
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _signInWithPassword() async {
    if (_emailCtrl.text.trim().isEmpty || _passwordCtrl.text.isEmpty) {
      _toast(Translations.of('auth.enterEmailPwd'));
      return;
    }
    setState(() => _loading = true);
    try {
      await _auth.signInWithPassword(
        email: _emailCtrl.text,
        password: _passwordCtrl.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    } catch (e) {
      _toast(Translations.of('auth.signInFailed') + ': $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendOtp() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _toast(Translations.of('auth.enterEmailOtp'));
      return;
    }
    setState(() => _loading = true);
    try {
      await _auth.sendEmailOtp(email);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OtpScreen(email: email),
        ),
      );
    } catch (e) {
      _toast(Translations.of('auth.otpSendFailed') + ': $e');
    } finally {
      if (mounted) setState(() => _loading = false);
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
                      const Icon(Icons.diamond,
                          color: AppColors.gold, size: 28),
                      const SizedBox(width: 8),
                      Container(
                        height: 36,
                        width: 1,
                        color: AppColors.gold.withOpacity(0.5),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Gold\nCentury',
                        style: GoogleFonts.inter(
                          color: AppColors.gold,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 36),
                  Text(
                    Translations.of('auth.login'),
                    style: GoogleFonts.inter(
                      color: AppColors.gold,
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    height: 2,
                    width: 64,
                    color: AppColors.gold,
                  ),
                  const SizedBox(height: 28),

                  // ---- Gold card ----
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
                          _label(Translations.of('auth.email')),
                          _underlineField(
                            controller: _emailCtrl,
                            hint: Translations.of('auth.emailHint'),
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 18),
                          _label(Translations.of('auth.password')),
                          _underlineField(
                            controller: _passwordCtrl,
                            hint: Translations.of('auth.passwordHint'),
                            obscure: _obscure,
                            suffix: IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: AppColors.textOnGold
                                    .withOpacity(0.7),
                                size: 20,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                          const SizedBox(height: 18),
                          _label(Translations.of('auth.goldPartner')),
                          DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _partner,
                              dropdownColor: AppColors.lightGold,
                              isExpanded: true,
                              icon: const Icon(Icons.keyboard_arrow_down,
                                  color: AppColors.textOnGold),
                              items: const [
                                'MMTC PAMP',
                                'Augmont',
                                'SafeGold',
                              ]
                                  .map((p) => DropdownMenuItem(
                                        value: p,
                                        child: Row(
                                          children: [
                                            const Icon(Icons.diamond,
                                                size: 16,
                                                color:
                                                    AppColors.textOnGold),
                                            const SizedBox(width: 8),
                                            Text(
                                              p,
                                              style: const TextStyle(
                                                color:
                                                    AppColors.textOnGold,
                                                fontWeight:
                                                    FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ))
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _partner = v ?? _partner),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                Translations.of('auth.noAccount') + ' ',
                                style: GoogleFonts.inter(
                                  color: AppColors.textOnGold
                                      .withOpacity(0.7),
                                  fontSize: 12,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const CreateAccountScreen(),
                                  ),
                                ),
                                child: Text(
                                  Translations.of('auth.registerNow'),
                                  style: GoogleFonts.inter(
                                    color: AppColors.textOnGold,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    decoration:
                                        TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ---- Sign in row ----
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _loading ? null : _signInWithPassword,
                          child: Text(Translations.of('auth.signIn')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Big circular Send OTP arrow button
                      _circleArrowButton(
                        onTap: _loading ? null : _sendOtp,
                        loading: _loading,
                        label: Translations.of('auth.sendOtp'),
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
    bool obscure = false,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      style: GoogleFonts.inter(
        color: AppColors.textOnGold,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        filled: false,
        hintText: hint,
        hintStyle: GoogleFonts.inter(
          color: AppColors.textOnGold.withOpacity(0.4),
          fontSize: 18,
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
  final String label;
  const _circleArrowButton({
    required this.onTap,
    required this.loading,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(40),
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
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
