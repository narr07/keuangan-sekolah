import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import '../models/transaction_model.dart';

class ExportService {
  static final _currencyFormat = NumberFormat('#,##0', 'id_ID');

  static String _formatCurrency(double amount) {
    return 'Rp ${_currencyFormat.format(amount.toInt())}';
  }

  static Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      if (await Permission.manageExternalStorage.isGranted) return true;
      if (await Permission.storage.isGranted) return true;

      // Request both to be safe depending on Android version
      await Permission.storage.request();
      if (await Permission.manageExternalStorage.request().isGranted)
        return true;
      if (await Permission.storage.request().isGranted) return true;

      return false; // Not granted
    }
    return true; // iOS or Web doesn't need this specific permission handler logic for default apps directory
  }

  // ============== EXCEL EXPORT ==============
  static Future<void> exportToExcel(
    List<TransactionModel> transactions,
    String schoolName,
  ) async {
    final excel = Excel.createExcel();
    final sheet = excel['Laporan Keuangan'];

    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    // Title Row
    sheet.cell(CellIndex.indexByString("A1")).value = TextCellValue(
      'Laporan Keuangan - $schoolName',
    );

    // Header Row
    final headers = [
      'Tanggal',
      'Jenis',
      'Kategori',
      'Keterangan',
      'Pemasukan',
      'Pengeluaran',
    ];
    for (int i = 0; i < headers.length; i++) {
      var cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 2),
      );
      cell.value = TextCellValue(headers[i]);
    }

    int rowIndex = 3;
    final df = DateFormat('dd MMM yyyy');
    double totalIn = 0;
    double totalOut = 0;

    for (final tx in transactions) {
      final isIn = tx.type == 'income';
      if (isIn) {
        totalIn += tx.amount;
      } else {
        totalOut += tx.amount;
      }

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
          .value = TextCellValue(
        df.format(tx.date),
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
          .value = TextCellValue(
        isIn ? 'Masuk' : 'Keluar',
      );
      final mappedCategory = tx.category == 'BOS Fund'
          ? 'Dana BOS'
          : tx.category;
      final fullTitle =
          (tx.description != null && tx.description!.trim().isNotEmpty)
          ? '${tx.title} - ${tx.description}'
          : tx.title;

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex))
          .value = TextCellValue(
        mappedCategory,
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex))
          .value = TextCellValue(
        fullTitle,
      );

      if (isIn) {
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex),
            )
            .value = DoubleCellValue(
          tx.amount,
        );
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex),
            )
            .value = TextCellValue(
          '-',
        );
      } else {
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex),
            )
            .value = TextCellValue(
          '-',
        );
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex),
            )
            .value = DoubleCellValue(
          tx.amount,
        );
      }
      rowIndex++;
    }

    // Total Row
    rowIndex++;
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex))
        .value = TextCellValue(
      'TOTAL',
    );
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex))
        .value = DoubleCellValue(
      totalIn,
    );
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex))
        .value = DoubleCellValue(
      totalOut,
    );

    // Saldo
    rowIndex++;
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex))
        .value = TextCellValue(
      'SALDO AKHIR',
    );
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex))
        .value = DoubleCellValue(
      totalIn - totalOut,
    );

    final fileBytes = excel.save();
    if (fileBytes != null) {
      if (kIsWeb) {
        // Fallback for Web if needed, but since requirement is mobile focus,
        // you might still use your old file_saver logic if you need web support.
      } else {
        bool hasPermission = await _requestStoragePermission();
        if (!hasPermission && Platform.isAndroid) {
          throw Exception(
            "Izin penyimpanan ditolak (Storage permission denied)",
          );
        }

        Directory? dir;
        if (Platform.isAndroid) {
          dir = Directory('/storage/emulated/0/Download');
          if (!await dir.exists()) {
            dir = await getExternalStorageDirectory();
          }
        } else {
          dir = await getApplicationDocumentsDirectory();
        }

        final filePath =
            '${dir!.path}/Laporan_Keuangan_Excel_${DateTime.now().millisecondsSinceEpoch}.xlsx';
        final file = File(filePath);
        await file.writeAsBytes(fileBytes);

        // Buka otomatis
        await OpenFilex.open(filePath);
      }
    }
  }

  // ============== PDF EXPORT ==============
  static Future<void> exportToPdf(
    List<TransactionModel> transactions,
    String schoolName,
  ) async {
    final pdf = pw.Document();

    double totalIn = 0;
    double totalOut = 0;
    for (var tx in transactions) {
      if (tx.type == 'income') {
        totalIn += tx.amount;
      } else {
        totalOut += tx.amount;
      }
    }

    final df = DateFormat('dd MMM yyyy');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Laporan Keuangan',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Sekolah: $schoolName',
                    style: const pw.TextStyle(fontSize: 14),
                  ),
                  pw.SizedBox(height: 16),
                ],
              ),
            ),
            pw.TableHelper.fromTextArray(
              headers: ['Tanggal', 'Transaksi', 'Kategori', 'Masuk', 'Keluar'],
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF2E6FF3),
              ),
              cellAlignment: pw.Alignment.centerLeft,
              data: [
                ...transactions.map((t) {
                  final mappedCat = t.category == 'BOS Fund'
                      ? 'Dana BOS'
                      : t.category;
                  final fullTitle =
                      (t.description != null &&
                          t.description!.trim().isNotEmpty)
                      ? '${t.title}\nCatatan: ${t.description}'
                      : t.title;

                  return [
                    df.format(t.date),
                    fullTitle,
                    mappedCat,
                    t.type == 'income' ? _formatCurrency(t.amount) : '-',
                    t.type == 'expense' ? _formatCurrency(t.amount) : '-',
                  ];
                }),
              ],
            ),
            pw.Divider(color: PdfColors.grey400),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Total Pemasukan: ${_formatCurrency(totalIn)}',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green700,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Total Pengeluaran: ${_formatCurrency(totalOut)}',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.red700,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Saldo Akhir: ${_formatCurrency(totalIn - totalOut)}',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    final bytes = await pdf.save();

    if (kIsWeb) {
      // Fallback for web if needed
    } else {
      bool hasPermission = await _requestStoragePermission();
      if (!hasPermission && Platform.isAndroid) {
        throw Exception("Izin penyimpanan ditolak (Storage permission denied)");
      }

      Directory? dir;
      if (Platform.isAndroid) {
        dir = Directory('/storage/emulated/0/Download');
        if (!await dir.exists()) {
          dir = await getExternalStorageDirectory();
        }
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      final filePath =
          '${dir!.path}/Laporan_Keuangan_PDF_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      // Buka otomatis
      await OpenFilex.open(filePath);
    }
  }
}
