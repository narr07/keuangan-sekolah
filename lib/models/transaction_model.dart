class TransactionModel {
  final int? id;
  final String title;
  final String category; // 'BOS Fund', 'General', 'Building', etc.
  final double amount;
  final String type; // 'income' or 'expense'
  final DateTime date;
  final String? description;
  final String icon; // Material icon name

  TransactionModel({
    this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.type,
    required this.date,
    this.description,
    this.icon = 'receipt',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'amount': amount,
      'type': type,
      'date': date.toIso8601String(),
      'description': description,
      'icon': icon,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] as int?,
      title: map['title'] as String,
      category: map['category'] as String,
      amount: (map['amount'] as num).toDouble(),
      type: map['type'] as String,
      date: DateTime.parse(map['date'] as String),
      description: map['description'] as String?,
      icon: map['icon'] as String? ?? 'receipt',
    );
  }

  TransactionModel copyWith({
    int? id,
    String? title,
    String? category,
    double? amount,
    String? type,
    DateTime? date,
    String? description,
    String? icon,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      date: date ?? this.date,
      description: description ?? this.description,
      icon: icon ?? this.icon,
    );
  }
}
