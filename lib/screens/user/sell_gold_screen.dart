import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/gold_price.dart';
import '../../models/wallet.dart';
import '../../services/gold_service.dart';
import '../../services/live_price_service.dart';
import '../../services/translations.dart';
import '../../services/locale_aware_mixin.dart';
import '../../theme/app_theme.dart';
import '../../widgets/money.dart';

class SellGoldScreen extends StatefulWidget {
  final String metal;
  const SellGoldScreen({super.key, this.metal = 'gold'});

  @override
  State<SellGoldScreen> createState() => _SellGoldScreenState();
}

class _SellGoldScreenState extends State<SellGoldScreen> with LocaleAwareMixin {
  final _ctrl = TextEditingController();
  final _service = GoldService();
  final _live = LivePriceService.instance;

  GoldPrice? _dbPrice;
  LivePrice? _livePrice;
  Wallet? _wallet;
  List<GoldPrice> _history = [];

  bool _initLoading = true;
  bool _submitting = false;
  Timer? _countdown;
  Duration _refreshIn = const Duration(minutes: 5, seconds: 54);

  bool get _isSilver => widget.metal == 'silver';
  String get _metalLabel => _isSilver ? 'Silver' : 'Gold';
  Color get _metalColor =>
      _isSilver ? const Color(0xFFB0BEC5) : AppColors.gold;
  Color get _metalAccent =>
      _isSilver ? const Color(0xFF6B7B8C) : AppColors.darkGold;


  String get _metalTranslated => _isSilver
      ? Translations.of('common.silver')
      : Translations.of('common.gold');
  double get _rate =>
      _livePrice?.inrPerGram ?? _dbPrice?.pricePerGram ?? 0;

