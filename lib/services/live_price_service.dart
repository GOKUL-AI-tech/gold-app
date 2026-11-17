import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// Singleton live-price service for Gold Century.
///
/// Data sources (both FREE, no API key required):
///   Gold / Silver : Yahoo Finance chart API (GC=F / SI=F futures)
///   USD → INR     : https://open.er-api.com/v6/latest/USD
///
/// Features:
///   • Fetches gold, silver and forex in parallel on first call.
///   • Auto-refreshes every [refreshInterval] while the app is open.
///   • Exposes [ChangeNotifier] so any widget can `addListener` and rebuild.
///   • Pushes a daily price snapshot to Supabase (gold_prices / silver_prices).
/// ─────────────────────────────────────────────────────────────────────────────
class LivePriceService extends ChangeNotifier {
  // ── Singleton ───────────────────────────────────────────────────
  LivePriceService._();
  static final LivePriceService instance = LivePriceService._();

  // ── API endpoints ───────────────────────────────────────────────
  /// Yahoo Finance chart API — no API key needed.
  /// GC=F = Gold Futures (USD/troy-oz), SI=F = Silver Futures (USD/troy-oz).
  static const _goldUrl   =
      'https://query1.finance.yahoo.com/v8/finance/chart/GC%3DF?interval=1d&range=1d';
  static const _silverUrl =
      'https://query1.finance.yahoo.com/v8/finance/chart/SI%3DF?interval=1d&range=1d';
  static const _forexUrl  = 'https://open.er-api.com/v6/latest/USD';

  // ── Constants ───────────────────────────────────────────────────
  static const double gramsPerTroyOunce = 31.1034768;

  /// How often to silently refresh in the background.
  static const Duration refreshInterval = Duration(minutes: 5);

  // ── State ───────────────────────────────────────────────────────
  LivePrice? goldPrice;
  LivePrice? silverPrice;
  double     usdToInr   = 84.5;   // fallback until forex fetch completes
  DateTime?  lastFetched;
  bool       isFetching = false;
  String?    error;

  Timer?    _timer;
  DateTime? _lastDbWrite;

  // ── Public API ──────────────────────────────────────────────────

  /// Call once from HomeScreen.initState. Fetches immediately and
  /// starts the 5-minute background refresh timer.
  void startAutoRefresh() {
    fetchAll();
    _timer?.cancel();
    _timer = Timer.periodic(refreshInterval, (_) => fetchAll());
  }

  void stopAutoRefresh() {
    _timer?.cancel();
    _timer = null;
  }

  /// Manually trigger a refresh (e.g. pull-to-refresh).
  Future<void> fetchAll() async {
    if (isFetching) return;
    isFetching = true;
    error      = null;
    notifyListeners();

    try {
      await _fetchForex();
      await Future.wait([_fetchGold(), _fetchSilver()]);

      lastFetched = DateTime.now();
      dev.log(
        'LivePriceService: gold=${goldPrice?.inrPerGram?.toStringAsFixed(2)} '
        'silver=${silverPrice?.inrPerGram?.toStringAsFixed(2)} '
        'USD/INR=${usdToInr.toStringAsFixed(2)}',
        name: 'LivePrice',
      );

      _maybePushToDb();
    } catch (e, st) {
      error = e.toString();
      dev.log('LivePriceService: fetchAll failed — $e',
          name: 'LivePrice', error: e, stackTrace: st);
    } finally {
      isFetching = false;
      notifyListeners();
    }
  }

  // ── Forex ───────────────────────────────────────────────────────

