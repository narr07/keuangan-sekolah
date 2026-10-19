/// Jenis transaksi.
class TxType {
  static const income = 'income';
  static const expense = 'expense';
}

/// Sumber dana sebuah transaksi.
class FundSource {
  static const bos = 'BOS';
  static const lainnya = 'Lainnya';

  static const all = [bos, lainnya];

  static String label(String source) =>
      source == bos ? 'Dana BOS' : 'Dana Lainnya';
}

/// Kategori pemasukan yang dibuat otomatis dari pencairan BOS.
const kBosCategory = 'BOS Fund';

class TransactionModel {
  final int? id;
  final String title;
  final String category; // 'BOS Fund', 'Operasional', 'Sumbangan', dll.
  final double amount;
  final String type; // TxType.income / TxType.expense
  final DateTime date;
  final String? description;
  final String icon; // Material icon name
  final String fundSource; // FundSource.bos / FundSource.lainnya
  final int? disbursementId; // terisi jika dibuat dari pencairan BOS

  TransactionModel({
    this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.type,
    required this.date,
    this.description,
    this.icon = 'receipt',
    String? fundSource,
    this.disbursementId,
  }) : fundSource =
           fundSource ??
           (category == kBosCategory ? FundSource.bos : FundSource.lainnya);

  bool get isIncome => type == TxType.income;

  /// Nama kategori untuk ditampilkan ke pengguna.
  String get categoryLabel => category == kBosCategory ? 'Dana BOS' : category;

  /// Transaksi hasil pencairan BOS hanya boleh diubah dari halaman BOS.
  bool get isLinkedToDisbursement => disbursementId != null;

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
      'fund_source': fundSource,
      'disbursement_id': disbursementId,
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
      fundSource: map['fund_source'] as String?,
      disbursementId: map['disbursement_id'] as int?,
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
    String? fundSource,
    int? disbursementId,
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
      fundSource: fundSource ?? this.fundSource,
      disbursementId: disbursementId ?? this.disbursementId,
    );
  }
}
