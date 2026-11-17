import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../models/transaction.dart';
import '../../services/gold_service.dart';
import '../../services/translations.dart';
import '../../services/locale_aware_mixin.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/live_price_ticker.dart';
import '../../widgets/money.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with LocaleAwareMixin {
  final _service = GoldService();
  List<Txn> _txns = [];
  bool _loading = true;

  /// 'all' / 'cash' / 'gold' / 'silver'
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      _txns = await _service.myTransactions();
    } catch (_) {
      _txns = [];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _matches(Txn t) {
    switch (_filter) {
      case 'cash':
        return t.type == TxnType.topUp;
      case 'gold':
        return t.type == TxnType.buyGold || t.type == TxnType.sellGold;
      case 'silver':
        return t.type == TxnType.buySilver ||
            t.type == TxnType.sellSilver;
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy, h:mm a');
    final filtered = _txns.where(_matches).toList();
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text(Translations.of('hist.title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding:
                        const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    children: [
                      const LivePriceTicker(),
                      const SizedBox(height: 16),
                      _filterRow(),
                      const SizedBox(height: 12),
                      if (filtered.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 60),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.receipt_long_outlined,
                                    color: AppColors.muted,
                                    size: 56),
                                SizedBox(height: 8),
                                Text(Translations.of('hist.noTxns'),
                                    style: TextStyle(
                                        color: AppColors.muted)),
                              ],
                            ),
                          ),
                        )
                      else
                        ...filtered.map((t) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.cardBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: _accentFor(t.type)
                                        .withOpacity(0.18),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    _iconFor(t.type),
                                    color: _accentFor(t.type),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(t.displayLabel,
                                          style: GoogleFonts.inter(
                                            color:
                                                AppColors.textOnDark,
                                            fontWeight:
                                                FontWeight.w600,
                                            fontSize: 13,
                                          )),
                                      const SizedBox(height: 2),
                                      Text(
                                        fmt.format(
                                            t.createdAt.toLocal()),
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.muted),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.end,
                                  children: [
                                    if (t.amountInr > 0)
                                      Text(
                                        '${t.isCredit ? '+' : '-'} ${formatInr(t.amountInr)}',
                                        style: TextStyle(
                                          color: t.isCredit
                                              ? AppColors.success
                                              : AppColors.textOnDark,
                                          fontWeight:
                                              FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                    if (t.goldGrams > 0)
                                      Text(
                                        formatGrams(t.goldGrams),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: _accentFor(t.type),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _filterRow() {
    final filters = [
      ('all', Translations.of('hist.all')),
      ('cash', Translations.of('hist.cash')),
      ('gold', Translations.of('hist.gold')),
      ('silver', Translations.of('hist.silver')),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final selected = _filter == f.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _filter = f.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.gold
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected
                        ? AppColors.gold
                        : AppColors.muted,
                  ),
                ),
                child: Text(
                  f.$2,
                  style: TextStyle(
                    color: selected
                        ? AppColors.textOnGold
                        : AppColors.muted,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  IconData _iconFor(TxnType t) {
    switch (t) {
      case TxnType.topUp:
        return Icons.add_circle_outline;
      case TxnType.buyGold:
      case TxnType.buySilver:
        return Icons.shopping_cart_outlined;
      case TxnType.sellGold:
      case TxnType.sellSilver:
        return Icons.sell_outlined;
      case TxnType.redemption:
        return Icons.diamond_outlined;
      case TxnType.adjustment:
        return Icons.tune;
    }
  }

  Color _accentFor(TxnType t) {
    switch (t) {
      case TxnType.topUp:
        return AppColors.success;
      case TxnType.buyGold:
      case TxnType.sellGold:
        return AppColors.gold;
      case TxnType.buySilver:
      case TxnType.sellSilver:
        return const Color(0xFFB0BEC5);
      case TxnType.redemption:
        return const Color(0xFF7B5BFF);
      default:
        return AppColors.muted;
    }
  }
}
