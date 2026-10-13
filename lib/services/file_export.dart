import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Menyimpan file lewat dialog "Simpan sebagai" milik sistem (Storage Access
/// Framework di Android), sehingga tidak butuh izin penyimpanan apa pun.
class FileExport {
  /// Mengembalikan `false` bila pengguna membatalkan dialog.
  static Future<bool> save(
    Uint8List bytes,
    String fileName, {
    bool openAfterSave = false,
  }) async {
    final saved = await FilePicker.platform.saveFile(
      dialogTitle: 'Simpan file',
      fileName: fileName,
      bytes: bytes,
    );
    if (saved == null) return false;

    if (openAfterSave && !kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      // Lokasi pilihan pengguna bisa berupa URI SAF yang tidak bisa dibuka
      // langsung, jadi buka salinan sementara.
      final tmp = File(p.join((await getTemporaryDirectory()).path, fileName));
      await tmp.writeAsBytes(bytes);
      await OpenFilex.open(tmp.path);
    }
    return true;
  }
}
