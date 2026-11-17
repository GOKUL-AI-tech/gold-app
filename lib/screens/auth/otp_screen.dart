import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../main.dart';
import '../../services/auth_service.dart';
import '../../services/translations.dart';
import '../../theme/app_theme.dart';
import '../user/home_screen.dart';

class OtpScreen extends StatefulWidget {
  final String? email;
  final String? phone;
  final String? fullName;
  final String? phoneToSave;

  const OtpScreen({
    super.key,
    this.email,
    this.phone,
    this.fullName,
    this.phoneToSave,
  }) : assert(email != null || phone != null,
            'Provide either email or phone');

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _otpCtrl = TextEditingController();
  final _auth = AuthService();
  bool _loading = false;

  @override
  void dispose() {
    _otpCtrl.dispose();
    super.dispose();
  }

  String get _destination => widget.email ?? widget.phone ?? '';
  bool get _isEmailFlow => widget.email != null;

  Future<void> _verify() async {
    if (_otpCtrl.text.trim().length < 6) {
      _toast(Translations.of('auth.enterSixDigit'));
      return;
    }
    setState(() => _loading = true);
    try {
      if (_isEmailFlow) {
        await _auth.verifyEmailOtp(
            email: widget.email!, token: _otpCtrl.text);
      } else {
        await _auth.verifyPhoneOtp(
            phone: widget.phone!, token: _otpCtrl.text);
      }
      await _persistProfileIfNeeded();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    } catch (e) {
      _toast('${Translations.of('auth.verifyFailed')}: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _persistProfileIfNeeded() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    if (widget.fullName == null && widget.phoneToSave == null) return;
    final updates = <String, dynamic>{'id': user.id};
    if (widget.fullName != null && widget.fullName!.isNotEmpty)
      updates['full_name'] = widget.fullName;
    if (widget.phoneToSave != null && widget.phoneToSave!.isNotEmpty)
      updates['phone'] = widget.phoneToSave;
    if (widget.phone != null && widget.email == null)
      updates['phone'] = widget.phone;
    if (widget.email != null) updates['email'] = widget.email;
    try {
      await supabase.from('profiles').upsert(updates);
    } catch (_) {}
  }

  Future<void> _resend() async {
    try {
      if (_isEmailFlow) {
        await _auth.sendEmailOtp(widget.email!);
      } else {
        await _auth.sendPhoneOtp(widget.phone!);
      }
      _toast(Translations.of('auth.otpResent'));
    } catch (e) {
      _toast('${Translations.of('auth.resendFailed')}: $e');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(Translations.of('auth.verifyOtp'))),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.gold, AppColors.darkGold],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.gold.withOpacity(0.3),
                            blurRadius: 24,
                          )
                        ],
                      ),
                      child: const Icon(
                        Icons.mark_email_read_outlined,
                        size: 32,
                        color: AppColors.textOnGold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    Translations.of('auth.verifyCode'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: AppColors.gold,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    Translations.of('auth.sentCodeTo'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                        color: AppColors.muted, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _destination,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textOnDark),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppColors.gold.withOpacity(0.4)),
                    ),
                    child: TextField(
                      controller: _otpCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 28,
                        letterSpacing: 12,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: const InputDecoration(
                        filled: false,
                        border: InputBorder.none,
                        hintText: '------',
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _loading ? null : _verify,
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: AppColors.textOnGold),
                          )
                        : Text(Translations.of('auth.verifyContinue')),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: _resend,
                      child: Text(Translations.of('auth.resendCode')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
