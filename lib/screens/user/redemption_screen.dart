import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/gold_price.dart';
import '../../models/jewellery_item.dart';
import '../../models/wallet.dart';
import '../../services/gold_service.dart';
import '../../services/translations.dart';
import '../../services/locale_aware_mixin.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/live_price_ticker.dart';
import '../../widgets/money.dart';
import 'buy_gold_screen.dart';
import 'wallet_topup_screen.dart';

class RedemptionScreen extends StatefulWidget {
  const RedemptionScreen({super.key});

  @override
  State<RedemptionScreen> createState() => _RedemptionScreenState();
}

class _RedemptionScreenState extends State<RedemptionScreen>
    with SingleTickerProviderStateMixin, LocaleAwareMixin {
  final _service = GoldService();
  late final TabController _tab;

  List<JewelleryItem> _items = [];
  Wallet? _wallet;
  GoldPrice? _goldPrice;
  GoldPrice? _silverPrice;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _refresh();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final items = await _service.jewelleryCatalog();
      final wallet = await _service.myWallet();
      final goldPrice = await _service.currentPrice();
      final silverPrice = await _service.currentSilverPrice();
      if (!mounted) return;
      setState(() {
        _items = items;
        _wallet = wallet;
        _goldPrice = goldPrice;
        _silverPrice = silverPrice;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  double _have(JewelleryItem item) => item.metal == 'silver'
      ? (_wallet?.silverGrams ?? 0)
      : (_wallet?.goldGrams ?? 0);

  double _pricePerGram(JewelleryItem item) => item.metal == 'silver'
      ? (_silverPrice?.pricePerGram ?? 0)
      : (_goldPrice?.pricePerGram ?? 0);

  Future<void> _redeem(JewelleryItem item) async {
    final addressCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Redeem ${item.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${Translations.of("redeem.deducts")} ${formatGrams(item.weightGrams)} ${Translations.of("redeem.fromHoldings")} ${item.metal} ${Translations.of("redeem.holdings")}',

              style: const TextStyle(color: AppColors.textOnDark),
            ),
            const SizedBox(height: 8),
            Text(
              '${Translations.of("redeem.makingChrg")} ${formatInr(item.makingChargesInr)} ${Translations.of("redeem.onDelivery")}',

              style: const TextStyle(
                  fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: addressCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                  labelText: Translations.of('redeem.shipAddr')),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(Translations.of('common.cancel'))),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(Translations.of('common.confirm'))),
        ],
      ),
    );

    if (ok != true) return;
    if (addressCtrl.text.trim().length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(Translations.of('redeem.enterAddr'))),
      );
      return;
    }
    try {
      await _service.requestRedemption(
        itemId: item.id,
        shippingAddress: addressCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${Translations.of("redeem.redeemFor")} ${item.name}')),

      );
      _refresh();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${Translations.of("redeem.failed")}: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text(Translations.of('redeem.title')),
        bottom: TabBar(
          controller: _tab,
          labelColor: AppColors.gold,
          unselectedLabelColor: AppColors.muted,
          indicatorColor: AppColors.gold,
          indicatorWeight: 2.5,
          labelStyle: GoogleFonts.inter(
              fontWeight: FontWeight.w700, fontSize: 13),
          tabs: [
            Tab(
                icon: Icon(Icons.diamond, color: AppColors.gold),
                text: Translations.of('redeem.goldTab')),
            Tab(
                icon: Icon(Icons.workspace_premium_outlined,
                    color: Color(0xFFB0BEC5)),
                text: Translations.of('redeem.silverTab')),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) => Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 600,
                    minHeight: constraints.maxHeight,
                    maxHeight: constraints.maxHeight,
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: const LivePriceTicker(),
                      ),
                      Expanded(
                        child: TabBarView(
                          controller: _tab,
                          children: [
                            _itemsList('gold'),
                            _itemsList('silver'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _itemsList(String metal) {
    final items =
        _items.where((i) => i.metal == metal).toList();
    final isSilver = metal == 'silver';
    final accent =
        isSilver ? const Color(0xFFB0BEC5) : AppColors.gold;
    final have = isSilver
        ? (_wallet?.silverGrams ?? 0)
        : (_wallet?.goldGrams ?? 0);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                Icon(Icons.workspace_premium_outlined, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${Translations.of("redeem.yourMetal")} $metal: ${formatGrams(have)}',
                    style: TextStyle(
                        color: accent, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (have == 0)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accent.withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: accent, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${Translations.of("redeem.noMetal")} $metal ${Translations.of("redeem.noMetalYet")}',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.textOnDark),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${Translations.of("redeem.buyFirst")} $metal ${Translations.of("redeem.buyFirstSfx")}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.muted)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.add_circle_outline,
                              size: 16),
                          label: Text(Translations.of('redeem.addMoney')),
                          onPressed: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    const WalletTopUpScreen(),
                              ),
                            );
                            _refresh();
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(
                              Icons.shopping_cart_outlined,
                              size: 16),
                          label: Text('${Translations.of("redeem.buyBtn")} $metal'),
                          onPressed: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    BuyGoldScreen(metal: metal),
                              ),
                            );
                            _refresh();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ...items.map((item) => _itemCard(item, accent)),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Text(
                '${Translations.of("redeem.noItems")} $metal ${Translations.of("redeem.noItemsSfx")}',
                style:
                    const TextStyle(color: AppColors.muted),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _itemCard(JewelleryItem item, Color accent) {
    final have = _have(item);
    final canRedeem = have >= item.weightGrams;
    final deficitGrams =
        (item.weightGrams - have).clamp(0, double.infinity);
    final deficitInr = deficitGrams * _pricePerGram(item);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.diamond_outlined,
                    color: accent, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        style: GoogleFonts.inter(
                          color: AppColors.textOnDark,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        )),
                    const SizedBox(height: 2),
                    Text(
                      '${formatGrams(item.weightGrams)} • Making ${formatInr(item.makingChargesInr)}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.muted),
                    ),
                    if (item.description != null) ...[
                      const SizedBox(height: 4),
                      Text(item.description!,
                          style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.muted)),
                    ]
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  item.categoryLabel,
                  style: TextStyle(
                    color: accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left: item value chip
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: canRedeem
                      ? AppColors.success.withOpacity(0.12)
                      : accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  canRedeem
                      ? '✓ ${formatGrams(item.weightGrams)}'
                      : '${formatGrams(item.weightGrams)} needed',
                  style: TextStyle(
                      color: canRedeem ? AppColors.success : accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ),
              // Right: action button — compact size
              canRedeem
                  ? ElevatedButton.icon(
                      icon: const Icon(Icons.diamond_outlined, size: 15),
                      label: Text(
                        Translations.of('redeem.redeemBtn'),
                        style: const TextStyle(fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => _redeem(item),
                    )
                  : OutlinedButton.icon(
                      icon: const Icon(Icons.shopping_cart_outlined,
                          size: 14),
                      label: Text(
                        'Need ${deficitGrams.toStringAsFixed(2)} g',
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                BuyGoldScreen(metal: item.metal),
                          ),
                        );
                        _refresh();
                      },
                    ),
            ],
          ),
        ],
      ),
    );
  }
}
