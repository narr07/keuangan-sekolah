import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/transaction_model.dart';
import '../models/fund_model.dart';
import '../models/settings_model.dart';
import '../models/bos_disbursement_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('keuangan_sekolah.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE funds (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        balance REAL NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        date TEXT NOT NULL,
        description TEXT,
        icon TEXT DEFAULT 'receipt'
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        school_name TEXT NOT NULL DEFAULT 'Nama Sekolah',
        pagu_semester1 REAL NOT NULL DEFAULT 0,
        pagu_semester2 REAL NOT NULL DEFAULT 0,
        tahun_anggaran TEXT NOT NULL DEFAULT '2024'
      )
    ''');

    await db.execute('''
      CREATE TABLE bos_disbursements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        phase TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'Cair',
        description TEXT,
        semester INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // Insert default funds
    await db.insert('funds', {'name': 'BOS Fund', 'balance': 0});
    await db.insert('funds', {'name': 'Other Fund', 'balance': 0});

    // Insert default settings
    await db.insert('settings', {
      'school_name': 'Nama Sekolah',
      'pagu_semester1': 225000000,
      'pagu_semester2': 225000000,
      'tahun_anggaran': '2024',
    });
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS settings (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          school_name TEXT NOT NULL DEFAULT 'Nama Sekolah',
          pagu_semester1 REAL NOT NULL DEFAULT 0,
          pagu_semester2 REAL NOT NULL DEFAULT 0,
          tahun_anggaran TEXT NOT NULL DEFAULT '2024'
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS bos_disbursements (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          amount REAL NOT NULL,
          date TEXT NOT NULL,
          phase TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'Cair',
          description TEXT,
          semester INTEGER NOT NULL DEFAULT 1
        )
      ''');

      // Insert default settings if not exists
      final existing = await db.query('settings');
      if (existing.isEmpty) {
        await db.insert('settings', {
          'school_name': 'Nama Sekolah',
          'pagu_semester1': 225000000,
          'pagu_semester2': 225000000,
          'tahun_anggaran': '2024',
        });
      }
    }
  }

  // ==================== SETTINGS OPERATIONS ====================

  Future<SettingsModel> getSettings() async {
    final db = await database;
    final result = await db.query('settings', limit: 1);
    if (result.isEmpty) {
      // Insert default settings
      await db.insert('settings', {
        'school_name': 'Nama Sekolah',
        'pagu_semester1': 225000000,
        'pagu_semester2': 225000000,
        'tahun_anggaran': '2024',
      });
      final newResult = await db.query('settings', limit: 1);
      return SettingsModel.fromMap(newResult.first);
    }
    return SettingsModel.fromMap(result.first);
  }

  Future<void> updateSettings(SettingsModel settings) async {
    final db = await database;
    final existing = await db.query('settings');
    if (existing.isEmpty) {
      await db.insert('settings', settings.toMap()..remove('id'));
    } else {
      await db.update(
        'settings',
        settings.toMap()..remove('id'),
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    }
  }

  // ==================== BOS DISBURSEMENT OPERATIONS ====================

  Future<int> insertBosDisbursement(BosDisbursementModel disbursement) async {
    final db = await database;
    final id = await db.insert(
      'bos_disbursements',
      disbursement.toMap()..remove('id'),
    );

    // If status is 'Cair', auto-create income transaction & update BOS fund
    if (disbursement.status == 'Cair') {
      await _processCairDisbursement(disbursement);
    }

    return id;
  }

  Future<void> _processCairDisbursement(
    BosDisbursementModel disbursement,
  ) async {
    // Auto-insert income transaction
    final transaction = TransactionModel(
      title: 'Dana BOS ${disbursement.phase}',
      category: 'BOS Fund',
      amount: disbursement.amount,
      type: 'income',
      date: disbursement.date,
      description:
          disbursement.description ??
          'Pencairan Dana BOS ${disbursement.phase}',
      icon: 'account_balance',
    );
    await insertTransaction(transaction);
  }

  Future<void> updateDisbursementStatus(int id, String newStatus) async {
    final db = await database;

    // Get the disbursement first
    final result = await db.query(
      'bos_disbursements',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isEmpty) return;

    final disbursement = BosDisbursementModel.fromMap(result.first);
    final oldStatus = disbursement.status;

    // Update status
    await db.update(
      'bos_disbursements',
      {'status': newStatus},
      where: 'id = ?',
      whereArgs: [id],
    );

    // If changing from 'Proses' to 'Cair', process the disbursement
    if (oldStatus == 'Proses' && newStatus == 'Cair') {
      await _processCairDisbursement(disbursement);
    }
  }

  Future<List<BosDisbursementModel>> getAllBosDisbursements() async {
    final db = await database;
    final result = await db.query('bos_disbursements', orderBy: 'date DESC');
    return result.map((map) => BosDisbursementModel.fromMap(map)).toList();
  }

  Future<List<BosDisbursementModel>> getBosDisbursementsBySemester(
    int semester,
  ) async {
    final db = await database;
    final result = await db.query(
      'bos_disbursements',
      where: 'semester = ?',
      whereArgs: [semester],
      orderBy: 'date DESC',
    );
    return result.map((map) => BosDisbursementModel.fromMap(map)).toList();
  }

  Future<double> getTotalBosCairBySemester(int semester) async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT SUM(amount) as total FROM bos_disbursements WHERE semester = ? AND status = 'Cair'",
      [semester],
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  Future<double> getTotalBosCair() async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT SUM(amount) as total FROM bos_disbursements WHERE status = 'Cair'",
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  Future<int> deleteBosDisbursement(int id) async {
    final db = await database;

    // Get the disbursement first to find matching transaction
    final result = await db.query(
      'bos_disbursements',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (result.isNotEmpty) {
      final disbursement = BosDisbursementModel.fromMap(result.first);
      if (disbursement.status == 'Cair') {
        // Find matching transaction
        final txResult = await db.query(
          'transactions',
          where: 'title = ? AND amount = ?',
          whereArgs: ['Dana BOS ${disbursement.phase}', disbursement.amount],
        );
        for (var txMap in txResult) {
          final txId = txMap['id'] as int;
          // Delete transaction and revert balance
          await deleteTransaction(txId);
        }
      }
    }

    return await db.delete(
      'bos_disbursements',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== FUND OPERATIONS ====================

  Future<List<FundModel>> getAllFunds() async {
    final db = await database;
    final result = await db.query('funds');
    return result.map((map) => FundModel.fromMap(map)).toList();
  }

  Future<double> getTotalBalance() async {
    final db = await database;
    final result = await db.rawQuery('SELECT SUM(balance) as total FROM funds');
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  Future<void> updateFundBalance(String fundName, double newBalance) async {
    final db = await database;
    await db.update(
      'funds',
      {'balance': newBalance},
      where: 'name = ?',
      whereArgs: [fundName],
    );
  }

  // ==================== TRANSACTION OPERATIONS ====================

  Future<int> insertTransaction(TransactionModel transaction) async {
    final db = await database;
    final id = await db.insert(
      'transactions',
      transaction.toMap()..remove('id'),
    );

    // Update relevant fund balance
    final funds = await getAllFunds();
    final fundName = transaction.category == 'BOS Fund'
        ? 'BOS Fund'
        : 'Other Fund';
    for (final fund in funds) {
      if (fund.name == fundName) {
        final newBalance = transaction.type == 'income'
            ? fund.balance + transaction.amount
            : fund.balance - transaction.amount;
        await updateFundBalance(fund.name, newBalance);
        break;
      }
    }

    return id;
  }

  Future<List<TransactionModel>> getAllTransactions() async {
    final db = await database;
    final result = await db.query('transactions', orderBy: 'date DESC');
    return result.map((map) => TransactionModel.fromMap(map)).toList();
  }

  Future<List<TransactionModel>> getRecentTransactions({int limit = 5}) async {
    final db = await database;
    final result = await db.query(
      'transactions',
      orderBy: 'date DESC',
      limit: limit,
    );
    return result.map((map) => TransactionModel.fromMap(map)).toList();
  }

  Future<int> deleteTransaction(int id) async {
    final db = await database;

    // Get transaction details before deleting so we can revert fund balance
    final result = await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isNotEmpty) {
      final tx = TransactionModel.fromMap(result.first);

      final funds = await getAllFunds();
      final fundName = tx.category == 'BOS Fund' ? 'BOS Fund' : 'Other Fund';
      for (final fund in funds) {
        if (fund.name == fundName) {
          final newBalance = tx.type == 'income'
              ? fund.balance - tx.amount
              : fund.balance + tx.amount;
          await updateFundBalance(fund.name, newBalance);
          break;
        }
      }
    }

    return await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateTransaction(TransactionModel transaction) async {
    final db = await database;

    // Get old transaction details to adjust balances realistically
    final oldResult = await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
    if (oldResult.isNotEmpty) {
      final oldTx = TransactionModel.fromMap(oldResult.first);

      // Step 1: Revert old tx from funds
      var funds = await getAllFunds();
      final oldFundName = oldTx.category == 'BOS Fund'
          ? 'BOS Fund'
          : 'Other Fund';
      for (final fund in funds) {
        if (fund.name == oldFundName) {
          final revertedBalance = oldTx.type == 'income'
              ? fund.balance - oldTx.amount
              : fund.balance + oldTx.amount;
          await updateFundBalance(fund.name, revertedBalance);
          break;
        }
      }

      // Step 2: Apply new tx to funds
      funds = await getAllFunds(); // Reload funds!
      final newFundName = transaction.category == 'BOS Fund'
          ? 'BOS Fund'
          : 'Other Fund';
      for (final fund in funds) {
        if (fund.name == newFundName) {
          final newBalance = transaction.type == 'income'
              ? fund.balance + transaction.amount
              : fund.balance - transaction.amount;
          await updateFundBalance(fund.name, newBalance);
          break;
        }
      }
    }

    return await db.update(
      'transactions',
      transaction.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<int> updateBosDisbursement(BosDisbursementModel disbursement) async {
    final db = await database;

    final oldResult = await db.query(
      'bos_disbursements',
      where: 'id = ?',
      whereArgs: [disbursement.id],
    );
    if (oldResult.isNotEmpty) {
      final oldDb = BosDisbursementModel.fromMap(oldResult.first);
      final oldTitle = 'Dana BOS ${oldDb.phase}';

      if (oldDb.status == 'Cair' && disbursement.status != 'Cair') {
        // We canceled the cair, so delete the transaction
        final txResult = await db.query(
          'transactions',
          where: 'title = ? AND amount = ?',
          whereArgs: [oldTitle, oldDb.amount],
        );
        for (var txMap in txResult) {
          await deleteTransaction(txMap['id'] as int);
        }
      } else if (oldDb.status != 'Cair' && disbursement.status == 'Cair') {
        // Newly cair
        await _processCairDisbursement(disbursement);
      } else if (oldDb.status == 'Cair' && disbursement.status == 'Cair') {
        // Just updating the details, need to sync the existing transaction
        final txResult = await db.query(
          'transactions',
          where: 'title = ? AND amount = ?',
          whereArgs: [oldTitle, oldDb.amount],
        );
        for (var txMap in txResult) {
          final oldTx = TransactionModel.fromMap(txMap);
          final newTx = oldTx.copyWith(
            title: 'Dana BOS ${disbursement.phase}',
            amount: disbursement.amount,
            date: disbursement.date,
            description:
                disbursement.description ??
                'Pencairan Dana BOS ${disbursement.phase}',
          );
          await updateTransaction(newTx);
        }
      }
    }

    return await db.update(
      'bos_disbursements',
      disbursement.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [disbursement.id],
    );
  }

  Future<double> getTotalIncome() async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT SUM(amount) as total FROM transactions WHERE type = 'income'",
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  Future<double> getTotalExpense() async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT SUM(amount) as total FROM transactions WHERE type = 'expense'",
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  Future<void> close() async {
    final db = await database;
    db.close();
    _database = null;
  }
}
