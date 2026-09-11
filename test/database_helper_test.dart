import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'package:baytulmal_collection_tracker/db/database_helper.dart';
import 'package:baytulmal_collection_tracker/models/criteria.dart';
import 'package:baytulmal_collection_tracker/models/protisthan.dart';
import 'package:baytulmal_collection_tracker/models/ward.dart';

const _uuid = Uuid();

/// Exercises [DatabaseHelper] against a real (FFI-backed) SQLite database.
/// This is the one place that can actually verify the SRS's
/// calculation/consistency claims (section 3.5) and cascading-delete /
/// overwrite-on-re-entry rules (section 2.3, FR-4.5) rather than just
/// reading the SQL.
///
/// [DatabaseHelper] is a singleton that lazily opens one database and keeps
/// it open for the process lifetime, so every test below shares that same
/// database rather than getting a fresh one — each test creates its own
/// uniquely-named Protisthan/Ward/Criteria and only asserts against the ids
/// it just created, so earlier tests' rows never interfere.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final db = DatabaseHelper.instance;

  setUpAll(() async {
    // DatabaseHelper always opens the same on-disk file; start every test
    // run from a clean schema instead of accumulating rows across runs.
    final path = join(await databaseFactory.getDatabasesPath(), 'baytulmal_collection_tracker.db');
    await databaseFactory.deleteDatabase(path);
  });

  Future<int> addProtisthan(String name) async {
    return db.insertProtisthan(
      Protisthan(uuid: 'p-$name', name: name, createdAt: DateTime.now().toIso8601String()),
    );
  }

  Future<int> addCriteria(int protisthanId, String name) async {
    return db.insertCriteria(
      Criteria(
        uuid: 'c-$name-$protisthanId',
        protisthanId: protisthanId,
        name: name,
        createdAt: DateTime.now().toIso8601String(),
      ),
    );
  }

  Future<int> addWard(int protisthanId, String name) async {
    return db.insertWard(
      Ward(
        uuid: 'w-$name-$protisthanId',
        protisthanId: protisthanId,
        name: name,
        createdAt: DateTime.now().toIso8601String(),
      ),
    );
  }

  test('re-entering an amount for the same ward+criteria+month overwrites, not duplicates (FR-4.5)', () async {
    final pId = await addProtisthan('কারওয়ান বাজার');
    final cId = await addCriteria(pId, 'দোকান ভাড়া');
    final wId = await addWard(pId, 'ওয়ার্ড ১');

    await db.saveEntry(wardId: wId, criteriaId: cId, month: 9, year: 2026, amount: 18000, uuidFactory: _uuid.v4());
    await db.saveEntry(wardId: wId, criteriaId: cId, month: 9, year: 2026, amount: 20000, uuidFactory: _uuid.v4());

    final entries = await db.getEntriesForWardMonth(wId, 9, 2026);
    expect(entries, hasLength(1));
    expect(entries[cId], 20000);
  });

  test('saving a blank amount over an existing entry deletes it (all criteria optional, FR-4.3)', () async {
    final pId = await addProtisthan('মিরপুর কাঁচাবাজার');
    final cId = await addCriteria(pId, 'টোল');
    final wId = await addWard(pId, 'ওয়ার্ড ১');

    await db.saveEntry(wardId: wId, criteriaId: cId, month: 9, year: 2026, amount: 5000, uuidFactory: _uuid.v4());
    await db.saveEntry(wardId: wId, criteriaId: cId, month: 9, year: 2026, amount: null, uuidFactory: _uuid.v4());

    final entries = await db.getEntriesForWardMonth(wId, 9, 2026);
    expect(entries, isEmpty);
  });

  test('ward and protisthan totals stay consistent with the matrix report grand total (FR-5.5)', () async {
    final pId = await addProtisthan('যাত্রাবাড়ী হাট');
    final c1 = await addCriteria(pId, 'দোকান ভাড়া');
    final c2 = await addCriteria(pId, 'টোল');
    final c3 = await addCriteria(pId, 'পার্কিং ফি');
    final w1 = await addWard(pId, 'ওয়ার্ড ১');
    final w2 = await addWard(pId, 'ওয়ার্ড ২');
    final w3 = await addWard(pId, 'ওয়ার্ড ৩');

    final amounts = <List<Object?>>[
      [w1, c1, 18000.0], [w1, c2, 5500.0],
      [w2, c1, 15000.0], [w2, c2, 4000.0], [w2, c3, 3000.0],
      [w3, c1, 12000.0], [w3, c2, 3500.0], [w3, c3, 1500.0],
    ];
    for (final a in amounts) {
      await db.saveEntry(
        wardId: a[0] as int,
        criteriaId: a[1] as int,
        month: 9,
        year: 2026,
        amount: a[2] as double,
        uuidFactory: _uuid.v4(),
      );
    }

    final w1Total = await db.getWardTotal(w1, 9, 2026);
    final w2Total = await db.getWardTotal(w2, 9, 2026);
    final w3Total = await db.getWardTotal(w3, 9, 2026);
    expect(w1Total, 23500);
    expect(w2Total, 22000);
    expect(w3Total, 17000);

    final protisthanTotal = await db.getProtisthanTotal(pId, 9, 2026);
    expect(protisthanTotal, w1Total + w2Total + w3Total);
    expect(protisthanTotal, 62500);

    final criteriaBreakdown = await db.getProtisthanCriteriaBreakdown(pId, 9, 2026);
    final criteriaSum = criteriaBreakdown.fold<double>(0, (s, e) => s + e.value);
    expect(criteriaSum, protisthanTotal);

    final matrix = await db.getMatrixReport(pId, 9, 2026);
    expect(matrix.grandTotal, protisthanTotal);
    expect(matrix.rowTotals.values.fold<double>(0, (s, v) => s + v), matrix.grandTotal);
    expect(matrix.colTotals.values.fold<double>(0, (s, v) => s + v), matrix.grandTotal);
    // FR-8.6: an unentered ward+criteria cell reads as 0 in the raw data
    // (the "—" placeholder is a display-layer concern, not a data concern).
    expect(matrix.amountFor(w1, c3), 0);
  });

  test('a criteria added after some entries exist shows as blank for past months, no backfill (FR-2.5)', () async {
    final pId = await addProtisthan('নতুন বাজার');
    final c1 = await addCriteria(pId, 'দোকান ভাড়া');
    final wId = await addWard(pId, 'ওয়ার্ড ১');
    await db.saveEntry(wardId: wId, criteriaId: c1, month: 8, year: 2026, amount: 10000, uuidFactory: _uuid.v4());

    final c2 = await addCriteria(pId, 'নতুন খাত');
    final entriesForAugust = await db.getEntriesForWardMonth(wId, 8, 2026);

    expect(entriesForAugust.containsKey(c1), isTrue);
    expect(entriesForAugust.containsKey(c2), isFalse); // blank, not backfilled
    final breakdown = await db.getWardCriteriaBreakdown(wId, pId, 8, 2026);
    expect(breakdown.firstWhere((e) => e.key.id == c2).value, 0);
  });

  test('deleting a protisthan cascades to its criteria, wards and entries (FR-1.4)', () async {
    final pId = await addProtisthan('বাতিল হবে');
    final cId = await addCriteria(pId, 'ক্রাইটেরিয়া');
    final wId = await addWard(pId, 'ওয়ার্ড');
    await db.saveEntry(wardId: wId, criteriaId: cId, month: 9, year: 2026, amount: 1000, uuidFactory: _uuid.v4());

    await db.deleteProtisthan(pId);

    expect(await db.getCriteriaForProtisthan(pId), isEmpty);
    expect(await db.getWardsForProtisthan(pId), isEmpty);
    final rawEntries = (await db.exportAllData())['entry'] as List;
    expect(rawEntries.where((e) => e['ward_id'] == wId), isEmpty);
  });

  test('deleting a ward cascades to its entries only (FR-3.4)', () async {
    final pId = await addProtisthan('প্রতিষ্ঠান-ওয়ার্ড-টেস্ট');
    final cId = await addCriteria(pId, 'ক্রাইটেরিয়া');
    final w1 = await addWard(pId, 'ওয়ার্ড ১');
    final w2 = await addWard(pId, 'ওয়ার্ড ২');
    await db.saveEntry(wardId: w1, criteriaId: cId, month: 9, year: 2026, amount: 1000, uuidFactory: _uuid.v4());
    await db.saveEntry(wardId: w2, criteriaId: cId, month: 9, year: 2026, amount: 2000, uuidFactory: _uuid.v4());

    await db.deleteWard(w1);

    expect(await db.getWardTotal(w1, 9, 2026), 0);
    expect(await db.getWardTotal(w2, 9, 2026), 2000); // untouched
    final ward2Still = await db.getWard(w2);
    expect(ward2Still, isNotNull);
  });

  test('deleting a criteria removes only its own entries across all wards (FR-2.4)', () async {
    final pId = await addProtisthan('প্রতিষ্ঠান-ক্রাইটেরিয়া-টেস্ট');
    final c1 = await addCriteria(pId, 'ক্রাইটেরিয়া ১');
    final c2 = await addCriteria(pId, 'ক্রাইটেরিয়া ২');
    final wId = await addWard(pId, 'ওয়ার্ড');
    await db.saveEntry(wardId: wId, criteriaId: c1, month: 9, year: 2026, amount: 1000, uuidFactory: _uuid.v4());
    await db.saveEntry(wardId: wId, criteriaId: c2, month: 9, year: 2026, amount: 2000, uuidFactory: _uuid.v4());

    await db.deleteCriteria(c1);

    expect(await db.getWardTotal(wId, 9, 2026), 2000);
  });

  test('trend data covers every month in range, including months with no entries (FR-6.3)', () async {
    final pId = await addProtisthan('প্রতিষ্ঠান-ট্রেন্ড-টেস্ট');
    final cId = await addCriteria(pId, 'ক্রাইটেরিয়া');
    final wId = await addWard(pId, 'ওয়ার্ড');
    await db.saveEntry(wardId: wId, criteriaId: cId, month: 7, year: 2026, amount: 5000, uuidFactory: _uuid.v4());
    // August is deliberately left empty.
    await db.saveEntry(wardId: wId, criteriaId: cId, month: 9, year: 2026, amount: 7000, uuidFactory: _uuid.v4());

    final points = await db.getTrendData(
      protisthanId: pId,
      startMonth: 7,
      startYear: 2026,
      endMonth: 9,
      endYear: 2026,
    );

    expect(points, hasLength(3));
    expect(points[0].total, 5000);
    expect(points[1].total, 0);
    expect(points[2].total, 7000);
  });

  test('exportAllData / importAllData round-trips every row exactly (whole-database backup)', () async {
    final pId = await addProtisthan('ব্যাকআপ পরীক্ষা');
    final cId = await addCriteria(pId, 'ক্রাইটেরিয়া');
    final wId = await addWard(pId, 'ওয়ার্ড');
    await db.saveEntry(wardId: wId, criteriaId: cId, month: 9, year: 2026, amount: 4321, uuidFactory: _uuid.v4());

    // Snapshot the whole (shared, singleton) database, then restore that
    // exact snapshot — a true no-op if the round-trip is faithful.
    final exported = await db.exportAllData();
    await db.importAllData(exported);

    final restored = await db.getAllProtisthan();
    expect(restored.any((p) => p.name == 'ব্যাকআপ পরীক্ষা'), isTrue);
    expect(await db.getWardTotal(wId, 9, 2026), 4321);
  });

  test('insertProtisthan auto-seeds the আদায়/বকেয়া special criteria', () async {
    final pId = await addProtisthan('স্পেশাল ক্রাইটেরিয়া টেস্ট');

    final criteria = await db.getCriteriaForProtisthan(pId);

    expect(criteria, hasLength(2));
    expect(criteria.every((c) => c.isSpecial), isTrue);
    expect(criteria[0].name, 'আদায়');
    expect(criteria[0].specialOrder, 2);
    expect(criteria[1].name, 'বকেয়া');
    expect(criteria[1].specialOrder, 3);
  });

  test('special criteria always sort first regardless of insertion order', () async {
    final pId = await addProtisthan('সর্টিং টেস্ট');
    // Normal criteria added after the auto-seeded special ones.
    await addCriteria(pId, 'দোকান ভাড়া');
    await addCriteria(pId, 'টোল');

    final criteria = await db.getCriteriaForProtisthan(pId);

    expect(criteria, hasLength(4));
    expect(criteria[0].isSpecial, isTrue);
    expect(criteria[1].isSpecial, isTrue);
    expect(criteria[2].name, 'দোকান ভাড়া');
    expect(criteria[3].name, 'টোল');
  });

  test('deleteCriteria throws for a special criteria (আদায়/বকেয়া cannot be deleted)', () async {
    final pId = await addProtisthan('ডিলিট প্রোটেকশন টেস্ট');
    final criteria = await db.getCriteriaForProtisthan(pId);
    final specialCriteria = criteria.firstWhere((c) => c.isSpecial);

    expect(() => db.deleteCriteria(specialCriteria.id!), throwsA(isA<StateError>()));

    // Untouched — still there after the failed delete attempt.
    expect(await db.getCriteriaForProtisthan(pId), hasLength(2));
  });

  test('ward target amount round-trips and getProtisthanTargetTotal sums all wards', () async {
    final pId = await addProtisthan('লক্ষ্যমাত্রা টেস্ট');
    final w1Id = await db.insertWard(
      Ward(
        uuid: 'w-target-1-$pId',
        protisthanId: pId,
        name: 'ওয়ার্ড ১',
        createdAt: DateTime.now().toIso8601String(),
        targetAmount: 30000,
      ),
    );
    final w2Id = await db.insertWard(
      Ward(
        uuid: 'w-target-2-$pId',
        protisthanId: pId,
        name: 'ওয়ার্ড ২',
        createdAt: DateTime.now().toIso8601String(),
        targetAmount: 45000,
      ),
    );

    final w1 = await db.getWard(w1Id);
    expect(w1!.targetAmount, 30000);

    final wardsForProtisthan = await db.getWardsForProtisthan(pId);
    expect(wardsForProtisthan.firstWhere((w) => w.id == w2Id).targetAmount, 45000);

    final targetTotal = await db.getProtisthanTargetTotal(pId);
    expect(targetTotal, 75000);
  });

  test('saveRemittance / getRemittance round-trips and overwrites on re-entry, mirroring saveEntry (FR-4.5)', () async {
    final pId = await addProtisthan('রেমিট্যান্স টেস্ট');

    expect(await db.getRemittance(pId, 9, 2026), isNull);

    await db.saveRemittance(
      protisthanId: pId,
      month: 9,
      year: 2026,
      expenseAmount: 5000,
      actualDepositAmount: 40000,
    );
    final first = await db.getRemittance(pId, 9, 2026);
    expect(first, isNotNull);
    expect(first!.expenseAmount, 5000);
    expect(first.actualDepositAmount, 40000);

    // Re-entering the same protisthan+month overwrites, not duplicates.
    await db.saveRemittance(
      protisthanId: pId,
      month: 9,
      year: 2026,
      expenseAmount: 6000,
      actualDepositAmount: 42000,
    );
    final updated = await db.getRemittance(pId, 9, 2026);
    expect(updated!.id, first.id);
    expect(updated.expenseAmount, 6000);
    expect(updated.actualDepositAmount, 42000);
  });
}
