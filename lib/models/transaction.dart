enum TxnType {
  topUp,
  buyGold,
  sellGold,
  buySilver,
  sellSilver,
  redemption,
  adjustment,
}

TxnType _txnFromString(String? s) {
  switch (s) {
    case 'top_up':
      return TxnType.topUp;
    case 'buy_gold':
      return TxnType.buyGold;
    case 'sell_gold':
      return TxnType.sellGold;
    case 'buy_silver':
      return TxnType.buySilver;
    case 'sell_silver':
      return TxnType.sellSilver;
    case 'redemption':
      return TxnType.redemption;
    default:
      return TxnType.adjustment;
  }
}

class Txn {
  final String id;
  final String userId;
  final TxnType type;
  final double amountInr;
  final double goldGrams; // grams of metal (gold OR silver, schema column)
  final double pricePerGram;
  final String? note;
  final String status;
  final DateTime createdAt;

  Txn({
    required this.id,
    required this.userId,
    required this.type,
    required this.amountInr,
    required this.goldGrams,
    required this.pricePerGram,
    this.note,
    required this.status,
    required this.createdAt,
  });

  factory Txn.fromMap(Map<String, dynamic> map) {
    double parse(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    return Txn(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      type: _txnFromString(map['txn_type'] as String?),
      amountInr: parse(map['amount_inr']),
      goldGrams: parse(map['gold_grams']),
      pricePerGram: parse(map['price_per_gram']),
      note: map['note'] as String?,
      status: (map['status'] as String?) ?? 'completed',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  String get displayLabel {
    switch (type) {
      case TxnType.topUp:
        return 'Wallet Top-up';
      case TxnType.buyGold:
        return 'Bought Gold';
      case TxnType.sellGold:
        return 'Sold Gold';
      case TxnType.buySilver:
        return 'Bought Silver';
      case TxnType.sellSilver:
        return 'Sold Silver';
      case TxnType.redemption:
        return 'Jewellery Redemption';
      case TxnType.adjustment:
        return 'Adjustment';
    }
  }

  bool get isCredit =>
      type == TxnType.topUp ||
      type == TxnType.sellGold ||
      type == TxnType.sellSilver;
}
