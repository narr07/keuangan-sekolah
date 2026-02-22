class SettingsModel {
  final int? id;
  final String schoolName;
  final double paguSemester1;
  final double paguSemester2;
  final String tahunAnggaran;

  SettingsModel({
    this.id,
    required this.schoolName,
    required this.paguSemester1,
    required this.paguSemester2,
    required this.tahunAnggaran,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'school_name': schoolName,
      'pagu_semester1': paguSemester1,
      'pagu_semester2': paguSemester2,
      'tahun_anggaran': tahunAnggaran,
    };
  }

  factory SettingsModel.fromMap(Map<String, dynamic> map) {
    return SettingsModel(
      id: map['id'] as int?,
      schoolName: map['school_name'] as String,
      paguSemester1: (map['pagu_semester1'] as num).toDouble(),
      paguSemester2: (map['pagu_semester2'] as num).toDouble(),
      tahunAnggaran: map['tahun_anggaran'] as String,
    );
  }

  SettingsModel copyWith({
    int? id,
    String? schoolName,
    double? paguSemester1,
    double? paguSemester2,
    String? tahunAnggaran,
  }) {
    return SettingsModel(
      id: id ?? this.id,
      schoolName: schoolName ?? this.schoolName,
      paguSemester1: paguSemester1 ?? this.paguSemester1,
      paguSemester2: paguSemester2 ?? this.paguSemester2,
      tahunAnggaran: tahunAnggaran ?? this.tahunAnggaran,
    );
  }

  double get totalPagu => paguSemester1 + paguSemester2;
}
