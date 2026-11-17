import '../main.dart';
import '../models/gold_price.dart';
import '../models/transaction.dart';
import '../models/wallet.dart';
import '../models/jewellery_item.dart';

/// Metal (gold + silver) + wallet operations.
///
/// All write paths go through Postgres functions (RPCs) defined as
/// SECURITY DEFINER so balance changes happen atomically inside the DB.
class GoldService {
  // ---------- Live prices ----------
  Future<GoldPrice?> currentPrice() => _currentPrice('gold_prices');
  Future<GoldPrice?> currentSilverPrice() =>
      _currentPrice('silver_prices');

  Future<GoldPrice?> _currentPrice(String table) async {
    final row = await supabase
        .from(table)
        .select()
        .order('effective_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    return GoldPrice.fromMap(row);
  }

  Future<List<GoldPrice>> priceHistory({
    int limit = 30,
    String metal = 'gold',
  }) async {
    final table = metal == 'silver' ? 'silver_prices' : 'gold_prices';
    final rows = await supabase
        .from(table)
        .select()
        .order('effective_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((m) => GoldPrice.fromMap(m as Map<String, dynamic>))
        .toList();
  }

  // ---------- Wallet ----------
  Future<Wallet?> myWallet() async {
    final user = supabase.auth.currentUser;
    if (user == null) return null;
    final row = await supabase
        .from('wallets')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();
    if (row == null) return null;
    return Wallet.fromMap(row);
  }

  Future<List<Txn>> myTransactions({int limit = 50}) async {
    final user = supabase.auth.currentUser;
    if (user == null) return [];
    final rows = await supabase
        .from('transactions')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((m) => Txn.fromMap(m as Map<String, dynamic>))
        .toList();
  }

  // ---------- Cash + buy/sell ----------
  Future<void> topUpWallet(double amountInr) async {
    await supabase.rpc('top_up_wallet', params: {'p_amount': amountInr});
  }

  /// Buy gold OR silver depending on [metal].
  Future<void> buyMetal({
    required String metal,
    required double amountInr,
  }) async {
    final rpc = metal == 'silver' ? 'buy_silver' : 'buy_gold';
    await supabase.rpc(rpc, params: {'p_amount_inr': amountInr});
  }

  /// Sell gold OR silver depending on [metal].
  Future<void> sellMetal({
    required String metal,
    required double grams,
  }) async {
    final rpc = metal == 'silver' ? 'sell_silver' : 'sell_gold';
    await supabase.rpc(rpc, params: {'p_grams': grams});
  }

  // Backwards-compatible shortcuts
  Future<void> buyGold(double amountInr) =>
      buyMetal(metal: 'gold', amountInr: amountInr);
  Future<void> sellGold(double grams) =>
      sellMetal(metal: 'gold', grams: grams);

  // ---------- Jewellery / redemption ----------
  Future<List<JewelleryItem>> jewelleryCatalog({String? metal}) async {
    final base = supabase
        .from('jewellery_catalog')
        .select()
        .eq('in_stock', true);
    final rows = await (metal == null
            ? base
            : base.eq('metal', metal))
        .order('metal')
        .order('category')
        .order('weight_grams');
    return (rows as List)
        .map((m) => JewelleryItem.fromMap(m as Map<String, dynamic>))
        .toList();
  }

  Future<void> requestRedemption({
    required String itemId,
    required String shippingAddress,
  }) async {
    await supabase.rpc('request_redemption', params: {
      'p_item_id': itemId,
      'p_shipping_address': shippingAddress,
    });
  }

  // ---------- Admin ----------
  Future<void> updateGoldPrice(double pricePerGram) async {
    await supabase.from('gold_prices').insert({
      'price_per_gram': pricePerGram,
      'currency': 'INR',
    });
  }

  Future<void> updateSilverPrice(double pricePerGram) async {
    await supabase.from('silver_prices').insert({
      'price_per_gram': pricePerGram,
      'currency': 'INR',
    });
  }
}