  Future<void> _fetchForex() async {
    try {
      final res = await http
          .get(Uri.parse(_forexUrl))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data  = jsonDecode(res.body) as Map<String, dynamic>;
        final rates = data['rates'] as Map<String, dynamic>?;
        final inr   = (rates?['INR'] as num?)?.toDouble();
        if (inr != null && inr > 0) {
          usdToInr = inr;
          dev.log('LivePriceService: 1 USD = $inr INR', name: 'LivePrice');
        }
      }
    } catch (e) {
      dev.log('LivePriceService: forex failed — $e (fallback $usdToInr)',
          name: 'LivePrice');
    }
  }

  // ── Gold / Silver ───────────────────────────────────────────────

  Future<void> _fetchGold()   async => goldPrice   = await _fetchYahoo('XAU', _goldUrl);
  Future<void> _fetchSilver() async => silverPrice = await _fetchYahoo('XAG', _silverUrl);

  /// Parses a Yahoo Finance v8/finance/chart response.
  /// Returns null on any error so the UI gracefully falls back to DB price.
  Future<LivePrice?> _fetchYahoo(String symbol, String url) async {
    try {
      final res = await http.get(
        Uri.parse(url),
        headers: {
          // Yahoo sometimes blocks requests without a User-Agent header.
          'User-Agent': 'Mozilla/5.0 (compatible; GoldCenturyApp/1.0)',
          'Accept':     'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      dev.log('LivePriceService: $symbol HTTP ${res.statusCode}',
          name: 'LivePrice');

      if (res.statusCode != 200) return null;

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final chart = body['chart'] as Map<String, dynamic>?;
      if (chart == null) return null;

      final results = chart['result'] as List<dynamic>?;
      if (results == null || results.isEmpty) return null;

      final meta = results.first['meta'] as Map<String, dynamic>?;
      if (meta == null) return null;

      // Prefer regularMarketPrice; fall back to previousClose.
      final usdPerOz = _asDouble(meta['regularMarketPrice'])
          ?? _asDouble(meta['chartPreviousClose'])
          ?? _asDouble(meta['previousClose']);

      if (usdPerOz == null || usdPerOz <= 0) {
        dev.log('LivePriceService: $symbol price field missing in $meta',
            name: 'LivePrice');
        return null;
      }

      dev.log('LivePriceService: $symbol = \$$usdPerOz / oz', name: 'LivePrice');

      return LivePrice(
        symbol:      symbol,
        usdPerOunce: usdPerOz,
        inrPerGram:  (usdPerOz * usdToInr) / gramsPerTroyOunce,
        fetchedAt:   DateTime.now(),
      );
    } catch (e, st) {
      dev.log('LivePriceService: error fetching $symbol — $e',
          name: 'LivePrice', error: e, stackTrace: st);
      return null;
    }
  }

  double? _asDouble(dynamic v) =>
      v == null ? null : (v as num).toDouble();

  // ── Daily Supabase push ─────────────────────────────────────────

  void _maybePushToDb() {
    final now = DateTime.now();
    if (_lastDbWrite != null &&
        now.difference(_lastDbWrite!).inHours < 20) return;
    _lastDbWrite = now;
    _pushToDb();
  }

  Future<void> _pushToDb() async {
    try {
      final client = Supabase.instance.client;
      final now    = DateTime.now().toUtc().toIso8601String();

      if (goldPrice != null) {
        await client.from('gold_prices').upsert({
          'price_per_gram': goldPrice!.inrPerGram,
          'recorded_at':    now,
        }, onConflict: 'recorded_at');
      }
      if (silverPrice != null) {
        await client.from('silver_prices').upsert({
          'price_per_gram': silverPrice!.inrPerGram,
          'recorded_at':    now,
        }, onConflict: 'recorded_at');
      }
      dev.log('LivePriceService: daily snapshot pushed to Supabase',
          name: 'LivePrice');
    } catch (e) {
      dev.log('LivePriceService: Supabase push failed — $e',
          name: 'LivePrice');
    }
  }

  // ── Convenience getters ─────────────────────────────────────────

  double get goldInrPerGram   => goldPrice?.inrPerGram   ?? 0;
  double get silverInrPerGram => silverPrice?.inrPerGram ?? 0;

  String get lastUpdatedLabel {
    if (lastFetched == null) return '—';
    final diff = DateTime.now().difference(lastFetched!);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}

// ── Data model ────────────────────────────────────────────────────

class LivePrice {
  final String   symbol;
  final double   usdPerOunce;
  final double   inrPerGram;
  final DateTime fetchedAt;

  const LivePrice({
    required this.symbol,
    required this.usdPerOunce,
    required this.inrPerGram,
    required this.fetchedAt,
  });
}
