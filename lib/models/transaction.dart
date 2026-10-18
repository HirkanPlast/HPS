class InventoryTransaction {
  final int? id;
  final String date; // Shamsi date YYYY/MM/DD
  final String type; // ورود، فروش، برگشت، تعدیل
  final String productCode;
  final double quantity;
  final double unitPrice;
  final String? notes;
  final String? createdBy;
  final DateTime createdAt;

  // Joined fields (not stored)
  final String? productName;
  final String? unit;

  InventoryTransaction({
    this.id,
    required this.date,
    required this.type,
    required this.productCode,
    required this.quantity,
    required this.unitPrice,
    this.notes,
    this.createdBy,
    DateTime? createdAt,
    this.productName,
    this.unit,
  }) : createdAt = createdAt ?? DateTime.now();

  double get totalAmount => quantity * unitPrice;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'type': type,
      'product_code': productCode,
      'quantity': quantity,
      'unit_price': unitPrice,
      'notes': notes,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory InventoryTransaction.fromMap(Map<String, dynamic> map) {
    return InventoryTransaction(
      id: map['id'] as int?,
      date: map['date'] as String,
      type: map['type'] as String,
      productCode: map['product_code'] as String,
      quantity: (map['quantity'] as num).toDouble(),
      unitPrice: (map['unit_price'] as num).toDouble(),
      notes: map['notes'] as String?,
      createdBy: map['created_by'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      productName: map['product_name'] as String?,
      unit: map['unit'] as String?,
    );
  }
}

/// Effect of each transaction type on stock
/// ورود: +qty
/// فروش: -qty
/// برگشت: +qty  (customer return)
/// تعدیل: can be positive or negative (user enters signed qty)
double stockDelta(String type, double quantity) {
  switch (type) {
    case 'ورود':
    case 'برگشت':
      return quantity.abs();
    case 'فروش':
      return -quantity.abs();
    case 'تعدیل':
      return quantity; // user can enter + or -
    default:
      return 0;
  }
}
