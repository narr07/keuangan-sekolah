/// Pengaturan umum aplikasi. Pagu BOS disimpan per tahun di
/// [BosPaguModel], bukan di sini.
class SettingsModel {
  final int? id;
  final String schoolName;
  final String tahunAnggaran;

  SettingsModel({
    this.id,
    required this.schoolName,
    required this.tahunAnggaran,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'school_name': schoolName,
      'tahun_anggaran': tahunAnggaran,
    };
  }

  factory SettingsModel.fromMap(Map<String, dynamic> map) {
    return SettingsModel(
      id: map['id'] as int?,
      schoolName: map['school_name'] as String,
      tahunAnggaran: map['tahun_anggaran'] as String,
    );
  }

  SettingsModel copyWith({int? id, String? schoolName, String? tahunAnggaran}) {
    return SettingsModel(
      id: id ?? this.id,
      schoolName: schoolName ?? this.schoolName,
      tahunAnggaran: tahunAnggaran ?? this.tahunAnggaran,
    );
  }

  /// Tahun anggaran sebagai angka; jatuh ke tahun berjalan bila tidak valid.
  int get activeYear => int.tryParse(tahunAnggaran) ?? DateTime.now().year;
}
