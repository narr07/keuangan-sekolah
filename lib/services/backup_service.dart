import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import '../database/database_helper.dart';
import 'file_export.dart';

/// Backup & restore seluruh data aplikasi sebagai file JSON.
class BackupService {
  /// Mengembalikan `false` bila pengguna membatalkan dialog simpan.
  static Future<bool> exportBackup() async {
    final data = await DatabaseHelper.instance.exportData();
    final bytes = utf8.encode(const JsonEncoder.withIndent(' ').convert(data));
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    return FileExport.save(bytes, 'backup_budgetku_$stamp.json');
  }

  /// Membaca file backup yang dipilih pengguna dan mengganti seluruh data.
  ///
  /// Mengembalikan `false` bila pengguna membatalkan pemilihan file; melempar
  /// [FormatException] bila file tidak valid.
  static Future<bool> importBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    final bytes = result?.files.single.bytes;
    if (bytes == null) return false;

    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      throw const FormatException('File bukan JSON yang valid.');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Bukan file backup BudgetKu Edu.');
    }
    await DatabaseHelper.instance.importData(decoded);
    return true;
  }
}
