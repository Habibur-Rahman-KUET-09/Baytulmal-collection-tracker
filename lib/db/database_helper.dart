import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/criteria.dart';
import '../models/protisthan.dart';
import '../models/remittance.dart';
import '../models/ward.dart';

const int _specialNisabOrder = 1; // ধার্যকৃত নিসাব (fixed — mirrors ward.target_amount, no Entry)
const int _specialIncomeOrder = 2; // আয়
const int _specialExpenseOrder = 3; // ব্যয়
const int _specialActualDepositOrder = 4; // বাস্তব জমা (computed = আয় − ব্যয়, no Entry)
const _uuid = Uuid();

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
      version: 4,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createSchema,
      onUpgrade: _upgradeSchema,
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
        special_order INTEGER,
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
        target_amount REAL NOT NULL DEFAULT 0,
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

    await _createRemittanceTable(db);
  }

  Future<void> _createRemittanceTable(Database db) async {
    await db.execute('''
      CREATE TABLE remittance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        protisthan_id INTEGER NOT NULL,
        month INTEGER NOT NULL,
        year INTEGER NOT NULL,
        expense_amount REAL NOT NULL DEFAULT 0,
        actual_deposit_amount REAL NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (protisthan_id) REFERENCES protisthan (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX idx_remittance_unique
        ON remittance (protisthan_id, month, year)
    ''');
    await db.execute('CREATE INDEX idx_remittance_protisthan ON remittance (protisthan_id)');
  }

  /// v1 -> v2: special criteria (আদায়/বকেয়া + ward-level নির্ধারিত
  /// লক্ষ্যমাত্রা) and the higher-management remittance page.
  /// v2 -> v3: special criteria became লক্ষ্যমাত্রা (১)/খরচ (২)/সিনিয়র
  /// ম্যানেজমেন্ট এ জমা (৩), replacing আদায় (২)/বকেয়া (৩).
  /// v3 -> v4: special criteria became ধার্যকৃত নিসাব (১)/আয় (২)/ব্যয় (৩)
  /// + a new বাস্তব জমা (৪, computed = আয়−ব্যয়, no Entry).
  Future<void> _upgradeSchema(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE criteria ADD COLUMN special_order INTEGER');
      await db.execute('ALTER TABLE ward ADD COLUMN target_amount REAL NOT NULL DEFAULT 0');
      await _createRemittanceTable(db);
    }
    if (oldVersion < 3) {
      await _migrateToTargetExpenseDepositCriteria(db);
    }
    if (oldVersion < 4) {
      await _migrateToNisabIncomeExpenseDeposit(db);
    }
  }

  /// v2 -> v3: renames the existing special_order ২/৩ criteria in place
  /// (আদায় -> খরচ, বকেয়া -> সিনিয়র ম্যানেজমেন্ট এ জমা — their historical
  /// Entry amounts carry over under the new labels) and seeds special_order
  /// ১ (লক্ষ্যমাত্রা) for every Protisthan, since it didn't exist as a
  /// Criteria row before v3.
  Future<void> _migrateToTargetExpenseDepositCriteria(Database db) async {
    await db.update(
      'criteria',
      {'name': 'খরচ'},
      where: 'special_order = ?',
      whereArgs: [2],
    );
    await db.update(
      'criteria',
      {'name': 'সিনিয়র ম্যানেজমেন্ট এ জমা'},
      where: 'special_order = ?',
      whereArgs: [3],
    );
    final protisthanRows = await db.query('protisthan', columns: ['id']);
    for (final row in protisthanRows) {
      final id = row['id'] as int;
      final existing = await db.query(
        'criteria',
        where: 'protisthan_id = ? AND special_order IS NOT NULL',
        whereArgs: [id],
      );
      final haveOrders = existing.map((r) => r['special_order'] as int).toSet();
      if (!haveOrders.contains(1)) {
        await db.insert('criteria', {
          'uuid': _uuid.v4(),
          'protisthan_id': id,
          'name': 'লক্ষ্যমাত্রা',
          'created_at': DateTime.now().toIso8601String(),
          'special_order': 1,
        });
      }
    }
  }

  /// v3 -> v4: renames the existing special_order ১/২/৩ criteria in place
  /// (লক্ষ্যমাত্রা -> ধার্যকৃত নিসাব, খরচ -> আয়, সিনিয়র ম্যানেজমেন্ট এ জমা ->
  /// ব্যয় — their historical Entry amounts on ২/৩ carry over under the new
  /// labels) and seeds special_order ৪ (বাস্তব জমা) for every Protisthan,
  /// since it didn't exist as a Criteria row before v4.
  Future<void> _migrateToNisabIncomeExpenseDeposit(Database db) async {
    await db.update(
      'criteria',
      {'name': 'ধার্যকৃত নিসাব'},
      where: 'special_order = ?',
      whereArgs: [_specialNisabOrder],
    );
    await db.update(
      'criteria',
      {'name': 'আয়'},
      where: 'special_order = ?',
      whereArgs: [_specialIncomeOrder],
    );
    await db.update(
      'criteria',
      {'name': 'ব্যয়'},
      where: 'special_order = ?',
      whereArgs: [_specialExpenseOrder],
    );
    await _seedSpecialCriteriaForAllProtisthan(db);
  }

  /// Ensures every existing Protisthan has all four special criteria
  /// (new Protisthan get these at creation time instead — see
  /// [ensureSpecialCriteria]).
  Future<void> _seedSpecialCriteriaForAllProtisthan(Database db) async {
    final protisthanRows = await db.query('protisthan', columns: ['id']);
    for (final row in protisthanRows) {
      await ensureSpecialCriteria(row['id'] as int, db: db);
    }
  }

  /// Creates this Protisthan's ধার্যকৃত নিসাব/আয়/ব্যয়/বাস্তব জমা special
  /// criteria if they don't already exist. Safe to call repeatedly (e.g.
  /// right after creating a Protisthan, and defensively during the v3->v4
  /// migration).
  Future<void> ensureSpecialCriteria(int protisthanId, {Database? db}) async {
    final database = db ?? await this.database;
    final existing = await database.query(
      'criteria',
      where: 'protisthan_id = ? AND special_order IS NOT NULL',
      whereArgs: [protisthanId],
    );
    final haveOrders = existing.map((r) => r['special_order'] as int).toSet();
    final now = DateTime.now().toIso8601String();

    Future<void> seed(int order, String name) async {
      if (!haveOrders.contains(order)) {
        await database.insert('criteria', {
          'uuid': _uuid.v4(),
          'protisthan_id': protisthanId,
          'name': name,
          'created_at': now,
          'special_order': order,
        });
      }
    }

    await seed(_specialNisabOrder, 'ধার্যকৃত নিসাব');
    await seed(_specialIncomeOrder, 'আয়');
    await seed(_specialExpenseOrder, 'ব্যয়');
    await seed(_specialActualDepositOrder, 'বাস্তব জমা');
  }

  // ---------------------------------------------------------------------
  // Protisthan CRUD
  // ---------------------------------------------------------------------

  /// Also seeds this Protisthan's ধার্যকৃত নিসাব/আয়/ব্যয়/বাস্তব জমা
  /// special criteria (section 4/5 of the special-criteria feature) so
  /// every Protisthan always has them, without the caller needing to know
  /// about that detail.
  Future<int> insertProtisthan(Protisthan p) async {
    final db = await database;
    final id = await db.insert('protisthan', p.toMap()..remove('id'));
    await ensureSpecialCriteria(id, db: db);
    return id;
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

  /// Special criteria (ধার্যকৃত নিসাব/আয়/ব্যয়/বাস্তব জমা) can't be deleted —
  /// the fixed relationship (আয় − ব্যয় = বাস্তব জমা) depends on all four
  /// always existing. The UI already hides the delete action for them;
  /// this is the backstop.
  Future<int> deleteCriteria(int id) async {
    final db = await database;
    final rows = await db.query('criteria', where: 'id = ?', whereArgs: [id]);
    if (rows.isNotEmpty && rows.first['special_order'] != null) {
      throw StateError('special criteria (ধার্যকৃত নিসাব/আয়/ব্যয়/বাস্তব জমা) cannot be deleted');
    }
    return db.delete('criteria', where: 'id = ?', whereArgs: [id]);
  }

  /// Special criteria always sort first, in their defined order, regardless
  /// of when they were created — migration-seeded special criteria on a
  /// pre-existing Protisthan would otherwise land after that Protisthan's
  /// normal criteria by id.
  Future<List<Criteria>> getCriteriaForProtisthan(int protisthanId) async {
    final db = await database;
    final rows = await db.query(
      'criteria',
      where: 'protisthan_id = ?',
      whereArgs: [protisthanId],
      orderBy: 'CASE WHEN special_order IS NULL THEN 1 ELSE 0 END, special_order ASC, id ASC',
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

  /// Ward total for a month (FR-5.x) — excludes ধার্যকৃত নিসাব (১) and আয়
  /// (২) the same way [getMatrixReport]'s row totals do (আয়'s contribution
  /// flows through ব্যয়+বাস্তব জমা instead — see [Criteria.specialOrder]),
  /// so this always agrees with that screen's row total for the same ward.
  Future<double> getWardTotal(int wardId, int month, int year) async {
    final ward = await getWard(wardId);
    if (ward == null) return 0;
    final breakdown = await getWardCriteriaBreakdown(wardId, ward.protisthanId, month, year);
    return breakdown.fold<double>(0, (sum, e) {
      if (e.key.isFixedTarget || e.key.specialOrder == _specialIncomeOrder) return sum;
      return sum + e.value;
    });
  }

  /// Per-criteria breakdown for a single ward + month (FR-6.2). ধার্যকৃত
  /// নিসাব (১) isn't backed by an Entry — its value is always the ward's
  /// fixed [Ward.targetAmount]. বাস্তব জমা (৪) isn't either — its value is
  /// always আয়(২) − ব্যয়(৩) for that ward+month.
  Future<List<MapEntry<Criteria, double>>> getWardCriteriaBreakdown(
    int wardId,
    int protisthanId,
    int month,
    int year,
  ) async {
    final criteriaList = await getCriteriaForProtisthan(protisthanId);
    final entries = await getEntriesForWardMonth(wardId, month, year);
    final ward = await getWard(wardId);
    final targetAmount = ward?.targetAmount ?? 0;

    int? incomeId, expenseId;
    for (final c in criteriaList) {
      if (c.specialOrder == _specialIncomeOrder) incomeId = c.id;
      if (c.specialOrder == _specialExpenseOrder) expenseId = c.id;
    }
    final actualDeposit = (entries[incomeId] ?? 0) - (entries[expenseId] ?? 0);

    return criteriaList.map((c) {
      if (c.isFixedTarget) return MapEntry(c, targetAmount);
      if (c.isComputedDeposit) return MapEntry(c, actualDeposit);
      return MapEntry(c, entries[c.id] ?? 0.0);
    }).toList();
  }

  /// Special criteria ১ (ধার্যকৃত নিসাব) at the Protisthan level: the sum
  /// of all its wards' fixed target amounts (section 5) — not stored
  /// anywhere itself, always derived.
  Future<double> getProtisthanTargetTotal(int protisthanId) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(target_amount), 0) AS total FROM ward WHERE protisthan_id = ?',
      [protisthanId],
    );
    return (rows.first['total'] as num).toDouble();
  }

  /// Protisthan total for a month = sum of all its wards' totals (FR-5.4)
  /// — same ধার্যকৃত নিসাব/আয় exclusion rule as [getWardTotal]/
  /// [getMatrixReport], so this always agrees with the matrix's grand total.
  Future<double> getProtisthanTotal(int protisthanId, int month, int year) async {
    final breakdown = await getProtisthanCriteriaBreakdown(protisthanId, month, year);
    return breakdown.fold<double>(0, (sum, e) {
      if (e.key.isFixedTarget || e.key.specialOrder == _specialIncomeOrder) return sum;
      return sum + e.value;
    });
  }

  /// Breakdown by Criteria across all wards of a Protisthan for a month
  /// (FR-5.3, FR-6.1). ধার্যকৃত নিসাব (১) isn't backed by any Entry — its
  /// value is always [getProtisthanTargetTotal], the sum of all this
  /// Protisthan's wards' fixed target amounts. বাস্তব জমা (৪) isn't either
  /// — its value is always this Protisthan's total আয়(২) minus total
  /// ব্যয়(৩) for the month.
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
    final targetTotal = await getProtisthanTargetTotal(protisthanId);

    int? incomeId, expenseId;
    for (final c in criteriaList) {
      if (c.specialOrder == _specialIncomeOrder) incomeId = c.id;
      if (c.specialOrder == _specialExpenseOrder) expenseId = c.id;
    }
    final actualDepositTotal = (totals[incomeId] ?? 0) - (totals[expenseId] ?? 0);

    return criteriaList.map((c) {
      if (c.isFixedTarget) return MapEntry(c, targetTotal);
      if (c.isComputedDeposit) return MapEntry(c, actualDepositTotal);
      return MapEntry(c, totals[c.id] ?? 0.0);
    }).toList();
  }

  /// বাস্তব জমা (special_order ৪) summed across all this Protisthan's wards
  /// for a month — this Protisthan's total আয় minus total ব্যয়. Used for
  /// the "উচ্চ কর্তৃপক্ষে বাস্তব জমা" report calculation.
  Future<double> getProtisthanActualDepositTotal(int protisthanId, int month, int year) async {
    final breakdown = await getProtisthanCriteriaBreakdown(protisthanId, month, year);
    for (final e in breakdown) {
      if (e.key.isComputedDeposit) return e.value;
    }
    return 0;
  }

  /// ব্যয় (special_order ৩) summed across all this Protisthan's wards for a
  /// month — ওয়ার্ডগুলোর মোট ব্যয়, প্রতিষ্ঠানের নিজস্ব ব্যয় ([Remittance])
  /// থেকে আলাদা।
  Future<double> getWardExpenseTotal(int protisthanId, int month, int year) async {
    final breakdown = await getProtisthanCriteriaBreakdown(protisthanId, month, year);
    for (final e in breakdown) {
      if (e.key.specialOrder == _specialExpenseOrder) return e.value;
    }
    return 0;
  }

  /// Breakdown by Ward for a Protisthan/month (FR-6.1) — reuses
  /// [getWardTotal] per ward so this always agrees with that screen's own
  /// headline total for the same ward.
  Future<List<MapEntry<Ward, double>>> getProtisthanWardBreakdown(
    int protisthanId,
    int month,
    int year,
  ) async {
    final wards = await getWardsForProtisthan(protisthanId);
    final result = <MapEntry<Ward, double>>[];
    for (final w in wards) {
      result.add(MapEntry(w, await getWardTotal(w.id!, month, year)));
    }
    return result;
  }

  /// Matrix report data (FR-8.x): full ward x criteria amount grid, plus
  /// row totals, column totals and the grand total — all derived from the
  /// same Entry set so they are consistent by construction (FR-5.5).
  ///
  /// ধার্যকৃত নিসাব (১) has no Entry of its own — its cell is always the
  /// ward's fixed [Ward.targetAmount], the same every month. বাস্তব জমা (৪)
  /// has no Entry either — its cell is always আয়(২) − ব্যয়(৩) for that
  /// ward+month. নিসাব (১) and আয় (২) are excluded from every row total
  /// and the grand total (১ is a reference figure rather than money
  /// collected, and ২'s contribution flows through via ৩+৪ instead — see
  /// [Criteria.specialOrder]), though both still show their own column
  /// total.
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

    Criteria? targetCriteria, incomeCriteria, expenseCriteria, depositCriteria;
    for (final c in criteriaList) {
      if (c.isFixedTarget) targetCriteria = c;
      if (c.specialOrder == _specialIncomeOrder) incomeCriteria = c;
      if (c.specialOrder == _specialExpenseOrder) expenseCriteria = c;
      if (c.isComputedDeposit) depositCriteria = c;
    }
    if (targetCriteria != null) {
      for (final w in wards) {
        cells.putIfAbsent(w.id!, () => {})[targetCriteria.id!] = w.targetAmount;
      }
    }
    if (depositCriteria != null) {
      for (final w in wards) {
        final income = cells[w.id]?[incomeCriteria?.id] ?? 0.0;
        final expense = cells[w.id]?[expenseCriteria?.id] ?? 0.0;
        cells.putIfAbsent(w.id!, () => {})[depositCriteria.id!] = income - expense;
      }
    }

    final rowTotals = <int, double>{};
    final colTotals = <int, double>{};
    double grandTotal = 0;

    for (final w in wards) {
      double rowSum = 0;
      for (final c in criteriaList) {
        final v = cells[w.id]?[c.id] ?? 0.0;
        colTotals[c.id!] = (colTotals[c.id] ?? 0) + v;
        if (!c.isFixedTarget && c.specialOrder != _specialIncomeOrder) rowSum += v;
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

  /// Trend data across a month range (FR-6.3/6.4). Pass neither
  /// `criteriaId` nor `wardId` for the Protisthan total, or exactly one of
  /// them to filter to a single Criteria or Ward.
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
  // Higher-management remittance (protisthan + month): total collection is
  // derived from Entry data via getProtisthanTotal; expense and the actual
  // deposited amount are the two figures recorded here.
  // ---------------------------------------------------------------------

  Future<Remittance?> getRemittance(int protisthanId, int month, int year) async {
    final db = await database;
    final rows = await db.query(
      'remittance',
      where: 'protisthan_id = ? AND month = ? AND year = ?',
      whereArgs: [protisthanId, month, year],
    );
    if (rows.isEmpty) return null;
    return Remittance.fromMap(rows.first);
  }

  /// Inserts or overwrites (by protisthan+month/year, mirroring the Entry
  /// overwrite-on-re-entry rule) this month's expense/actual-deposit
  /// figures.
  Future<void> saveRemittance({
    required int protisthanId,
    required int month,
    required int year,
    required double expenseAmount,
    required double actualDepositAmount,
  }) async {
    final db = await database;
    final existing = await getRemittance(protisthanId, month, year);
    final now = DateTime.now().toIso8601String();
    if (existing != null) {
      await db.update(
        'remittance',
        {
          'expense_amount': expenseAmount,
          'actual_deposit_amount': actualDepositAmount,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [existing.id],
      );
    } else {
      await db.insert('remittance', {
        'uuid': _uuid.v4(),
        'protisthan_id': protisthanId,
        'month': month,
        'year': year,
        'expense_amount': expenseAmount,
        'actual_deposit_amount': actualDepositAmount,
        'updated_at': now,
      });
    }
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
    final remittanceRows = await db.query('remittance');
    return {
      'protisthan': protisthanRows,
      'criteria': criteriaRows,
      'ward': wardRows,
      'entry': entryRows,
      'remittance': remittanceRows,
    };
  }

  /// Replaces ALL local data with the given backup payload inside one
  /// transaction. Caller is responsible for confirming this destructive
  /// action with the user first.
  Future<void> importAllData(Map<String, dynamic> data) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('entry');
      await txn.delete('remittance');
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
      // Older backups (from before the higher-management feature) simply
      // won't have a 'remittance' key — nothing to restore, not an error.
      for (final row in (data['remittance'] as List? ?? const [])) {
        batch.insert('remittance', Map<String, dynamic>.from(row as Map));
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
