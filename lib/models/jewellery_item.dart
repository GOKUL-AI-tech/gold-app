class JewelleryItem {
  final String id;
  final String name;
  final String? description;
  final double weightGrams;
  final double makingChargesInr;
  final String? imageUrl;
  final bool inStock;
  final String metal; // 'gold' or 'silver'
  final String category; // ring / necklace / chain / earrings / etc.

  JewelleryItem({
    required this.id,
    required this.name,
    this.description,
    required this.weightGrams,
    required this.makingChargesInr,
    this.imageUrl,
    required this.inStock,
    this.metal = 'gold',
    this.category = 'general',
  });

  factory JewelleryItem.fromMap(Map<String, dynamic> map) {
    return JewelleryItem(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      weightGrams: (map['weight_grams'] as num).toDouble(),
      makingChargesInr: (map['making_charges_inr'] as num).toDouble(),
      imageUrl: map['image_url'] as String?,
      inStock: (map['in_stock'] as bool?) ?? true,
      metal: (map['metal'] as String?) ?? 'gold',
      category: (map['category'] as String?) ?? 'general',
    );
  }

  String get categoryLabel {
    if (category.isEmpty) return 'General';
    return category[0].toUpperCase() + category.substring(1);
  }
}
