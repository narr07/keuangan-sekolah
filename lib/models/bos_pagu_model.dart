/// Pagu (batas alokasi) dana BOS untuk satu tahun anggaran.
class BosPaguModel {
  final int year;
  final double semester1;
  final double semester2;

  const BosPaguModel({
    required this.year,
    this.semester1 = 0,
    this.semester2 = 0,
  });

  double get total => semester1 + semester2;

  double forSemester(int semester) => semester == 1 ? semester1 : semester2;

  Map<String, dynamic> toMap() {
    return {'year': year, 'semester1': semester1, 'semester2': semester2};
  }

  factory BosPaguModel.fromMap(Map<String, dynamic> map) {
    return BosPaguModel(
      year: map['year'] as int,
      semester1: (map['semester1'] as num).toDouble(),
      semester2: (map['semester2'] as num).toDouble(),
    );
  }
}
