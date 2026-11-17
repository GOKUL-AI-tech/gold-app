class GoldPrice {
  final String id;
  final double pricePerGram;
  final String currency;
  final DateTime effectiveAt;

  GoldPrice({
    required this.id,
    required this.pricePerGram,
    required this.currency,
    required this.effectiveAt,
  });

  factory GoldPrice.fromMap(Map<String, dynamic> map) {
    return GoldPrice(
      id: map['id'] as String,
      pricePerGram: (map['price_per_gram'] as num).toDouble(),
      currency: (map['currency'] as String?) ?? 'INR',
      effectiveAt: DateTime.tryParse(
              map['effective_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
