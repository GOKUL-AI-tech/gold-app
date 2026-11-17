import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/env.dart';
import '../../services/gold_service.dart';
import '../../services/locale_aware_mixin.dart';
import '../../services/translations.dart';
import '../../theme/app_theme.dart';
import '../../widgets/live_price_ticker.dart';
import '../../widgets/money.dart';

class WalletTopUpScreen extends StatefulWidget {
  const WalletTopUpScreen({super.key});

  @override
  State<WalletTopUpScreen> createState() => _WalletTopUpScreenState();
}

class _WalletTopUpScreenState extends State<WalletTopUpScreen>
    with LocaleAwareMixin {
  final _ctrl    = TextEditingController();
  final _service = GoldService();
  late final Razorpay _razorpay;

  bool   _loading       = false;
  double _pendingAmount = 0;

  // ── Lifecycle ───────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR,   _onPaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    _ctrl.dispose();
    super.dispose();
  }

  // ── Razorpay callbacks ──────────────────────────────────────────
  Future<void> _onPaymentSuccess(PaymentSuccessResponse res) async {
    setState(() => _loading = true);
    try {
      await _service.topUpWallet(_pendingAmount);
      if (!mounted) return;
      _toast('✓  ${formatInr(_pendingAmount)} added to wallet',
          success: true);
      Navigator.of(context).pop();
    } catch (e) {
      _toast('Payment done but wallet update failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onPaymentError(PaymentFailureResponse res) {
    setState(() => _loading = false);
    _toast('Payment failed: ${res.message ?? "Unknown error"}');
  }

  void _onExternalWallet(ExternalWalletResponse res) {
    _toast('External wallet: ${res.walletName}');
  }

  // ── Open Razorpay checkout ──────────────────────────────────────
  void _openRazorpay(double amount) {
    final user = Supabase.instance.client.auth.currentUser;
    final options = <String, dynamic>{
      'key':         PaymentConfig.razorpayKeyId,
      'amount':      (amount * 100).toInt(), // in paise
      'currency':    'INR',
      'name':        PaymentConfig.appName,
      'description': PaymentConfig.description,
      'prefill': {
        'contact': user?.phone ?? '',
        'email':   user?.email ?? '',
      },
      'theme': {'color': '#E8C36A'},
      'modal': {'confirm_close': true},
    };
    try {
      _pendingAmount = amount;
      _razorpay.open(options);
    } catch (e) {
      setState(() => _loading = false);
      _toast('Could not open payment: $e');
    }
  }

  // ── Validate and trigger ────────────────────────────────────────
  void _pay() {
    final amount = double.tryParse(_ctrl.text.trim());
    if (amount == null || amount < 1) {
      _toast(Translations.of('wallet.validAmount'));
      return;
    }
    setState(() => _loading = true);
    _openRazorpay(amount);
  }

  void _toast(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? const Color(0xFF2E7D32) : null,
    ));
  }

  // ── UI ──────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(Translations.of('wallet.title'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const LivePriceTicker(),
                const SizedBox(height: 18),

                // Amount card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF1D689), Color(0xFFD9B556)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        Translations.of('wallet.howMuch'),
                        style: GoogleFonts.inter(
                          color: AppColors.textOnGold.withOpacity(0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _ctrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        style: GoogleFonts.inter(
                          color: AppColors.textOnGold,
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: InputDecoration(
                          filled: false,
                          prefix: Text('₹  ',
                              style: GoogleFonts.inter(
                                  color: AppColors.textOnGold,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w700)),
                          hintText: '0.00',
                          hintStyle: GoogleFonts.inter(
                            color: AppColors.textOnGold.withOpacity(0.4),
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                          ),
                          contentPadding: EdgeInsets.zero,
                          border: const UnderlineInputBorder(
                              borderSide:
                                  BorderSide(color: AppColors.textOnGold)),
                          enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(
                                  color: AppColors.textOnGold
                                      .withOpacity(0.6))),
                          focusedBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(
                                  color: AppColors.textOnGold,
                                  width: 1.5)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        Translations.of('wallet.fundsNote'),
                        style: GoogleFonts.inter(
                          color: AppColors.textOnGold.withOpacity(0.75),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),
                Text(Translations.of('wallet.quickAdd'),
                    style: GoogleFonts.inter(
                        color: AppColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [100, 500, 1000, 5000, 10000, 25000]
                      .map((q) => OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 40),
                              foregroundColor: AppColors.gold,
                              side: const BorderSide(color: AppColors.gold),
                            ),
                            onPressed: () => _ctrl.text = q.toString(),
                            child: Text(formatInr(q)),
                          ))
                      .toList(),
                ),

                const SizedBox(height: 28),

                // Pay button
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _pay,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: _loading
                            ? null
                            : const LinearGradient(
                                colors: [
                                  Color(0xFFE8C36A),
                                  Color(0xFFB88A2A)
                                ],
                              ),
                        color: _loading ? AppColors.cardElevated : null,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    color: AppColors.gold, strokeWidth: 2),
                              )
                            : Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.lock_outline,
                                      color: AppColors.textOnGold,
                                      size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    Translations.of('wallet.payAdd'),
                                    style: const TextStyle(
                                      color: AppColors.textOnGold,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.2,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Razorpay badge + payment method icons
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.verified_user_outlined,
                            color: AppColors.muted, size: 13),
                        SizedBox(width: 5),
                        Text('Secured by Razorpay',
                            style: TextStyle(
                                color: AppColors.muted, fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _payChip(Icons.credit_card,       'Cards'),
                        const SizedBox(width: 10),
                        _payChip(Icons.account_balance,   'Net Banking'),
                        const SizedBox(width: 10),
                        _payChip(Icons.phone_android,     'UPI'),
                        const SizedBox(width: 10),
                        _payChip(Icons.account_balance_wallet, 'Wallets'),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _payChip(IconData icon, String label) => Column(
        children: [
          Icon(icon, color: AppColors.muted, size: 18),
          const SizedBox(height: 2),
          Text(label,
              style:
                  const TextStyle(color: AppColors.muted, fontSize: 9)),
        ],
      );
}
