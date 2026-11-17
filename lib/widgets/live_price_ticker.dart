import 'package:flutter/material.dart';

import '../services/live_price_service.dart';
import '../theme/app_theme.dart';
import 'money.dart';

/// A compact two-card strip showing the live gold and silver prices
/// (per gram, INR). Used on dashboards and money-flow screens so
/// users always see what their next trade will execute against.
///
/// Auto-fetches on mount; tap the refresh icon to re-fetch.
class LivePriceTicker extends StatefulWidget {
  const LivePriceTicker({super.key});

  @override
  State<LivePriceTicker> createState() => _LivePriceTickerState();
}

class _LivePriceTickerState extends State<LivePriceTicker> {
  LivePriceService get _svc => LivePriceService.instance;

  @override
  void initState() {
    super.initState();
    _svc.addListener(_onUpdate);
    // Trigger a fetch only if we have no cached data yet.
    if (_svc.goldPrice == null) _svc.fetchAll();
  }

  @override
  void dispose() {
    _svc.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _refresh() async {
    await _svc.fetchAll();
  }

  @override
  Widget build(BuildContext context) {
    final loading = _svc.isFetching;
    return Row(
      children: [
        Expanded(
          child: _PriceCell(
            label: 'GOLD',
            color: AppColors.gold,
            accent: AppColors.darkGold,
            price: _svc.goldPrice?.inrPerGram,
            loading: loading,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _PriceCell(
            label: 'SILVER',
            color: const Color(0xFFB0BEC5),
            accent: const Color(0xFF6B7B8C),
            price: _svc.silverPrice?.inrPerGram,
            loading: loading,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: loading ? null : _refresh,
          icon: const Icon(Icons.refresh, color: AppColors.gold),
          tooltip: 'Refresh prices',
        ),
      ],
    );
  }
}

class _PriceCell extends StatelessWidget {
  final String label;
  final Color color;
  final Color accent;
  final double? price;
  final bool loading;

  const _PriceCell({
    required this.label,
    required this.color,
    required this.accent,
    required this.price,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.danger,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: AppColors.danger.withOpacity(0.5),
                    blurRadius: 6),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    loading
                        ? '…'
                        : (price == null
                            ? '—'
                            : '${formatInr(price!)} / g'),
                    maxLines: 1,
                    style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
