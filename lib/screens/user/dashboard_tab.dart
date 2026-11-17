import 'dart:convert';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../models/gold_price.dart';
import '../../models/wallet.dart';
import '../../services/gold_service.dart';
import '../../services/translations.dart';
import '../../services/locale_aware_mixin.dart';
import '../../services/live_price_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/money.dart';
import 'buy_gold_screen.dart';
import 'wallet_topup_screen.dart';

// A single chart data point with its real date.
class _ChartPoint {
  final DateTime date;
  final double priceInr;
  const _ChartPoint(this.date, this.priceInr);
}

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> with LocaleAwareMixin {
  final _service = GoldService();
  Wallet?    _wallet;
  GoldPrice? _goldPrice;
  GoldPrice? _silverPrice;
  LivePrice? _liveGold;
  LivePrice? _liveSilver;
  bool _loading       = true;
  bool _chartLoading  = false;
  String? _error;
  String _range = '3M';

  // Real historical chart data from Yahoo Finance.
  List<_ChartPoint> _chartPoints = [];

  @override
  void initState() {
    super.initState();
    LivePriceService.instance.addListener(_onLivePriceUpdate);
    _refresh();
  }

  @override
  void dispose() {
    LivePriceService.instance.removeListener(_onLivePriceUpdate);
    super.dispose();
  }

  void _onLivePriceUpdate() {
    if (!mounted) return;
    setState(() {
      _liveGold   = LivePriceService.instance.goldPrice;
      _liveSilver = LivePriceService.instance.silverPrice;
    });
  }

  Future<void> _refresh() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _service.myWallet(),
        _service.currentPrice(),
        _service.currentSilverPrice(),
      ]);
      if (!mounted) return;
      setState(() {
        _wallet      = results[0] as Wallet?;
        _goldPrice   = results[1] as GoldPrice?;
        _silverPrice = results[2] as GoldPrice?;
        _loading     = false;
      });
      await Future.wait([_refreshLive(), _fetchChartData(_range)]);
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _refreshLive() async {
    await LivePriceService.instance.fetchAll();
  }

  // ── Yahoo Finance historical data ──────────────────────────────
  // Maps our range labels to Yahoo Finance API params.
  static const _rangeParams = {
    '1M': ('1d',  '1mo'),
    '3M': ('1d',  '3mo'),
    '6M': ('1wk', '6mo'),
    '1Y': ('1wk', '1y'),
    '3Y': ('1mo', '3y'),
  };

  Future<void> _fetchChartData(String range) async {
    setState(() => _chartLoading = true);
    try {
      final p = _rangeParams[range] ?? ('1d', '3mo');
      final interval = p.$1;
      final period   = p.$2;
      final symbol   = Uri.encodeComponent('GC=F'); // Gold futures
      final url = Uri.parse(
        'https://query1.finance.yahoo.com/v8/finance/chart/$symbol'
        '?interval=$interval&range=$period',
      );
      final resp = await http.get(url, headers: {
        'User-Agent': 'Mozilla/5.0',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 12));

      if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
      final json   = jsonDecode(resp.body);
      final result = json['chart']['result'][0];
      final timestamps = (result['timestamp'] as List).cast<int>();
      final closes = (result['indicators']['quote'][0]['close'] as List)
          .map((v) => v == null ? null : (v as num).toDouble())
          .toList();

      final usd2inr = LivePriceService.instance.usdToInr;
      const gramsPerTroyOz = 31.1035;

      final points = <_ChartPoint>[];
      for (int i = 0; i < timestamps.length; i++) {
        final close = closes[i];
        if (close == null) continue;
        final date   = DateTime.fromMillisecondsSinceEpoch(timestamps[i] * 1000);
        final inrPerG = (close * usd2inr) / gramsPerTroyOz;
        points.add(_ChartPoint(date, inrPerG));
      }

      if (!mounted) return;
      setState(() => _chartPoints = points);
    } catch (_) {
      // Fall back to whatever we have; chart will use synthetic data.
    } finally {
      if (mounted) setState(() => _chartLoading = false);
    }
  }

  double get _currentGoldRate =>
      _liveGold?.inrPerGram ?? _goldPrice?.pricePerGram ?? 0;

  double get _currentSilverRate =>
      _liveSilver?.inrPerGram ?? _silverPrice?.pricePerGram ?? 0;

  // ── Percent change across chart data ──────────────────────────
  double _percentChange() {
    if (_chartPoints.length < 2) return 0;
    final oldest = _chartPoints.first.priceInr;
    final newest = _chartPoints.last.priceInr;
    if (oldest == 0) return 0;
    return ((newest - oldest) / oldest) * 100;
  }

  // ── Build FlSpots from chart points ───────────────────────────
  List<FlSpot> _chartSpots() {
    if (_chartPoints.length >= 2) {
      return [
        for (int i = 0; i < _chartPoints.length; i++)
          FlSpot(i.toDouble(), _chartPoints[i].priceInr),
      ];
    }
    // Synthetic fallback when no data yet
    final rate = _currentGoldRate == 0 ? 7250.0 : _currentGoldRate;
    final rng  = math.Random(42);
    final pts  = <FlSpot>[];
    double v   = rate * 0.92;
    for (int i = 0; i < 29; i++) {
      v += (rng.nextDouble() - 0.44) * (rate * 0.015);
      v  = v.clamp(rate * 0.85, rate * 1.1);
      pts.add(FlSpot(i.toDouble(), v));
    }
    pts.add(FlSpot(29, rate));
    return pts;
  }

  // ── How to format a date on the X axis based on current range ─
  String _xLabel(DateTime date) {
    switch (_range) {
      case '1M': return DateFormat('d MMM').format(date);   // "3 May"
      case '3M': return DateFormat('d MMM').format(date);   // "15 Mar"
      case '6M': return DateFormat('MMM').format(date);      // "Jan"
      case '1Y': return DateFormat('MMM yy').format(date);  // "Jan 24"
      case '3Y': return DateFormat('MMM yy').format(date);  // "Mar 22"
      default:   return DateFormat('d MMM').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu, color: AppColors.gold),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.diamond, size: 18, color: AppColors.gold),
            const SizedBox(width: 8),
            Text(Translations.of('app.name'),
                style: GoogleFonts.inter(
                    color: AppColors.gold,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: AppColors.gold),
            onPressed: _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 36),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Error: $_error',
                        style: const TextStyle(color: AppColors.danger)),
                  )
                else ...[
                  _heroPromoCard(),
                  const SizedBox(height: 20),
                  _priceTrendsHeader(),
                  const SizedBox(height: 8),
                  _priceChart(),
                  const SizedBox(height: 4),
                  _chartCaption(),
                  const SizedBox(height: 6),
                  _rangeSelector(),
                  const SizedBox(height: 18),
                  _livePricesBanner(),
                  const SizedBox(height: 10),
                  _walletSummary(),
                  const SizedBox(height: 18),
                  _buyGoldButton(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _featureCard(
                          gradient: const [Color(0xFF323232), Color(0xFF1A1A1A)],
                          icon: Icons.account_balance_outlined,
                          tagColor: AppColors.gold,
                          title: Translations.of('dash.savingPlan'),
                          onTap: () => _open(const WalletTopUpScreen()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _featureCard(
                          gradient: const [Color(0xFF3A2E10), Color(0xFF1F1A0C)],
                          icon: Icons.diamond_outlined,
                          tagColor: AppColors.gold,
                          title: Translations.of('dash.perfectInvest'),
                          onTap: () => _open(const BuyGoldScreen(metal: 'gold')),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _silverShortcut(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  //   COMPONENTS
  // ============================================================

  Widget _heroPromoCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF1D689), Color(0xFFD9B556)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.diamond, color: AppColors.textOnGold, size: 36),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Translations.of('dash.promoTitle'),
                    style: GoogleFonts.inter(
                        color: AppColors.textOnGold, fontSize: 14,
                        fontWeight: FontWeight.w700, height: 1.25)),
                const SizedBox(height: 4),
                Text(Translations.of('dash.promoSub'),
                    style: GoogleFonts.inter(
                        color: AppColors.textOnGold.withOpacity(0.8),
                        fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceTrendsHeader() {
    final pct      = _percentChange();
    final positive = pct >= 0;
    return Row(
      children: [
        Text(Translations.of('dash.goldTrends'),
            style: GoogleFonts.inter(
                color: AppColors.textOnDark,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        const Spacer(),
        Text(_range.toLowerCase(),
            style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: (positive ? AppColors.success : AppColors.danger)
                .withOpacity(0.18),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                positive ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                color: positive ? AppColors.success : AppColors.danger,
                size: 18,
              ),
              Text(
                '${pct.toStringAsFixed(2)}%',
                style: TextStyle(
                  color: positive ? AppColors.success : AppColors.danger,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _priceChart() {
    final spots    = _chartSpots();
    final ys       = spots.map((s) => s.y).toList();
    final minY     = ys.reduce(math.min);
    final maxY     = ys.reduce(math.max);
    final yRange   = maxY - minY;
    final yPad     = yRange * 0.12;
    final chartMinY = minY - yPad;
    final chartMaxY = maxY + yPad;
    final interval  = _niceInterval(yRange + 2 * yPad, 4);
    final n         = spots.length;

    // Choose ~4–5 x-axis tick positions evenly spaced
    final xStep = math.max(1, (n / 5).floor()).toDouble();

    return Stack(
      children: [
        Container(
          height: 240,
          padding: const EdgeInsets.only(right: 8, top: 12, bottom: 4),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: LineChart(
            LineChartData(
              minY: chartMinY,
              maxY: chartMaxY,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: true,
                drawHorizontalLine: true,
                horizontalInterval: interval,
                verticalInterval: xStep,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: AppColors.gold.withOpacity(0.07),
                  strokeWidth: 1,
                ),
                getDrawingVerticalLine: (_) => FlLine(
                  color: AppColors.muted.withOpacity(0.08),
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 58,
                    interval: interval,
                    getTitlesWidget: (value, meta) {
                      if (value == meta.min || value == meta.max) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(
                          _shortInr(value),
                          style: const TextStyle(
                              color: AppColors.muted, fontSize: 9),
                          textAlign: TextAlign.right,
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    interval: xStep,
                    getTitlesWidget: (value, meta) {
                      if (value == meta.max) return const SizedBox.shrink();
                      final idx = value.round();
                      if (idx < 0 || idx >= _chartPoints.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          _xLabel(_chartPoints[idx].date),
                          style: const TextStyle(
                              color: AppColors.muted, fontSize: 9),
                        ),
                      );
                    },
                  ),
                ),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.25,
                  barWidth: 2.5,
                  color: AppColors.gold,
                  dotData: FlDotData(
                    show: true,
                    checkToShowDot: (s, _) => s == spots.last,
                    getDotPainter: (s, _, __, ___) => FlDotCirclePainter(
                      radius: 5,
                      color: AppColors.gold,
                      strokeWidth: 2.5,
                      strokeColor: AppColors.charcoal,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        AppColors.gold.withOpacity(0.22),
                        AppColors.gold.withOpacity(0.0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
              lineTouchData: LineTouchData(
                handleBuiltInTouches: true,
                getTouchedSpotIndicator: (barData, spotIndexes) =>
                    spotIndexes.map((i) => TouchedSpotIndicatorData(
                          FlLine(
                            color: AppColors.gold.withOpacity(0.4),
                            strokeWidth: 1.5,
                            dashArray: [4, 4],
                          ),
                          FlDotData(
                            getDotPainter: (s, _, __, ___) =>
                                FlDotCirclePainter(
                              radius: 5,
                              color: AppColors.gold,
                              strokeWidth: 2,
                              strokeColor: AppColors.charcoal,
                            ),
                          ),
                        )).toList(),
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) =>
                      AppColors.cardElevated.withOpacity(0.97),
                  tooltipRoundedRadius: 10,
                  tooltipPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  getTooltipItems: (touchedSpots) =>
                      touchedSpots.map((s) {
                    final idx = s.spotIndex;
                    final dateStr = idx < _chartPoints.length
                        ? DateFormat('d MMM yyyy')
                            .format(_chartPoints[idx].date)
                        : '';
                    return LineTooltipItem(
                      '${formatInr(s.y)}\n',
                      const TextStyle(
                          color: AppColors.gold,
                          fontWeight: FontWeight.w700,
                          fontSize: 13),
                      children: [
                        TextSpan(
                          text: dateStr,
                          style: const TextStyle(
                              color: AppColors.muted,
                              fontWeight: FontWeight.w400,
                              fontSize: 11),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
        // Loading overlay
        if (_chartLoading)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.charcoal.withOpacity(0.55),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                    color: AppColors.gold, strokeWidth: 2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _chartCaption() {
    String dateRange = '';
    if (_chartPoints.length >= 2) {
      final fmt = DateFormat('d MMM yyyy');
      dateRange =
          '${fmt.format(_chartPoints.first.date)} – ${fmt.format(_chartPoints.last.date)}';
    }
    return Row(
      children: [
        const Icon(Icons.show_chart, color: AppColors.muted, size: 11),
        const SizedBox(width: 4),
        Text('Gold (24K) · INR/g',
            style: const TextStyle(color: AppColors.muted, fontSize: 10)),
        if (dateRange.isNotEmpty) ...[
          const SizedBox(width: 6),
          const Text('·', style: TextStyle(color: AppColors.muted, fontSize: 10)),
          const SizedBox(width: 6),
          Text(dateRange,
              style: const TextStyle(color: AppColors.muted, fontSize: 10)),
        ],
        const Spacer(),
        Text('Yahoo Finance',
            style: TextStyle(
                color: AppColors.muted.withOpacity(0.6), fontSize: 9)),
      ],
    );
  }

  double _niceInterval(double range, int targetTicks) {
    if (range <= 0) return 100;
    final rawStep = range / targetTicks;
    final mag     = math.pow(10, (math.log(rawStep) / math.ln10).floor());
    final norm    = rawStep / mag;
    double nice;
    if (norm <= 1)       nice = 1;
    else if (norm <= 2)  nice = 2;
    else if (norm <= 5)  nice = 5;
    else                 nice = 10;
    return nice * mag;
  }

  String _shortInr(double v) {
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000)   return '₹${(v / 1000).toStringAsFixed(1)}K';
    return '₹${v.toStringAsFixed(0)}';
  }

  Widget _rangeSelector() {
    final ranges = ['1M', '3M', '6M', '1Y', '3Y'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: ranges.map((r) {
        final selected = r == _range;
        return GestureDetector(
          onTap: () {
            setState(() => _range = r);
            _fetchChartData(r);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color:  selected ? AppColors.gold : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? AppColors.gold : AppColors.muted,
              ),
            ),
            child: Text(r,
                style: TextStyle(
                  color: selected ? AppColors.textOnGold : AppColors.muted,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                )),
          ),
        );
      }).toList(),
    );
  }

  // ---------- Live Prices Banner ----------
  Widget _livePricesBanner() {
    final fmt      = DateFormat('h:mm a');
    final fetching = LivePriceService.instance.isFetching;

    String goldSub() {
      if (fetching && _liveGold == null) return Translations.of('common.fetching');
      if (_liveGold == null) return LivePriceService.instance.lastUpdatedLabel;
      return 'Updated ${fmt.format(_liveGold!.fetchedAt.toLocal())}';
    }

    String silverSub() {
      if (fetching && _liveSilver == null) return Translations.of('common.fetching');
      if (_liveSilver == null) return LivePriceService.instance.lastUpdatedLabel;
      return 'Updated ${fmt.format(_liveSilver!.fetchedAt.toLocal())}';
    }

    return Row(
      children: [
        Expanded(child: _livePriceTile(
          label: Translations.of('dash.liveGold'),
          icon: Icons.circle,
          iconColor: AppColors.gold,
          price: _currentGoldRate == 0 ? '—' : '${formatInr(_currentGoldRate)} / g',
          subtitle: goldSub(),
          gradient: const [Color(0xFF2A2208), Color(0xFF1A1500)],
          borderColor: AppColors.gold,
        )),
        const SizedBox(width: 10),
        Expanded(child: _livePriceTile(
          label: Translations.of('dash.liveSilver'),
          icon: Icons.circle,
          iconColor: const Color(0xFFB0BEC5),
          price: _currentSilverRate == 0
              ? '—'
              : '${formatInr(_currentSilverRate)} / g',
          subtitle: silverSub(),
          gradient: const [Color(0xFF1C2025), Color(0xFF111417)],
          borderColor: const Color(0xFF6B7B8C),
        )),
      ],
    );
  }

  Widget _livePriceTile({
    required String label,
    required IconData icon,
    required Color iconColor,
    required String price,
    required String subtitle,
    required List<Color> gradient,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: iconColor, size: 8),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(color: AppColors.muted, fontSize: 11)),
          ]),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(price,
                style: GoogleFonts.inter(
                    color: iconColor, fontSize: 15,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 3),
          Text(subtitle,
              style: const TextStyle(color: AppColors.muted, fontSize: 9)),
        ],
      ),
    );
  }

  Widget _walletSummary() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppColors.cardBg, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Expanded(child: _kv(
            Translations.of('dash.wallet'),
            formatInr(_wallet?.cashBalance ?? 0),
            footer: Translations.of('dash.cashBalance'),
          )),
          _vDivider(),
          Expanded(child: _kv(
            Translations.of('dash.myGold'),
            formatGrams(_wallet?.goldGrams ?? 0),
            footer: Translations.of('dash.holdings'),
          )),
          _vDivider(),
          Expanded(child: _kv(
            Translations.of('dash.mySilver'),
            formatGrams(_wallet?.silverGrams ?? 0),
            footer: Translations.of('dash.holdings'),
          )),
        ],
      ),
    );
  }

  Widget _kv(String label, String value, {String? footer}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: AppColors.muted, fontSize: 11)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value,
              maxLines: 1,
              style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
        ),
        if (footer != null) ...[
          const SizedBox(height: 2),
          Text(footer,
              style: const TextStyle(color: AppColors.muted, fontSize: 9)),
        ],
      ],
    );
  }

  Widget _vDivider() => Container(
        width: 1, height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        color: const Color(0xFF333333),
      );

  Widget _buyGoldButton() {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: () => _open(const BuyGoldScreen(metal: 'gold')),
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFFE8C36A), Color(0xFFB88A2A)]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.auto_awesome,
                    color: AppColors.textOnGold, size: 18),
                const SizedBox(width: 8),
                Text(Translations.of('dash.buyGold'),
                    style: const TextStyle(
                      color: AppColors.textOnGold,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      fontSize: 15,
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _featureCard({
    required List<Color> gradient,
    required IconData icon,
    required String title,
    required Color tagColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        height: 120,
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.gold.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: tagColor.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: tagColor, size: 20),
            ),
            Text(title,
                style: GoogleFonts.inter(
                    color: AppColors.textOnDark,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    height: 1.3)),
          ],
        ),
      ),
    );
  }

  Widget _silverShortcut() {
    final silverTxt = _currentSilverRate == 0
        ? Translations.of('dash.silverTap')
        : 'Live: ${formatInr(_currentSilverRate)} / g';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF6B7B8C).withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: const Color(0xFF6B7B8C).withOpacity(0.2),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.workspace_premium_outlined,
                color: Color(0xFFB0BEC5), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Translations.of('dash.silverAvail'),
                    style: GoogleFonts.inter(
                        color: AppColors.textOnDark,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                Text(silverTxt,
                    style: TextStyle(
                      color: _currentSilverRate == 0
                          ? AppColors.muted
                          : const Color(0xFFB0BEC5),
                      fontSize: 11,
                      fontWeight: _currentSilverRate == 0
                          ? FontWeight.w400
                          : FontWeight.w600,
                    )),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () => _open(const BuyGoldScreen(metal: 'silver')),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 36),
              foregroundColor: const Color(0xFFB0BEC5),
              side: const BorderSide(color: Color(0xFF6B7B8C)),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            child: Text(Translations.of('dash.buySilver')),
          ),
        ],
      ),
    );
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => screen));
    _refresh();
  }
}
