class FundModel {
  final int? id;
  final String name; // 'BOS Fund', 'Other Fund', etc.
  final double balance;

  FundModel({this.id, required this.name, required this.balance});

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'balance': balance};
  }

  factory FundModel.fromMap(Map<String, dynamic> map) {
    return FundModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      balance: (map['balance'] as num).toDouble(),
    );
  }

  FundModel copyWith({int? id, String? name, double? balance}) {
    return FundModel(
      id: id ?? this.id,
      name: name ?? this.name,
      balance: balance ?? this.balance,
    );
  }
}
