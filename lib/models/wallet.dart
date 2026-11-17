class Wallet {
  final String userId;
  final double cashBalance;
  final double goldGrams;
  final double silverGrams;
  final DateTime updatedAt;

  Wallet({
    required this.userId,
    required this.cashBalance,
    required this.goldGrams,
    required this.silverGrams,
    required this.updatedAt,
  });

  factory Wallet.fromMap(Map<String, dynamic> map) {
    return Wallet(
      userId: map['user_id'] as String,
      cashBalance: _toDouble(map['cash_balance']),
      goldGrams: _toDouble(map['gold_grams']),
      silverGrams: _toDouble(map['silver_grams']),
      updatedAt:
          DateTime.tryParse(map['updated_at']?.toString() ?? '') ??
              DateTime.now(),
    );
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
}
