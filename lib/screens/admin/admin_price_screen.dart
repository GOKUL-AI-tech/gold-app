import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../models/gold_price.dart';
import '../../services/gold_service.dart';
import '../../services/live_price_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/money.dart';

class AdminPriceScreen extends StatefulWidget {
  const AdminPriceScreen({super.key});

  @override
  State<AdminPriceScreen> createState() => _AdminPriceScreenState();
}

class _AdminPriceScreenState extends State<AdminPriceScreen>
    with SingleTickerProviderStateMixin {
  final _service = GoldService();
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.charcoal,
      appBar: AppBar(
        backgroundColor: AppColors.charcoal,
        iconTheme: const IconThemeData(color: AppColors.gold),
        title: Text('Update Metal Price',
            style: GoogleFonts.inter(
                color: AppColors.gold,
                fontSize: 17,
                fontWeight: FontWeight.w700)),
        bottom: TabBar(
          controller: _tab,
          labelColor: AppColors.gold,
          unselectedLabelColor: AppColors.muted,
          indicatorColor: AppColors.gold,
          labelStyle:
              GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
          unselectedLabelStyle: GoogleFonts.inter(fontSize: 14),
          tabs: const [Tab(text: 'Gold'), Tab(text: 'Silver')],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _PricePane(metal: 'gold'),
          _PricePane(metal: 'silver'),
        ],
      ),
    );
  }
}

class _PricePane extends StatefulWidget {
  final String metal;
  const _PricePane({required this.metal});

  @override
  State<_PricePane> createState() => _PricePaneState();
}

class _PricePaneState extends State<_PricePane> {
  final _service = GoldService();
  final _live    = LivePriceService.instance;
  final _ctrl    = TextEditingController();

  GoldPrice?      _current;
  List<GoldPrice> _history     = [];
  bool _loading      = true;
  bool _syncing      = false; // auto-sync in progress
  bool _submitting   = false; // manual publish in progress
  String? _syncStatus;        // short status message shown under current price

