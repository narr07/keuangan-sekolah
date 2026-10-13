import 'package:budgetku_edu/database/database_helper.dart';
import 'package:budgetku_edu/models/bos_disbursement_model.dart';
import 'package:budgetku_edu/models/transaction_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late DatabaseHelper db;

  setUp(() => db = DatabaseHelper.withName(inMemoryDatabasePath));
  tearDown(() => db.close());

  BosDisbursementModel disbursement({
    double amount = 100000000,
    String phase = 'Tahap 1',
    String status = 'Cair',
    DateTime? date,
  }) => BosDisbursementModel(
    amount: amount,
    date: date ?? DateTime(2026, 2, 10),
    phase: phase,
    status: status,
    semester: 1,
  );

  TransactionModel expense(
    double amount, {
    String source = FundSource.bos,
    DateTime? date,
  }) => TransactionModel(
    title: 'Belanja',
    category: 'Operasional',
    amount: amount,
    type: TxType.expense,
    date: date ?? DateTime(2026, 3, 1),
    fundSource: source,
  );

  group('pencairan BOS', () {
    test('pencairan Cair membuat tepat satu pemasukan yang tertaut', () async {
      final id = await db.insertBosDisbursement(disbursement());
      final txs = await db.getTransactions(year: 2026);
      expect(txs, hasLength(1));
      expect(txs.single.disbursementId, id);
      expect(txs.single.fundSource, FundSource.bos);
    });

    test('pencairan Proses tidak membuat pemasukan sampai jadi Cair', () async {
      final d = disbursement(status: 'Proses');
      final id = await db.insertBosDisbursement(d);
      expect(await db.getTransactions(year: 2026), isEmpty);

      await db.updateBosDisbursement(d.copyWith(id: id, status: 'Cair'));
      expect(await db.getTransactions(year: 2026), hasLength(1));

      await db.updateBosDisbursement(d.copyWith(id: id, status: 'Proses'));
      expect(await db.getTransactions(year: 2026), isEmpty);
    });

    test('edit pencairan memperbarui pemasukan yang tertaut', () async {
      final d = disbursement();
      final id = await db.insertBosDisbursement(d);
      await db.updateBosDisbursement(
        d.copyWith(id: id, amount: 150000000, phase: 'Tahap 1 Revisi'),
      );
      final tx = (await db.getTransactions(year: 2026)).single;
      expect(tx.amount, 150000000);
      expect(tx.title, 'Dana BOS Tahap 1 Revisi');
    });

    test('hapus satu dari dua pencairan identik hanya menghapus miliknya', () async {
      final id1 = await db.insertBosDisbursement(disbursement());
      final id2 = await db.insertBosDisbursement(disbursement());
      await db.deleteBosDisbursement(id1);

      final txs = await db.getTransactions(year: 2026);
      expect(txs, hasLength(1));
      expect(txs.single.disbursementId, id2);
    });

    test('pemasukan tertaut tidak bisa diubah/dihapus langsung', () async {
      await db.insertBosDisbursement(disbursement());
      final tx = (await db.getTransactions(year: 2026)).single;
      expect(() => db.deleteTransaction(tx.id!), throwsStateError);
      expect(
        () => db.updateTransaction(tx.copyWith(amount: 1)),
        throwsStateError,
      );
    });

    test('total cair difilter per tahun dan semester', () async {
      await db.insertBosDisbursement(disbursement(amount: 100));
      await db.insertBosDisbursement(
        disbursement(amount: 50, status: 'Proses'),
      );
      await db.insertBosDisbursement(
        disbursement(amount: 30, date: DateTime(2025, 2, 1)),
      );
      expect(await db.getTotalBosCair(2026), 100);
      expect(await db.getTotalBosCair(2026, semester: 2), 0);
      expect(await db.getTotalBosCair(2025), 30);
    });
  });

  group('ringkasan tahunan', () {
    test('saldo awal, saldo akhir, dan saldo per sumber dana', () async {
      // 2025: masuk BOS 100, keluar BOS 40 -> sisa 60 dibawa ke 2026
      await db.insertBosDisbursement(
        disbursement(amount: 100, date: DateTime(2025, 2, 1)),
      );
      await db.insertTransaction(expense(40, date: DateTime(2025, 5, 1)));

      // 2026
      await db.insertBosDisbursement(disbursement(amount: 200));
      await db.insertTransaction(
        TransactionModel(
          title: 'Sumbangan alumni',
          category: 'Sumbangan',
          amount: 50,
          type: TxType.income,
          date: DateTime(2026, 4, 1),
        ),
      );
      await db.insertTransaction(expense(70));
      await db.insertTransaction(expense(20, source: FundSource.lainnya));

      final s = await db.getYearSummary(2026);
      expect(s.openingBalance, 60);
      expect(s.income, 250);
      expect(s.expense, 90);
      expect(s.closingBalance, 220);
      expect(s.bosBalance, 190); // 60 + 200 - 70
      expect(s.otherBalance, 30); // 50 - 20

      expect(await db.getTransactions(year: 2025), hasLength(2));
      expect(
        await db.getTransactions(year: 2026, type: TxType.expense),
        hasLength(2),
      );
      expect(await db.getAvailableYears(), containsAll([2026, 2025]));
    });
  });

  group('backup', () {
    test('ekspor lalu impor mengembalikan data beserta tautannya', () async {
      await db.insertBosDisbursement(disbursement());
      await db.insertTransaction(expense(10));
      final backup = await db.exportData();

      await db.insertTransaction(expense(999));
      await db.importData(backup);

      final txs = await db.getTransactions(year: 2026);
      expect(txs, hasLength(2));
      final linked = txs.firstWhere((t) => t.isLinkedToDisbursement);
      await db.deleteBosDisbursement(linked.disbursementId!);
      expect(await db.getTransactions(year: 2026), hasLength(1));
    });

    test('file asing ditolak tanpa mengubah data', () async {
      await db.insertTransaction(expense(10));
      expect(
        () => db.importData({'app': 'lain'}),
        throwsA(isA<FormatException>()),
      );
      final backup = await db.exportData();
      (backup['transactions'] as List).add({'title': 'rusak'});
      expect(() => db.importData(backup), throwsA(isA<FormatException>()));
      expect(await db.getTransactions(year: 2026), hasLength(1));
    });
  });
}