  double get _have =>
      _isSilver ? (_wallet?.silverGrams ?? 0) : (_wallet?.goldGrams ?? 0);

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() => setState(() {}));
    _bootstrap();
    _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_refreshIn.inSeconds <= 1) {
          _refreshLive();
          _refreshIn = const Duration(minutes: 5, seconds: 54);
        } else {
          _refreshIn -= const Duration(seconds: 1);
        }
      });
    });
  }

  Future<void> _bootstrap() async {
    final dbp = _isSilver
        ? await _service.currentSilverPrice()
        : await _service.currentPrice();
    final wallet = await _service.myWallet();
    final history =
        await _service.priceHistory(limit: 30, metal: widget.metal);
    if (!mounted) return;
    setState(() {
      _dbPrice = dbp;
      _wallet = wallet;
      _history = history;
      _initLoading = false;
    });
    _refreshLive();
  }

  Future<void> _refreshLive() async {
    await _live.fetchAll();
    if (!mounted) return;
    setState(() {
      _livePrice = _isSilver ? _live.silverPrice : _live.goldPrice;
    });
  }

  @override
  void dispose() {
    _countdown?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  double? get _typed => double.tryParse(_ctrl.text.trim());
  double get _grams => _typed ?? 0;
  double get _amount => _grams * _rate;

  void _setGrams(double g) =>
      _ctrl.text = g.clamp(0, _have).toStringAsFixed(4);

  Future<void> _sell() async {
    if (_grams <= 0) {
      _toast(Translations.of('buy.enterGrams'));
      return;
    }
    if (_have < _grams) {
      _toast('${Translations.of("buy.notEnough")} $_metalTranslated ${Translations.of("buy.toSell")}');
      return;
    }
    setState(() => _submitting = true);
    try {
      await _service.sellMetal(metal: widget.metal, grams: _grams);
      if (!mounted) return;
      _toast(
          'Sold ${_grams.toStringAsFixed(4)} g for ${formatInr(_amount)}');
      Navigator.of(context).pop();
    } catch (e) {
      _toast('${Translations.of("buy.saleFailed")}: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  String _fmtCountdown(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(1, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${Translations.of("common.sell")} $_metalTranslated'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: _refreshLive,
          ),
        ],
      ),
      body: _initLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    _livePriceCard(),
                    const SizedBox(height: 14),
                    _balanceLine(),
                    const SizedBox(height: 18),
                    Text(
                      '${Translations.of("common.sell")} ${_metalTranslated.toLowerCase()} ${Translations.of("buy.fromLocker")}',

                      style: GoogleFonts.inter(
                        color: AppColors.textOnDark,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _amountInput(),
                    const SizedBox(height: 14),
                    _quickPercentChips(),
                    const SizedBox(height: 22),
                    _sellButton(),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        Translations.of('buy.fundsNote'),
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 11),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('$_metalTranslated ${Translations.of("buy.priceTrends")}',

                        style: GoogleFonts.inter(
                          color: AppColors.textOnDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        )),
                    const SizedBox(height: 8),
                    SizedBox(height: 140, child: _miniChart()),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _livePriceCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _metalAccent.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.danger,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(Translations.of('buy.liveSellPrice'),
                  style: GoogleFonts.inter(
                    color: AppColors.textOnDark,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  )),
              const Spacer(),
              const Icon(Icons.access_time,
                  color: AppColors.muted, size: 14),
              const SizedBox(width: 4),
              Text('${Translations.of("buy.refreshIn")} ${_fmtCountdown(_refreshIn)}',

                  style: const TextStyle(
                      color: AppColors.muted, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  _rate == 0 ? '—' : '${formatInr(_rate)} / g',
                  style: GoogleFonts.inter(
                    color: _metalColor,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _metalAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _isSilver ? '999 Silver' : '24K · 999%',
                  style: TextStyle(
                    color: _metalColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _balanceLine() {
    return Row(
      children: [
        Text(
          '${Translations.of("buy.available")} ${_metalTranslated.toLowerCase()}:',

          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(width: 6),
        Text(
          '${_have.toStringAsFixed(4)} g',
          style: TextStyle(
              color: _metalColor,
              fontWeight: FontWeight.w700,
              fontSize: 13),
        ),
        const Spacer(),
        Text('Wallet ${formatInr(_wallet?.cashBalance ?? 0)}',
            style: const TextStyle(
                color: AppColors.muted, fontSize: 11)),
      ],
    );
  }

  Widget _amountInput() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _metalAccent.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _metalColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('g',
                style: TextStyle(
                    color: AppColors.textOnGold,
                    fontWeight: FontWeight.w700,
                    fontSize: 18)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _ctrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.inter(
                color: AppColors.textOnDark,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
              decoration: const InputDecoration(
                filled: false,
                border: InputBorder.none,
                hintText: '0.0000',
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '= ${formatInr(_amount)}',
            style: TextStyle(
              color: _metalColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickPercentChips() {
    final percents = [25, 50, 75, 100];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: percents
          .map((p) => OutlinedButton(
                onPressed: () => _setGrams(_have * p / 100),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  side: BorderSide(color: _metalAccent),
                  foregroundColor: _metalColor,
                ),
                child: Text(p == 100 ? 'MAX' : '$p%'),
              ))
          .toList(),
    );
  }

  Widget _sellButton() {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: _submitting ? null : _sell,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _isSilver
                  ? const [Color(0xFFB0BEC5), Color(0xFF6B7B8C)]
                  : const [Color(0xFFE8C36A), Color(0xFFB88A2A)],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.sell_outlined,
                    color: AppColors.textOnGold, size: 18),
                const SizedBox(width: 8),
                Text(
                  _submitting
                      ? Translations.of('common.processing')
                      : '${Translations.of("common.sell").toUpperCase()} ${_metalTranslated.toUpperCase()}',
                  style: const TextStyle(
                    color: AppColors.textOnGold,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniChart() {
    final pts = _miniSeries();
    final ys = pts.map((s) => s.y).toList();
    final minY = ys.reduce(math.min);
    final maxY = ys.reduce(math.max);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: LineChart(
        LineChartData(
          minY: minY * 0.97,
          maxY: maxY * 1.03,
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: pts,
              isCurved: true,
              barWidth: 2,
              color: _metalColor,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    _metalColor.withOpacity(0.3),
                    _metalColor.withOpacity(0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<FlSpot> _miniSeries() {
    if (_history.length >= 2) {
      final reversed = _history.reversed.toList();
      return [
        for (int i = 0; i < reversed.length; i++)
          FlSpot(i.toDouble(), reversed[i].pricePerGram),
      ];
    }
    final rate = _rate == 0 ? 7000.0 : _rate;
    final rng = math.Random(11);
    final pts = <FlSpot>[];
    double v = rate * 0.95;
    for (int i = 0; i < 20; i++) {
      v += (rng.nextDouble() - 0.5) * (rate * 0.01);
      pts.add(FlSpot(i.toDouble(), v));
    }
    pts.add(FlSpot(20, rate));
    return pts;
  }
}