  bool get _isSilver => widget.metal == 'silver';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Full refresh: fetch live price → auto-sync → reload DB record + history.
  Future<void> _refresh() async {
    setState(() { _loading = true; _syncStatus = null; });
    try {
      // 1. fetch live spot
      await _live.fetchAll();
      final spot = _isSilver ? _live.silverPrice : _live.goldPrice;

      // 2. auto-sync to DB if we got a live price
      if (spot != null) {
        final p = double.parse(spot.inrPerGram.toStringAsFixed(2));
        if (_isSilver) {
          await _service.updateSilverPrice(p);
        } else {
          await _service.updateGoldPrice(p);
        }
        if (mounted) setState(() => _syncStatus = 'Auto-synced from live market');
      }
    } catch (_) {
      // silently fall through — DB price stays unchanged
    }

    // 3. reload current DB record and history
    try {
      final cur = _isSilver
          ? await _service.currentSilverPrice()
          : await _service.currentPrice();
      final history =
          await _service.priceHistory(limit: 20, metal: widget.metal);
      if (!mounted) return;
      setState(() {
        _current = cur;
        _history = history;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Manual re-sync triggered by the refresh icon.
  Future<void> _manualSync() async {
    setState(() { _syncing = true; _syncStatus = null; });
    try {
      await _live.fetchAll();
      final spot = _isSilver ? _live.silverPrice : _live.goldPrice;
      if (spot == null) throw Exception('No live data');
      final p = double.parse(spot.inrPerGram.toStringAsFixed(2));
      if (_isSilver) {
        await _service.updateSilverPrice(p);
      } else {
        await _service.updateGoldPrice(p);
      }
      if (!mounted) return;
      setState(() => _syncStatus = 'Synced from live market');
      await _reloadCurrentAndHistory();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e')));
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _reloadCurrentAndHistory() async {
    final cur = _isSilver
        ? await _service.currentSilverPrice()
        : await _service.currentPrice();
    final history =
        await _service.priceHistory(limit: 20, metal: widget.metal);
    if (!mounted) return;
    setState(() { _current = cur; _history = history; });
  }

  Future<void> _submitManual() async {
    final p = double.tryParse(_ctrl.text.trim());
    if (p == null || p <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid price')));
      return;
    }
    setState(() => _submitting = true);
    try {
      _isSilver
          ? await _service.updateSilverPrice(p)
          : await _service.updateGoldPrice(p);
      _ctrl.clear();
      if (!mounted) return;
      setState(() => _syncStatus = 'Manual price set: ${formatInr(p)} / g');
      await _reloadCurrentAndHistory();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'New ${widget.metal} price: ${formatInr(p)} / g')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Update failed: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt    = DateFormat('dd MMM yyyy, h:mm a');
    final accent = _isSilver ? const Color(0xFFB0BEC5) : AppColors.gold;
    final live   = _isSilver ? _live.silverPrice : _live.goldPrice;

    if (_loading) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(color: AppColors.gold),
          const SizedBox(height: 14),
          Text('Fetching live ${widget.metal} price…',
              style: const TextStyle(color: AppColors.muted, fontSize: 13)),
        ]),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Current price (= live synced) ──
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withOpacity(0.35), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text('Current ${widget.metal} price',
                    style: TextStyle(
                        color: accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                // Refresh / re-sync button
                SizedBox(
                  width: 32, height: 32,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    tooltip: 'Re-sync from live market',
                    icon: _syncing
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.gold))
                        : Icon(Icons.sync, size: 18, color: accent),
                    onPressed: _syncing ? null : _manualSync,
                  ),
                ),
              ]),
              const SizedBox(height: 6),
              Text(
                _current == null
                    ? '—'
                    : '${formatInr(_current!.pricePerGram)} / g',
                style: GoogleFonts.inter(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textOnDark),
              ),
              const SizedBox(height: 4),
              if (_current != null)
                Text(
                  'Updated ${fmt.format(_current!.effectiveAt.toLocal())}',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.muted),
                ),
              if (live != null) ...[
                const SizedBox(height: 2),
                Text(
                  'USD ${live.usdPerOunce.toStringAsFixed(2)} / troy oz'
                  ' @ ₹${_live.usdToInr.toStringAsFixed(2)}/USD',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.muted),
                ),
              ],
              if (_syncStatus != null) ...[
                const SizedBox(height: 6),
                Row(children: [
                  Icon(Icons.check_circle_outline,
                      size: 13, color: AppColors.success),
                  const SizedBox(width: 4),
                  Text(_syncStatus!,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.success)),
                ]),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── Manual override ──
        const Divider(color: Color(0xFF333333)),
        const SizedBox(height: 14),
        Text('Or set a custom price manually',
            style: GoogleFonts.inter(
                color: AppColors.textOnDark,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        TextField(
          controller: _ctrl,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: AppColors.textOnDark),
          decoration: InputDecoration(
            hintText: 'New price per gram (₹)',
            hintStyle: const TextStyle(color: AppColors.muted),
            prefixIcon: const Icon(Icons.currency_rupee,
                color: AppColors.muted),
            filled: true,
            fillColor: AppColors.cardBg,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: accent, width: 1.5)),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _submitting ? null : _submitManual,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.charcoal,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              _submitting ? 'Saving…' : 'Publish New Price',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
        ),
        const SizedBox(height: 28),

        // ── History ──
        Text('Recent price changes',
            style: GoogleFonts.inter(
                color: AppColors.textOnDark,
                fontWeight: FontWeight.w700,
                fontSize: 15)),
        const SizedBox(height: 8),
        ..._history.map((p) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                Icon(Icons.history, color: accent, size: 18),
                const SizedBox(width: 12),
                Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${formatInr(p.pricePerGram)} / g',
                          style: GoogleFonts.inter(
                              color: AppColors.textOnDark,
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                      Text(fmt.format(p.effectiveAt.toLocal()),
                          style: const TextStyle(
                              color: AppColors.muted, fontSize: 11)),
                    ]),
              ]),
            )),
      ],
    );
  }
}
