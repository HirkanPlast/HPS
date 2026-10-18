class Expense {
  final int? id;
  final String date; // Shamsi YYYY/MM/DD
  final String category; // اجاره، برق، حقوق، حمل، سایر
  final String title;
  final double amount;
  final String? notes;
  final DateTime createdAt;

  Expense({
    this.id,
    required this.date,
    required this.category,
    required this.title,
    required this.amount,
    this.notes,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'category': category,
      'title': title,
      'amount': amount,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as int?,
      date: map['date'] as String,
      category: map['category'] as String,
      title: map['title'] as String,
      amount: (map['amount'] as num).toDouble(),
      notes: map['notes'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
    );
  }
}
