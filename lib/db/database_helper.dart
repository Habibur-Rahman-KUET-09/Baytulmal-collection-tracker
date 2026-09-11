import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/criteria.dart';
import '../models/entry.dart';
import '../models/protisthan.dart';
import '../models/ward.dart';

/// Single point of access to the local SQLite database.
///
/// Schema follows SRS section 5.2. `uuid` + timestamp columns exist on every
/// table (per FR-7.3) so a future cloud-sync layer can be added without a
/// schema rewrite, even though Phase 1 is fully offline.
class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static Database? _db;

  Future<Database> get database async {
    _db ??= await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'baytulmal_collection_tracker.db');
    return openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createSchema,
    );
  }

  Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE protisthan (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE criteria (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        protisthan_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (protisthan_id) REFERENCES protisthan (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE ward (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        protisthan_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (protisthan_id) REFERENCES protisthan (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE entry (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        ward_id INTEGER NOT NULL,
        criteria_id INTEGER NOT NULL,
        month INTEGER NOT NULL,
        year INTEGER NOT NULL,
        amount REAL NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (ward_id) REFERENCES ward (id) ON DELETE CASCADE,
        FOREIGN KEY (criteria_id) REFERENCES criteria (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE UNIQUE INDEX idx_entry_unique
        ON entry (ward_id, criteria_id, month, year)
    ''');

    await db.execute('CREATE INDEX idx_criteria_protisthan ON criteria (protisthan_id)');
    await db.execute('CREATE INDEX idx_ward_protisthan ON ward (protisthan_id)');
    await db.execute('CREATE INDEX idx_entry_ward ON entry (ward_id)');
    await db.execute('CREATE INDEX idx_entry_criteria ON entry (criteria_id)');
  }

  // ---------------------------------------------------------------------
  // Protisthan CRUD
  // ---------------------------------------------------------------------

  Future<int> insertProtisthan(Protisthan p) async {
    final db = await database;
    return db.insert('protisthan', p.toMap()..remove('id'));
  }

  Future<int> updateProtisthan(Protisthan p) async {
    final db = await database;
    return db.update('protisthan', p.toMap(), where: 'id = ?', whereArgs: [p.id]);
  }

  Future<int> deleteProtisthan(int id) async {
    final db = await database;
    return db.delete('protisthan', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Protisthan>> getAllProtisthan() async {
    final db = await database;
    final rows = await db.query('protisthan', orderBy: 'id ASC');
    return rows.map(Protisthan.fromMap).toList();
  }

  Future<Protisthan?> getProtisthan(int id) async {
    final db = await database;
    final rows = await db.query('protisthan', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Protisthan.fromMap(rows.first);
  }

  // ---------------------------------------------------------------------
  // Criteria CRUD
  // ---------------------------------------------------------------------

  Future<int> insertCriteria(Criteria c) async {
    final db = await database;
    return db.insert('criteria', c.toMap()..remove('id'));
  }

  Future<int> updateCriteria(Criteria c) async {
    final db = await database;
    return db.update('criteria', c.toMap(), where: 'id = ?', whereArgs: [c.id]);
  }

  Future<int> deleteCriteria(int id) async {
    final db = await database;
    return db.delete('criteria', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Criteria>> getCriteriaForProtisthan(int protisthanId) async {
    final db = await database;
    final rows = await db.query(
      'criteria',
      where: 'protisthan_id = ?',
      whereArgs: [protisthanId],
      orderBy: 'id ASC',
    );
    return rows.map(Criteria.fromMap).toList();
  }

  // ---------------------------------------------------------------------
  // Ward CRUD
  // ---------------------------------------------------------------------

  Future<int> insertWard(Ward w) async {
    final db = await database;
    return db.insert('ward', w.toMap()..remove('id'));
  }

  Future<int> updateWard(Ward w) async {
    final db = await database;
    return db.update('ward', w.toMap(), where: 'id = ?', whereArgs: [w.id]);
  }

  Future<int> deleteWard(int id) async {
    final db = await database;
    return db.delete('ward', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Ward>> getWardsForProtisthan(int protisthanId) async {
    final db = await database;
    final rows = await db.query(
      'ward',
      where: 'protisthan_id = ?',
      whereArgs: [protisthanId],
      orderBy: 'id ASC',
    );
    return rows.map(Ward.fromMap).toList();
  }

  Future<Ward?> getWard(int id) async {
    final db = await database;
    final rows = await db.query('ward', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Ward.fromMap(rows.first);
  }

  /// Counts used on the home screen card subtitle ("৫টি ওয়ার্ড · ৪টি ক্রাইটেরিয়া").
  Future<Map<int, int>> getWardCountsByProtisthan() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT protisthan_id, COUNT(*) AS cnt FROM ward GROUP BY protisthan_id',
    );
    return {for (final r in rows) r['protisthan_id'] as int: r['cnt'] as int};
  }

  Future<Map<int, int>> getCriteriaCountsByProtisthan() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT protisthan_id, COUNT(*) AS cnt FROM criteria GROUP BY protisthan_id',
    );
    return {for (final r in rows) r['protisthan_id'] as int: r['cnt'] as int};
  }

  // ---------------------------------------------------------------------
  // Entry CRUD (FR-4.x) — save() overwrites on (ward, criteria, month, year)
  // ---------------------------------------------------------------------

  /// Saves (inserts or overwrites) a single entry amount. Passing `null` or
  /// a blank amount for an already-existing entry deletes it, since every
  /// criteria field is optional (FR-4.3).
  Future<void> saveEntry({
    required int wardId,
    required int criteriaId,
    required int month,
    required int year,
    required double? amount,
    required String uuidFactory,
  }) async {
    final db = await database;
    final existing = await db.query(
      'entry',
      where: 'ward_id = ? AND criteria_id = ? AND month = ? AND year = ?',
      whereArgs: [wardId, criteriaId, month, year],
    );

    if (amount == null) {
      if (existing.isNotEmpty) {
        await db.delete('entry', where: 'id = ?', whereArgs: [existing.first['id']]);
      }
      return;
    }

    final now = DateTime.now().toIso8601String();
    if (existing.isNotEmpty) {
      await db.update(
        'entry',
        {'amount': amount, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    } else {
      await db.insert('entry', {
        'uuid': uuidFactory,
        'ward_id': wardId,
        'criteria_id': criteriaId,
        'month': month,
        'year': year,
        'amount': amount,
        'updated_at': now,
      });
    }
  }

  /// Existing entries for a ward + month/year, keyed by criteria_id — used
  /// to pre-fill the entry form (FR-4.5).
  Future<Map<int, double>> getEntriesForWardMonth(int wardId, int month, int year) async {
    final db = await database;
    final rows = await db.query(
      'entry',
      where: 'ward_id = ? AND month = ? AND year = ?',
      whereArgs: [wardId, month, year],
    );
    return {for (final r in rows) r['criteria_id'] as int: (r['amount'] as num).toDouble()};
  }

  // ---------------------------------------------------------------------
  // Calculation & Summation (FR-5.x)
  // ---------------------------------------------------------------------

  Future<double> getWardTotal(int wardId, int month, int year) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS total FROM entry '
      'WHERE ward_id = ? AND month = ? AND year = ?',
      [wardId, month, year],
    );
    return (rows.first['total'] as num).toDouble();
  }

  /// Per-criteria breakdown for a single ward + month (FR-6.2).
  Future<List<MapEntry<Criteria, double>>> getWardCriteriaBreakdown(
    int wardId,
    int protisthanId,
    int month,
    int year,
  ) async {
    final criteriaList = await getCriteriaForProtisthan(protisthanId);
    final entries = await getEntriesForWardMonth(wardId, month, year);
    return criteriaList.map((c) => MapEntry(c, entries[c.id] ?? 0.0)).toList();
  }

  /// Protisthan total for a month = sum of all its wards' totals (FR-5.4).
  Future<double> getProtisthanTotal(int protisthanId, int month, int year) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(e.amount), 0) AS total
      FROM entry e
      INNER JOIN ward w ON w.id = e.ward_id
      WHERE w.protisthan_id = ? AND e.month = ? AND e.year = ?
      ''',
      [protisthanId, month, year],
    );
    return (rows.first['total'] as num).toDouble();
  }

  /// Breakdown by Criteria across all wards of a Protisthan for a month (FR-5.3, FR-6.1).
  Future<List<MapEntry<Criteria, double>>> getProtisthanCriteriaBreakdown(
    int protisthanId,
    int month,
    int year,
  ) async {
    final db = await database;
    final criteriaList = await getCriteriaForProtisthan(protisthanId);
    final rows = await db.rawQuery(
      '''
      SELECT e.criteria_id AS criteria_id, COALESCE(SUM(e.amount), 0) AS total
      FROM entry e
      INNER JOIN ward w ON w.id = e.ward_id
      WHERE w.protisthan_id = ? AND e.month = ? AND e.year = ?
      GROUP BY e.criteria_id
      ''',
      [protisthanId, month, year],
    );
    final totals = {for (final r in rows) r['criteria_id'] as int: (r['total'] as num).toDouble()};
    return criteriaList.map((c) => MapEntry(c, totals[c.id] ?? 0.0)).toList();
  }

  /// Breakdown by Ward for a Protisthan/month (FR-6.1).
  Future<List<MapEntry<Ward, double>>> getProtisthanWardBreakdown(
    int protisthanId,
    int month,
    int year,
  ) async {
    final db = await database;
    final wards = await getWardsForProtisthan(protisthanId);
    final rows = await db.rawQuery(
      '''
      SELECT e.ward_id AS ward_id, COALESCE(SUM(e.amount), 0) AS total
      FROM entry e
      INNER JOIN ward w ON w.id = e.ward_id
      WHERE w.protisthan_id = ? AND e.month = ? AND e.year = ?
      GROUP BY e.ward_id
      ''',
      [protisthanId, month, year],
    );
    final totals = {for (final r in rows) r['ward_id'] as int: (r['total'] as num).toDouble()};
    return wards.map((w) => MapEntry(w, totals[w.id] ?? 0.0)).toList();
  }

  /// Matrix report data (FR-8.x): full ward x criteria amount grid, plus
  /// row totals, column totals and the grand total — all derived from the
  /// same Entry set so they are consistent by construction (FR-5.5).
  Future<MatrixReportData> getMatrixReport(int protisthanId, int month, int year) async {
    final wards = await getWardsForProtisthan(protisthanId);
    final criteriaList = await getCriteriaForProtisthan(protisthanId);
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT e.ward_id AS ward_id, e.criteria_id AS criteria_id, e.amount AS amount
      FROM entry e
      INNER JOIN ward w ON w.id = e.ward_id
      WHERE w.protisthan_id = ? AND e.month = ? AND e.year = ?
      ''',
      [protisthanId, month, year],
    );

    final cells = <int, Map<int, double>>{};
    for (final r in rows) {
      final wardId = r['ward_id'] as int;
      final criteriaId = r['criteria_id'] as int;
      final amount = (r['amount'] as num).toDouble();
      cells.putIfAbsent(wardId, () => {})[criteriaId] = amount;
    }

    final rowTotals = <int, double>{};
    final colTotals = <int, double>{};
    double grandTotal = 0;

    for (final w in wards) {
      double rowSum = 0;
      for (final c in criteriaList) {
        final v = cells[w.id]?[c.id] ?? 0.0;
        rowSum += v;
        colTotals[c.id!] = (colTotals[c.id] ?? 0) + v;
      }
      rowTotals[w.id!] = rowSum;
      grandTotal += rowSum;
    }

    return MatrixReportData(
      wards: wards,
      criteriaList: criteriaList,
      cells: cells,
      rowTotals: rowTotals,
      colTotals: colTotals,
      grandTotal: grandTotal,
    );
  }

  /// Trend data across a month range (FR-6.3/6.4). `mode` is "total",
  /// "criteria:<id>" or "ward:<id>".
  Future<List<TrendPoint>> getTrendData({
    required int protisthanId,
    required int startMonth,
    required int startYear,
    required int endMonth,
    required int endYear,
    int? criteriaId,
    int? wardId,
  }) async {
    final months = _monthRange(startMonth, startYear, endMonth, endYear);
    final db = await database;
    final results = <TrendPoint>[];

    for (final m in months) {
      String where = 'w.protisthan_id = ? AND e.month = ? AND e.year = ?';
      final args = <Object?>[protisthanId, m.month, m.year];
      if (criteriaId != null) {
        where += ' AND e.criteria_id = ?';
        args.add(criteriaId);
      }
      if (wardId != null) {
        where += ' AND e.ward_id = ?';
        args.add(wardId);
      }
      final rows = await db.rawQuery(
        '''
        SELECT COALESCE(SUM(e.amount), 0) AS total
        FROM entry e
        INNER JOIN ward w ON w.id = e.ward_id
        WHERE $where
        ''',
        args,
      );
      results.add(TrendPoint(month: m.month, year: m.year, total: (rows.first['total'] as num).toDouble()));
    }
    return results;
  }

  List<_MonthYear> _monthRange(int startMonth, int startYear, int endMonth, int endYear) {
    final list = <_MonthYear>[];
    var m = startMonth;
    var y = startYear;
    while (y < endYear || (y == endYear && m <= endMonth)) {
      list.add(_MonthYear(m, y));
      m++;
      if (m > 12) {
        m = 1;
        y++;
      }
    }
    return list;
  }

  // ---------------------------------------------------------------------
  // Full data export / import (backup & restore — additional feature)
  // ---------------------------------------------------------------------

  Future<Map<String, dynamic>> exportAllData() async {
    final db = await database;
    final protisthanRows = await db.query('protisthan');
    final criteriaRows = await db.query('criteria');
    final wardRows = await db.query('ward');
    final entryRows = await db.query('entry');
    return {
      'protisthan': protisthanRows,
      'criteria': criteriaRows,
      'ward': wardRows,
      'entry': entryRows,
    };
  }

  /// Replaces ALL local data with the given backup payload inside one
  /// transaction. Caller is responsible for confirming this destructive
  /// action with the user first.
  Future<void> importAllData(Map<String, dynamic> data) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('entry');
      await txn.delete('ward');
      await txn.delete('criteria');
      await txn.delete('protisthan');

      final batch = txn.batch();
      for (final row in (data['protisthan'] as List)) {
        batch.insert('protisthan', Map<String, dynamic>.from(row as Map));
      }
      for (final row in (data['criteria'] as List)) {
        batch.insert('criteria', Map<String, dynamic>.from(row as Map));
      }
      for (final row in (data['ward'] as List)) {
        batch.insert('ward', Map<String, dynamic>.from(row as Map));
      }
      for (final row in (data['entry'] as List)) {
        batch.insert('entry', Map<String, dynamic>.from(row as Map));
      }
      await batch.commit(noResult: true);
    });
  }
}

class _MonthYear {
  final int month;
  final int year;
  _MonthYear(this.month, this.year);
}

class TrendPoint {
  final int month;
  final int year;
  final double total;
  TrendPoint({required this.month, required this.year, required this.total});
}

class MatrixReportData {
  final List<Ward> wards;
  final List<Criteria> criteriaList;
  final Map<int, Map<int, double>> cells; // wardId -> criteriaId -> amount
  final Map<int, double> rowTotals; // wardId -> total
  final Map<int, double> colTotals; // criteriaId -> total
  final double grandTotal;

  MatrixReportData({
    required this.wards,
    required this.criteriaList,
    required this.cells,
    required this.rowTotals,
    required this.colTotals,
    required this.grandTotal,
  });

  double amountFor(int wardId, int criteriaId) => cells[wardId]?[criteriaId] ?? 0.0;
}
