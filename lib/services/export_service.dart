import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/transaction_model.dart';
import '../models/year_summary.dart';
import 'file_export.dart';

class ExportService {
  static final _currencyFormat = NumberFormat('#,##0', 'id_ID');
  static final _dateFormat = DateFormat('dd MMM yyyy');

  static String _formatCurrency(double amount) {
    return 'Rp ${_currencyFormat.format(amount.toInt())}';
  }

  static String _categoryLabel(TransactionModel tx) =>
      tx.category == kBosCategory ? 'Dana BOS' : tx.category;

  static String _fileName(String kind, int year, String ext) {
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    return 'Laporan_Keuangan_${year}_${kind}_$stamp.$ext';
  }

  /// Urut dari tanggal terlama agar mudah dibaca sebagai buku kas.
  static List<TransactionModel> _chronological(List<TransactionModel> txs) =>
      [...txs]..sort((a, b) => a.date.compareTo(b.date));

  // ============== EXCEL EXPORT ==============
  /// Mengembalikan `false` bila pengguna membatalkan dialog simpan.
  static Future<bool> exportToExcel(
    List<TransactionModel> transactions,
    String schoolName,
    YearSummary summary,
  ) async {
    final excel = Excel.createExcel();
    final sheet = excel['Laporan Keuangan'];
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    var row = 0;
    void put(int col, CellValue value) {
      sheet
              .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
              .value =
          value;
    }

    put(0, TextCellValue('Laporan Keuangan - $schoolName'));
    row++;
    put(0, TextCellValue('Tahun Anggaran ${summary.year}'));
    row += 2;

    const headers = [
      'Tanggal',
      'Jenis',
      'Kategori',
      'Sumber Dana',
      'Keterangan',
      'Pemasukan',
      'Pengeluaran',
    ];
    for (var i = 0; i < headers.length; i++) {
      put(i, TextCellValue(headers[i]));
    }
    row++;

    put(4, TextCellValue('Saldo awal (sisa tahun lalu)'));
    put(5, DoubleCellValue(summary.openingBalance));
    row++;

    for (final tx in _chronological(transactions)) {
      final fullTitle =
          (tx.description != null && tx.description!.trim().isNotEmpty)
          ? '${tx.title} - ${tx.description}'
          : tx.title;
      put(0, TextCellValue(_dateFormat.format(tx.date)));
      put(1, TextCellValue(tx.isIncome ? 'Masuk' : 'Keluar'));
      put(2, TextCellValue(_categoryLabel(tx)));
      put(3, TextCellValue(FundSource.label(tx.fundSource)));
      put(4, TextCellValue(fullTitle));
      put(5, tx.isIncome ? DoubleCellValue(tx.amount) : TextCellValue('-'));
      put(6, tx.isIncome ? TextCellValue('-') : DoubleCellValue(tx.amount));
      row++;
    }

    row++;
    put(4, TextCellValue('TOTAL TAHUN ${summary.year}'));
    put(5, DoubleCellValue(summary.income));
    put(6, DoubleCellValue(summary.expense));
    row++;
    for (final (label, value) in [
      ('SALDO AKHIR', summary.closingBalance),
      ('  - Dana BOS', summary.bosBalance),
      ('  - Dana Lainnya', summary.otherBalance),
    ]) {
      put(4, TextCellValue(label));
      put(5, DoubleCellValue(value));
      row++;
    }

    final fileBytes = excel.save();
    if (fileBytes == null) return false;
    return FileExport.save(
      Uint8List.fromList(fileBytes),
      _fileName('Excel', summary.year, 'xlsx'),
      openAfterSave: true,
    );
  }

  // ============== PDF EXPORT ==============
  /// Mengembalikan `false` bila pengguna membatalkan dialog simpan.
  static Future<bool> exportToPdf(
    List<TransactionModel> transactions,
    String schoolName,
    YearSummary summary,
  ) async {
    final pdf = pw.Document();

    pw.Widget totalLine(String label, double value, {PdfColor? color}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Text(
            '$label: ${_formatCurrency(value)}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: color),
          ),
        );

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
                  pw.Text(
                    'Tahun Anggaran: ${summary.year}',
                    style: const pw.TextStyle(fontSize: 14),
                  ),
                  pw.SizedBox(height: 16),
                ],
              ),
            ),
            pw.TableHelper.fromTextArray(
              headers: [
                'Tanggal',
                'Transaksi',
                'Kategori',
                'Sumber',
                'Masuk',
                'Keluar',
              ],
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF2E6FF3),
              ),
              cellAlignment: pw.Alignment.centerLeft,
              data: [
                [
                  '',
                  'Saldo awal (sisa tahun lalu)',
                  '',
                  '',
                  _formatCurrency(summary.openingBalance),
                  '-',
                ],
                ..._chronological(transactions).map((t) {
                  final fullTitle =
                      (t.description != null &&
                          t.description!.trim().isNotEmpty)
                      ? '${t.title}\nCatatan: ${t.description}'
                      : t.title;
                  return [
                    _dateFormat.format(t.date),
                    fullTitle,
                    _categoryLabel(t),
                    t.fundSource == FundSource.bos ? 'BOS' : 'Lainnya',
                    t.isIncome ? _formatCurrency(t.amount) : '-',
                    t.isIncome ? '-' : _formatCurrency(t.amount),
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
                    totalLine('Saldo Awal', summary.openingBalance),
                    totalLine(
                      'Total Pemasukan',
                      summary.income,
                      color: PdfColors.green700,
                    ),
                    totalLine(
                      'Total Pengeluaran',
                      summary.expense,
                      color: PdfColors.red700,
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Saldo Akhir: ${_formatCurrency(summary.closingBalance)}',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Dana BOS ${_formatCurrency(summary.bosBalance)} | '
                      'Dana Lainnya ${_formatCurrency(summary.otherBalance)}',
                    ),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    return FileExport.save(
      await pdf.save(),
      _fileName('PDF', summary.year, 'pdf'),
      openAfterSave: true,
    );
  }
}
