import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../main.dart';
import '../../theme/app_theme.dart';
import '../../widgets/money.dart';
import '../../widgets/stat_card.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  bool _loading = true;
  int    _userCount          = 0;
  double _totalCash          = 0;
  double _totalGold          = 0;
  double _totalBuyVolume     = 0;
  double _totalSellVolume    = 0;
  int    _pendingRedemptions = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final profiles = await supabase.from('profiles').select('id');
      _userCount = (profiles as List).length;

      final wallets =
          await supabase.from('wallets').select('cash_balance, gold_grams');
      double cash = 0, gold = 0;
      for (final w in wallets as List) {
        cash += ((w['cash_balance'] as num?) ?? 0).toDouble();
        gold += ((w['gold_grams']   as num?) ?? 0).toDouble();
      }
      _totalCash = cash;
      _totalGold = gold;

      final txns =
          await supabase.from('transactions').select('txn_type, amount_inr');
      double buy = 0, sell = 0;
      for (final t in txns as List) {
        final type = t['txn_type'] as String?;
        final amt  = ((t['amount_inr'] as num?) ?? 0).toDouble();
        if (type == 'buy_gold')  buy  += amt;
        if (type == 'sell_gold') sell += amt;
      }
      _totalBuyVolume  = buy;
      _totalSellVolume = sell;

      final pending = await supabase
          .from('redemption_requests')
          .select('id')
          .inFilter('status', ['requested', 'approved']);
      _pendingRedemptions = (pending as List).length;
    } catch (_) {
      // swallow; UI shows zeros
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.charcoal,
      appBar: AppBar(
        backgroundColor: AppColors.charcoal,
        automaticallyImplyLeading: false,
        title: Text('Reports',
            style: GoogleFonts.inter(
                color: AppColors.gold,
                fontSize: 17,
                fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh, color: AppColors.gold),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.3,
                children: [
                  StatCard(dark: true,
                    label: 'Total users',
                    value: _userCount.toString(),
                    icon: Icons.people_alt_outlined,
                    accent: AppColors.gold,
                  ),
                  StatCard(dark: true,
                    label: 'Cash in wallets',
                    value: formatInr(_totalCash),
                    icon: Icons.account_balance_wallet_outlined,
                    accent: AppColors.success,
                  ),
                  StatCard(dark: true,
                    label: 'Gold under custody',
                    value: '${_totalGold.toStringAsFixed(4)} g',
                    icon: Icons.workspace_premium_outlined,
                    accent: AppColors.darkGold,
                  ),
                  StatCard(dark: true,
                    label: 'Buy volume (all time)',
                    value: formatInr(_totalBuyVolume),
                    icon: Icons.trending_up,
                    accent: AppColors.success,
                  ),
                  StatCard(dark: true,
                    label: 'Sell volume (all time)',
                    value: formatInr(_totalSellVolume),
                    icon: Icons.trending_down,
                    accent: AppColors.danger,
                  ),
                  StatCard(dark: true,
                    label: 'Pending redemptions',
                    value: _pendingRedemptions.toString(),
                    icon: Icons.local_shipping_outlined,
                    accent: const Color(0xFF1E88E5),
                  ),
                ],
              ),
            ),
    );
  }
}
