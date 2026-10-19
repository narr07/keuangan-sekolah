import 'dart:io';

import 'package:budgetku_edu/database/database_helper.dart';
import 'package:budgetku_edu/models/transaction_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Membuat database dengan skema versi 2 (sebelum perbaikan) berisi data.
Future<void> _createV2(String path) async {
  final db = await databaseFactoryFfi.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 2,
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE funds (id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'name TEXT NOT NULL, balance REAL NOT NULL DEFAULT 0)',
        );
        await db.execute('''
          CREATE TABLE transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL,
            category TEXT NOT NULL, amount REAL NOT NULL, type TEXT NOT NULL,
            date TEXT NOT NULL, description TEXT, icon TEXT DEFAULT 'receipt')
        ''');
        await db.execute('''
          CREATE TABLE settings (
            id INTEGER PRIMARY KEY AUTOINCREMENT, school_name TEXT NOT NULL,
            pagu_semester1 REAL NOT NULL, pagu_semester2 REAL NOT NULL,
            tahun_anggaran TEXT NOT NULL)
        ''');
        await db.execute('''
          CREATE TABLE bos_disbursements (
            id INTEGER PRIMARY KEY AUTOINCREMENT, amount REAL NOT NULL,
            date TEXT NOT NULL, phase TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'Cair', description TEXT,
            semester INTEGER NOT NULL DEFAULT 1)
        ''');
        await db.insert('settings', {
          'school_name': 'SDN 1',
          'pagu_semester1': 1,
          'pagu_semester2': 1,
          'tahun_anggaran': '2026',
        });
        // Dua pencairan identik + transaksinya masing-masing.
        for (var i = 0; i < 2; i++) {
          await db.insert('bos_disbursements', {
            'amount': 100,
            'date': '2026-02-01T00:00:00.000',
            'phase': 'Tahap 1',
            'semester': 1,
          });
          await db.insert('transactions', {
            'title': 'Dana BOS Tahap 1',
            'category': 'BOS Fund',
            'amount': 100,
            'type': 'income',
            'date': '2026-02-01T00:00:00.000',
          });
        }
        await db.insert('transactions', {
          'title': 'Listrik',
          'category': 'Operasional',
          'amount': 30,
          'type': 'expense',
          'date': '2026-03-01T00:00:00.000',
        });
      },
    ),
  );
  await db.close();
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('migrasi v2 -> terbaru menautkan pencairan satu-satu', () async {
    final dir = await Directory.systemTemp.createTemp('budgetku_test');
    final path = p.join(dir.path, 'v2.db');
    await _createV2(path);

    final helper = DatabaseHelper.withName(path);
    addTearDown(() async {
      await helper.close();
      await dir.delete(recursive: true);
    });

    final txs = await helper.getTransactions(year: 2026);
    final linked = txs.where((t) => t.isLinkedToDisbursement).toList();
    expect(linked.map((t) => t.disbursementId).toSet(), {1, 2});
    expect(linked.every((t) => t.fundSource == FundSource.bos), isTrue);
    expect(
      txs.firstWhere((t) => t.title == 'Listrik').fundSource,
      FundSource.lainnya,
    );

    await helper.deleteBosDisbursement(1);
    expect(await helper.getTransactions(year: 2026), hasLength(2));

    // Pagu lama (satu untuk semua tahun) pindah ke tahun anggaran aktif.
    final pagu = await helper.getPagu(2026);
    expect(pagu.semester1, 1);
    expect(pagu.semester2, 1);
    expect((await helper.getPagu(2025)).total, 0);

    final db = await helper.database;
    final tables = await db.query(
      'sqlite_master',
      where: "type = 'table' AND name = 'funds'",
    );
    expect(tables, isEmpty);
  });
}
