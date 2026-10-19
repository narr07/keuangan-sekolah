import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/transaction_model.dart';
import '../models/settings_model.dart';
import '../models/bos_disbursement_model.dart';
import '../models/bos_pagu_model.dart';
import '../models/year_summary.dart';

class DatabaseHelper {
  static const _dbName = 'keuangan_sekolah.db';
  static const schemaVersion = 4;

  /// Penanda format file backup (lihat [exportData] / [importData]).
  static const backupAppId = 'budgetku_edu';

  static final DatabaseHelper instance = DatabaseHelper._(_dbName);

  DatabaseHelper._(this._name);

  /// Untuk test: gunakan [inMemoryDatabasePath] atau path file sementara.
  @visibleForTesting
  DatabaseHelper.withName(this._name);

  final String _name;
  Future<Database>? _database;

  Future<Database> get database => _database ??= _initDB();

  Future<Database> _initDB() async {
    final path = _name == inMemoryDatabasePath
        ? _name
        : join(await getDatabasesPath(), _name);

    return await openDatabase(
      path,
      version: schemaVersion,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  static Map<String, Object?> _defaultSettings() => {
    'school_name': 'Nama Sekolah',
    'tahun_anggaran': DateTime.now().year.toString(),
  };

  // Kolom pagu_semester1/2 tidak dipakai lagi sejak skema 4 (pindah ke
  // tabel bos_pagu per tahun), tapi dibiarkan agar migrasi lama tetap jalan.
  static const _createSettingsSql = '''
    CREATE TABLE IF NOT EXISTS settings (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      school_name TEXT NOT NULL DEFAULT 'Nama Sekolah',
      pagu_semester1 REAL NOT NULL DEFAULT 0,
      pagu_semester2 REAL NOT NULL DEFAULT 0,
      tahun_anggaran TEXT NOT NULL DEFAULT '2024'
    )
  ''';

  static const _createDisbursementsSql = '''
    CREATE TABLE IF NOT EXISTS bos_disbursements (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      amount REAL NOT NULL,
      date TEXT NOT NULL,
      phase TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'Cair',
      description TEXT,
      semester INTEGER NOT NULL DEFAULT 1
    )
  ''';

  static const _createBosPaguSql = '''
    CREATE TABLE IF NOT EXISTS bos_pagu (
      year INTEGER PRIMARY KEY,
      semester1 REAL NOT NULL DEFAULT 0,
      semester2 REAL NOT NULL DEFAULT 0
    )
  ''';

  static const _createIndexesSql = [
    'CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(date)',
    'CREATE INDEX IF NOT EXISTS idx_transactions_disbursement '
        'ON transactions(disbursement_id)',
  ];

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        date TEXT NOT NULL,
        description TEXT,
        icon TEXT DEFAULT 'receipt',
        fund_source TEXT NOT NULL DEFAULT 'Lainnya',
        disbursement_id INTEGER
      )
    ''');
    await db.execute(_createSettingsSql);
    await db.execute(_createDisbursementsSql);
    await db.execute(_createBosPaguSql);
    for (final sql in _createIndexesSql) {
      await db.execute(sql);
    }

    await db.insert('settings', _defaultSettings());
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(_createSettingsSql);
      await db.execute(_createDisbursementsSql);

      final existing = await db.query('settings');
      if (existing.isEmpty) {
        await db.insert('settings', _defaultSettings());
      }
    }

    if (oldVersion < 3) {
      await db.execute(
        "ALTER TABLE transactions ADD COLUMN fund_source TEXT NOT NULL DEFAULT 'Lainnya'",
      );
      await db.execute(
        'ALTER TABLE transactions ADD COLUMN disbursement_id INTEGER',
      );
      await db.update('transactions', {
        'fund_source': FundSource.bos,
      }, where: "category = '$kBosCategory'");

      // Sebelumnya pencairan dan transaksinya hanya dicocokkan lewat
      // judul + nominal. Tautkan satu-satu agar tidak ada yang terhapus ganda.
      final cair = await db.query(
        'bos_disbursements',
        where: "status = 'Cair'",
        orderBy: 'id',
      );
      for (final d in cair) {
        final match = await db.query(
          'transactions',
          columns: ['id'],
          where:
              'disbursement_id IS NULL AND category = ? AND title = ? AND amount = ?',
          whereArgs: [kBosCategory, 'Dana BOS ${d['phase']}', d['amount']],
          orderBy: 'id',
          limit: 1,
        );
        if (match.isNotEmpty) {
          await db.update(
            'transactions',
            {'disbursement_id': d['id']},
            where: 'id = ?',
            whereArgs: [match.first['id']],
          );
        }
      }

      // Saldo kini dihitung langsung dari transaksi.
      await db.execute('DROP TABLE IF EXISTS funds');
      for (final sql in _createIndexesSql) {
        await db.execute(sql);
      }
    }

    if (oldVersion < 4) {
      // Pagu dulu hanya satu untuk semua tahun; pindahkan ke tahun aktif.
      await db.execute(_createBosPaguSql);
      final rows = await db.query('settings', limit: 1);
      if (rows.isNotEmpty) {
        await _insertLegacyPagu(db, rows.first);
      }
    }
  }

  /// Menyimpan pagu dari baris `settings` versi lama sebagai pagu tahun
  /// anggarannya. Tidak melakukan apa-apa bila pagunya kosong.
  static Future<void> _insertLegacyPagu(
    DatabaseExecutor db,
    Map<String, Object?> settings,
  ) async {
    final s1 = (settings['pagu_semester1'] as num?)?.toDouble() ?? 0;
    final s2 = (settings['pagu_semester2'] as num?)?.toDouble() ?? 0;
    final year = int.tryParse('${settings['tahun_anggaran']}');
    if (year == null || (s1 == 0 && s2 == 0)) return;
    await db.insert(
      'bos_pagu',
      BosPaguModel(year: year, semester1: s1, semester2: s2).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Batas tanggal (ISO-8601) untuk satu tahun: [awal, akhir).
  static List<String> _yearRange(int year) => [
    DateTime(year).toIso8601String(),
    DateTime(year + 1).toIso8601String(),
  ];

  // ==================== SETTINGS ====================

  Future<SettingsModel> getSettings() async {
    final db = await database;
    final result = await db.query('settings', limit: 1);
    if (result.isEmpty) {
      await db.insert('settings', _defaultSettings());
      return getSettings();
    }
    return SettingsModel.fromMap(result.first);
  }

  Future<void> updateSettings(SettingsModel settings) async {
    final db = await database;
    final existing = await db.query('settings', columns: ['id'], limit: 1);
    final values = settings.toMap()..remove('id');
    if (existing.isEmpty) {
      await db.insert('settings', values);
    } else {
      await db.update(
        'settings',
        values,
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    }
  }

  /// Mengganti tahun anggaran aktif yang dipakai semua halaman.
  Future<void> setActiveYear(int year) async {
    final settings = await getSettings();
    await updateSettings(settings.copyWith(tahunAnggaran: year.toString()));
  }

  /// Tahun yang punya data, ditambah tahun aktif dan tahun berjalan.
  Future<List<int>> getAvailableYears() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT DISTINCT CAST(substr(date, 1, 4) AS INTEGER) AS year FROM transactions
      UNION
      SELECT DISTINCT CAST(substr(date, 1, 4) AS INTEGER) AS year FROM bos_disbursements
    ''');
    final years = {
      for (final r in rows)
        if (r['year'] != null) r['year'] as int,
      (await getSettings()).activeYear,
      DateTime.now().year,
    };
    return years.toList()..sort((a, b) => b.compareTo(a));
  }

  // ==================== BOS PAGU ====================

  /// Pagu BOS untuk [year]; bernilai 0 bila belum diisi.
  Future<BosPaguModel> getPagu(int year) async {
    final db = await database;
    final rows = await db.query(
      'bos_pagu',
      where: 'year = ?',
      whereArgs: [year],
    );
    return rows.isEmpty
        ? BosPaguModel(year: year)
        : BosPaguModel.fromMap(rows.first);
  }

  Future<void> setPagu(BosPaguModel pagu) async {
    final db = await database;
    await db.insert(
      'bos_pagu',
      pagu.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ==================== BOS DISBURSEMENTS ====================

  /// Pencairan berstatus 'Cair' selalu punya tepat satu transaksi pemasukan
  /// yang tertaut lewat `disbursement_id`; status lain tidak punya.
  Future<void> _syncDisbursementTransaction(
    DatabaseExecutor txn,
    BosDisbursementModel d,
  ) async {
    if (d.status != 'Cair') {
      await txn.delete(
        'transactions',
        where: 'disbursement_id = ?',
        whereArgs: [d.id],
      );
      return;
    }

    final values = TransactionModel(
      title: 'Dana BOS ${d.phase}',
      category: kBosCategory,
      amount: d.amount,
      type: TxType.income,
      date: d.date,
      description: d.description ?? 'Pencairan Dana BOS ${d.phase}',
      icon: 'account_balance',
      fundSource: FundSource.bos,
      disbursementId: d.id,
    ).toMap()..remove('id');

    final updated = await txn.update(
      'transactions',
      values,
      where: 'disbursement_id = ?',
      whereArgs: [d.id],
    );
    if (updated == 0) {
      await txn.insert('transactions', values);
    }
  }

  Future<int> insertBosDisbursement(BosDisbursementModel disbursement) async {
    final db = await database;
    return db.transaction((txn) async {
      final id = await txn.insert(
        'bos_disbursements',
        disbursement.toMap()..remove('id'),
      );
      await _syncDisbursementTransaction(txn, disbursement.copyWith(id: id));
      return id;
    });
  }

  Future<int> updateBosDisbursement(BosDisbursementModel disbursement) async {
    final db = await database;
    return db.transaction((txn) async {
      final count = await txn.update(
        'bos_disbursements',
        disbursement.toMap()..remove('id'),
        where: 'id = ?',
        whereArgs: [disbursement.id],
      );
      if (count > 0) {
        await _syncDisbursementTransaction(txn, disbursement);
      }
      return count;
    });
  }

  Future<int> deleteBosDisbursement(int id) async {
    final db = await database;
    return db.transaction((txn) async {
      await txn.delete(
        'transactions',
        where: 'disbursement_id = ?',
        whereArgs: [id],
      );
      return txn.delete('bos_disbursements', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<List<BosDisbursementModel>> getBosDisbursementsByYear(int year) async {
    final db = await database;
    final result = await db.query(
      'bos_disbursements',
      where: 'date >= ? AND date < ?',
      whereArgs: _yearRange(year),
      orderBy: 'date DESC',
    );
    return result.map(BosDisbursementModel.fromMap).toList();
  }

  /// Total dana BOS yang sudah cair pada [year], opsional per [semester].
  Future<double> getTotalBosCair(int year, {int? semester}) async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT SUM(amount) AS total FROM bos_disbursements "
      "WHERE status = 'Cair' AND date >= ? AND date < ?"
      "${semester != null ? ' AND semester = ?' : ''}",
      [..._yearRange(year), ?semester],
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  // ==================== TRANSACTIONS ====================

  Future<int> insertTransaction(TransactionModel transaction) async {
    final db = await database;
    return db.insert('transactions', transaction.toMap()..remove('id'));
  }

  Future<TransactionModel?> _getTransaction(DatabaseExecutor db, int id) async {
    final rows = await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : TransactionModel.fromMap(rows.first);
  }

  /// Transaksi hasil pencairan BOS hanya boleh diubah lewat pencairannya.
  Future<void> _ensureNotLinked(DatabaseExecutor db, int? id) async {
    if (id == null) return;
    final existing = await _getTransaction(db, id);
    if (existing != null && existing.isLinkedToDisbursement) {
      throw StateError(
        'Transaksi ini berasal dari pencairan BOS. Ubah atau hapus dari halaman BOS.',
      );
    }
  }

  Future<int> updateTransaction(TransactionModel transaction) async {
    final db = await database;
    return db.transaction((txn) async {
      await _ensureNotLinked(txn, transaction.id);
      return txn.update(
        'transactions',
        transaction.toMap()
          ..remove('id')
          ..remove('disbursement_id'),
        where: 'id = ?',
        whereArgs: [transaction.id],
      );
    });
  }

  Future<int> deleteTransaction(int id) async {
    final db = await database;
    return db.transaction((txn) async {
      await _ensureNotLinked(txn, id);
      return txn.delete('transactions', where: 'id = ?', whereArgs: [id]);
    });
  }

  /// Transaksi pada [year], opsional difilter per [type].
  Future<List<TransactionModel>> getTransactions({
    required int year,
    String? type,
    int? limit,
  }) async {
    final db = await database;
    final result = await db.query(
      'transactions',
      where: 'date >= ? AND date < ?${type != null ? ' AND type = ?' : ''}',
      whereArgs: [..._yearRange(year), ?type],
      orderBy: 'date DESC, id DESC',
      limit: limit,
    );
    return result.map(TransactionModel.fromMap).toList();
  }

  /// Saldo seluruh transaksi bersumber [fundSource] sampai saat ini.
  /// [excludeId] dipakai saat mengedit agar nilai lamanya tidak ikut dihitung.
  Future<double> getFundBalance(String fundSource, {int? excludeId}) async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT SUM(CASE type WHEN 'income' THEN amount ELSE -amount END) "
      'AS balance FROM transactions WHERE fund_source = ?'
      "${excludeId != null ? ' AND id != ?' : ''}",
      [fundSource, ?excludeId],
    );
    return (result.first['balance'] as num?)?.toDouble() ?? 0;
  }

  Future<YearSummary> getYearSummary(int year) async {
    final db = await database;
    final range = _yearRange(year);
    final row = (await db.rawQuery(
      '''
      SELECT
        SUM(CASE WHEN date < ? THEN signed END) AS opening,
        SUM(CASE WHEN date >= ? AND date < ? AND type = 'income' THEN amount END) AS income,
        SUM(CASE WHEN date >= ? AND date < ? AND type = 'expense' THEN amount END) AS expense,
        SUM(CASE WHEN date < ? AND fund_source = ? THEN signed END) AS bos_closing
      FROM (
        SELECT *, CASE type WHEN 'income' THEN amount ELSE -amount END AS signed
        FROM transactions
      )
      ''',
      [range[0], ...range, ...range, range[1], FundSource.bos],
    )).first;

    double read(String key) => (row[key] as num?)?.toDouble() ?? 0;

    final opening = read('opening');
    final closing = opening + read('income') - read('expense');
    final bosClosing = read('bos_closing');
    return YearSummary(
      year: year,
      openingBalance: opening,
      income: read('income'),
      expense: read('expense'),
      bosBalance: bosClosing,
      otherBalance: closing - bosClosing,
    );
  }

  // ==================== BACKUP / RESTORE ====================

  /// Seluruh isi database dalam bentuk yang bisa di-JSON-kan.
  Future<Map<String, dynamic>> exportData() async {
    final db = await database;
    return {
      'app': backupAppId,
      'schema': schemaVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'settings': (await getSettings()).toMap()..remove('id'),
      'bos_pagu': [
        for (final r in await db.query('bos_pagu', orderBy: 'year'))
          Map<String, Object?>.of(r),
      ],
      'bos_disbursements': [
        for (final r in await db.query('bos_disbursements', orderBy: 'id'))
          Map<String, Object?>.of(r),
      ],
      'transactions': [
        for (final r in await db.query('transactions', orderBy: 'id'))
          Map<String, Object?>.of(r),
      ],
    };
  }

  /// Mengganti seluruh data dengan isi backup dari [exportData].
  ///
  /// Data divalidasi lebih dulu; jika ada yang tidak valid, [FormatException]
  /// dilempar dan data lama tidak tersentuh.
  Future<void> importData(Map<String, dynamic> data) async {
    if (data['app'] != backupAppId) {
      throw const FormatException('Bukan file backup BudgetKu Edu.');
    }
    final schema = data['schema'];
    if (schema is! int || schema > schemaVersion) {
      throw const FormatException(
        'File backup berasal dari versi aplikasi yang lebih baru.',
      );
    }

    final SettingsModel settings;
    final List<BosPaguModel> pagu;
    final List<BosDisbursementModel> disbursements;
    final List<TransactionModel> transactions;
    try {
      settings = SettingsModel.fromMap(
        Map<String, dynamic>.from(data['settings'] as Map),
      );
      // Backup sebelum skema 4 tidak punya `bos_pagu`; pagunya ada di settings.
      pagu = [
        for (final m in (data['bos_pagu'] as List?) ?? const [])
          BosPaguModel.fromMap(Map<String, dynamic>.from(m as Map)),
      ];
      disbursements = [
        for (final m in data['bos_disbursements'] as List)
          BosDisbursementModel.fromMap(Map<String, dynamic>.from(m as Map)),
      ];
      transactions = [
        for (final m in data['transactions'] as List)
          TransactionModel.fromMap(Map<String, dynamic>.from(m as Map)),
      ];
    } catch (e) {
      throw FormatException('Isi file backup tidak valid: $e');
    }

    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('transactions');
      await txn.delete('bos_disbursements');
      await txn.delete('settings');
      await txn.delete('bos_pagu');
      await txn.insert('settings', settings.toMap()..remove('id'));
      if (data['bos_pagu'] == null) {
        await _insertLegacyPagu(
          txn,
          Map<String, Object?>.from(data['settings'] as Map),
        );
      }
      for (final p in pagu) {
        await txn.insert('bos_pagu', p.toMap());
      }
      for (final d in disbursements) {
        await txn.insert('bos_disbursements', d.toMap());
      }
      for (final t in transactions) {
        await txn.insert('transactions', t.toMap());
      }
    });
  }

  Future<void> close() async {
    final db = await _database;
    _database = null;
    await db?.close();
  }
}
