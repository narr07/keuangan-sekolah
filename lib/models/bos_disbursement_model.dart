class BosDisbursementModel {
  final int? id;
  final double amount;
  final DateTime date;
  final String phase; // e.g. "Tahap 1", "Tahap 2"
  final String status; // 'Cair' or 'Proses'
  final String? description;
  final int semester; // 1 or 2

  BosDisbursementModel({
    this.id,
    required this.amount,
    required this.date,
    required this.phase,
    this.status = 'Cair',
    this.description,
    required this.semester,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'date': date.toIso8601String(),
      'phase': phase,
      'status': status,
      'description': description,
      'semester': semester,
    };
  }

  factory BosDisbursementModel.fromMap(Map<String, dynamic> map) {
    return BosDisbursementModel(
      id: map['id'] as int?,
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
      phase: map['phase'] as String,
      status: map['status'] as String? ?? 'Cair',
      description: map['description'] as String?,
      semester: map['semester'] as int? ?? 1,
    );
  }

  BosDisbursementModel copyWith({
    int? id,
    double? amount,
    DateTime? date,
    String? phase,
    String? status,
    String? description,
    int? semester,
  }) {
    return BosDisbursementModel(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      phase: phase ?? this.phase,
      status: status ?? this.status,
      description: description ?? this.description,
      semester: semester ?? this.semester,
    );
  }
}
