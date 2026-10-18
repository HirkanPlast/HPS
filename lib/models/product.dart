class Product {
  final int? id;
  final String code;
  final String name;
  final String category;
  final String unit;
  final double initialStock;
  final double minStock;
  final double buyPrice;
  final double sellPrice;
  final bool isActive;
  final String? notes;

  Product({
    this.id,
    required this.code,
    required this.name,
    required this.category,
    required this.unit,
    this.initialStock = 0,
    this.minStock = 0,
    this.buyPrice = 0,
    this.sellPrice = 0,
    this.isActive = true,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'category': category,
      'unit': unit,
      'initial_stock': initialStock,
      'min_stock': minStock,
      'buy_price': buyPrice,
      'sell_price': sellPrice,
      'is_active': isActive ? 1 : 0,
      'notes': notes,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int?,
      code: map['code'] as String,
      name: map['name'] as String,
      category: map['category'] as String? ?? '',
      unit: map['unit'] as String? ?? 'تعدادی',
      initialStock: (map['initial_stock'] as num?)?.toDouble() ?? 0,
      minStock: (map['min_stock'] as num?)?.toDouble() ?? 0,
      buyPrice: (map['buy_price'] as num?)?.toDouble() ?? 0,
      sellPrice: (map['sell_price'] as num?)?.toDouble() ?? 0,
      isActive: (map['is_active'] as int?) == 1,
      notes: map['notes'] as String?,
    );
  }

  Product copyWith({
    int? id,
    String? code,
    String? name,
    String? category,
    String? unit,
    double? initialStock,
    double? minStock,
    double? buyPrice,
    double? sellPrice,
    bool? isActive,
    String? notes,
  }) {
    return Product(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      initialStock: initialStock ?? this.initialStock,
      minStock: minStock ?? this.minStock,
      buyPrice: buyPrice ?? this.buyPrice,
      sellPrice: sellPrice ?? this.sellPrice,
      isActive: isActive ?? this.isActive,
      notes: notes ?? this.notes,
    );
  }
}
