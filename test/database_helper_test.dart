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

  test('insertProtisthan auto-seeds the ধার্যকৃত নিসাব/আয়/ব্যয়/বাস্তব জমা special criteria', () async {
    final pId = await addProtisthan('স্পেশাল ক্রাইটেরিয়া টেস্ট');

    final criteria = await db.getCriteriaForProtisthan(pId);

    expect(criteria, hasLength(4));
    expect(criteria.every((c) => c.isSpecial), isTrue);
    expect(criteria[0].name, 'ধার্যকৃত নিসাব');
    expect(criteria[0].specialOrder, 1);
    expect(criteria[0].isFixedTarget, isTrue);
    expect(criteria[1].name, 'আয়');
    expect(criteria[1].specialOrder, 2);
    expect(criteria[1].isFixedTarget, isFalse);
    expect(criteria[2].name, 'ব্যয়');
    expect(criteria[2].specialOrder, 3);
    expect(criteria[3].name, 'বাস্তব জমা');
    expect(criteria[3].specialOrder, 4);
    expect(criteria[3].isComputedDeposit, isTrue);
  });

  test('special criteria always sort first regardless of insertion order', () async {
    final pId = await addProtisthan('সর্টিং টেস্ট');
    // Normal criteria added after the auto-seeded special ones.
    await addCriteria(pId, 'দোকান ভাড়া');
    await addCriteria(pId, 'টোল');

    final criteria = await db.getCriteriaForProtisthan(pId);

    expect(criteria, hasLength(6));
    expect(criteria[0].isSpecial, isTrue);
    expect(criteria[1].isSpecial, isTrue);
    expect(criteria[2].isSpecial, isTrue);
    expect(criteria[3].isSpecial, isTrue);
    expect(criteria[4].name, 'টোল');
    expect(criteria[5].name, 'দোকান ভাড়া');
  });

  test('deleteCriteria throws for a special criteria (ধার্যকৃত নিসাব/আয়/ব্যয়/বাস্তব জমা cannot be deleted)', () async {
    final pId = await addProtisthan('ডিলিট প্রোটেকশন টেস্ট');
    final criteria = await db.getCriteriaForProtisthan(pId);
    final specialCriteria = criteria.firstWhere((c) => c.isSpecial);

    expect(() => db.deleteCriteria(specialCriteria.id!), throwsA(isA<StateError>()));

    // Untouched — still there after the failed delete attempt.
    expect(await db.getCriteriaForProtisthan(pId), hasLength(4));
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

  test('ধার্যকৃত নিসাব ও বাস্তব জমা are never backed by an Entry — নিসাব always comes from '
      'ward.targetAmount, বাস্তব জমা is always আয়−ব্যয়, and both feed row/grand/column totals '
      'per the আয় exclusion rule', () async {
    final pId = await addProtisthan('নিসাব কলাম টেস্ট');
    final w1 = await db.insertWard(
      Ward(
        uuid: 'w-col-1-$pId',
        protisthanId: pId,
        name: 'ওয়ার্ড ১',
        createdAt: DateTime.now().toIso8601String(),
        targetAmount: 20000,
      ),
    );
    final w2 = await db.insertWard(
      Ward(
        uuid: 'w-col-2-$pId',
        protisthanId: pId,
        name: 'ওয়ার্ড ২',
        createdAt: DateTime.now().toIso8601String(),
        targetAmount: 15000,
      ),
    );
    final criteria = await db.getCriteriaForProtisthan(pId);
    final nisab = criteria.firstWhere((c) => c.isFixedTarget);
    final income = criteria.firstWhere((c) => c.specialOrder == 2);
    final expense = criteria.firstWhere((c) => c.specialOrder == 3);
    final deposit = criteria.firstWhere((c) => c.isComputedDeposit);

    // Deliberately chosen so আয় != নিসাবের সাথে — if আয় ever leaked into
    // the row/grand total (instead of just ব্যয়+বাস্তব জমা), these numbers
    // would expose it.
    await db.saveEntry(wardId: w1, criteriaId: income.id!, month: 9, year: 2026, amount: 8000, uuidFactory: _uuid.v4());
    await db.saveEntry(wardId: w1, criteriaId: expense.id!, month: 9, year: 2026, amount: 2000, uuidFactory: _uuid.v4());
    await db.saveEntry(wardId: w2, criteriaId: income.id!, month: 9, year: 2026, amount: 4000, uuidFactory: _uuid.v4());
    await db.saveEntry(wardId: w2, criteriaId: expense.id!, month: 9, year: 2026, amount: 1000, uuidFactory: _uuid.v4());

    // No Entry was ever saved for নিসাব/বাস্তব জমা; their breakdown values
    // are always the ward's fixed target and আয়−ব্যয় respectively.
    final w1Breakdown = await db.getWardCriteriaBreakdown(w1, pId, 9, 2026);
    expect(w1Breakdown.firstWhere((e) => e.key.id == nisab.id).value, 20000);
    expect(w1Breakdown.firstWhere((e) => e.key.id == deposit.id).value, 6000); // 8000 - 2000
    final w2Breakdown = await db.getWardCriteriaBreakdown(w2, pId, 9, 2026);
    expect(w2Breakdown.firstWhere((e) => e.key.id == nisab.id).value, 15000);
    expect(w2Breakdown.firstWhere((e) => e.key.id == deposit.id).value, 3000); // 4000 - 1000

    // Protisthan-level breakdown shows the sum of both wards' targets, and
    // this Protisthan's total আয় minus total ব্যয়.
    final protisthanBreakdown = await db.getProtisthanCriteriaBreakdown(pId, 9, 2026);
    expect(protisthanBreakdown.firstWhere((e) => e.key.id == nisab.id).value, 35000);
    expect(protisthanBreakdown.firstWhere((e) => e.key.id == deposit.id).value, 9000); // 12000 - 3000
    expect(await db.getProtisthanActualDepositTotal(pId, 9, 2026), 9000);
    expect(await db.getWardExpenseTotal(pId, 9, 2026), 3000);

    // Matrix: নিসাব ও আয় excluded from every row total and the grand
    // total (নিসাব is a reference figure, আয়'s contribution flows through
    // via ব্যয়+বাস্তব জমা instead), but both still show their own column
    // total.
    final matrix = await db.getMatrixReport(pId, 9, 2026);
    expect(matrix.amountFor(w1, nisab.id!), 20000);
    expect(matrix.amountFor(w1, deposit.id!), 6000);
    expect(matrix.colTotals[nisab.id!], 35000);
    expect(matrix.colTotals[income.id!], 12000);
    expect(matrix.rowTotals[w1], 8000); // ব্যয় ২০০০ + বাস্তব জমা ৬০০০, not আয় ৮০০০ বা নিসাব ২০০০০
    expect(matrix.rowTotals[w2], 4000); // ব্যয় ১০০০ + বাস্তব জমা ৩০০০
    expect(matrix.grandTotal, 12000);

    // getWardTotal/getProtisthanTotal agree with the matrix's row/grand
    // totals (this is exactly what tripped up the earlier design).
    expect(await db.getWardTotal(w1, 9, 2026), 8000);
    expect(await db.getWardTotal(w2, 9, 2026), 4000);
    expect(await db.getProtisthanTotal(pId, 9, 2026), 12000);
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

  test('every protisthan gets an auto-created, hidden থানা ward (invisible to ward lists/counts)', () async {
    final pId = await addProtisthan('থানা ওয়ার্ড টেস্ট');
    final realWardId = await addWard(pId, 'ওয়ার্ড ১');

    final thanaWard = await db.getThanaWard(pId);
    expect(thanaWard, isNotNull);
    expect(thanaWard!.isThanaWard, isTrue);
    expect(thanaWard.name, 'থানা');

    final wards = await db.getWardsForProtisthan(pId);
    expect(wards.map((w) => w.id), [realWardId]);
    expect(wards.any((w) => w.isThanaWard), isFalse);

    final counts = await db.getWardCountsByProtisthan();
    expect(counts[pId], 1); // শুধু বাস্তব ওয়ার্ড গণনা হয়, থানা বাদে

    // ensureThanaWard is idempotent — calling again doesn't create a duplicate.
    await db.ensureThanaWard(pId);
    final thanaWardAgain = await db.getThanaWard(pId);
    expect(thanaWardAgain!.id, thanaWard.id);
  });

  test("থানার আয় (thana ward normal-খাত entries) stays separate from real wards' totals, "
      'and combines correctly in the matrix report', () async {
    final pId = await addProtisthan('থানার আয় টেস্ট');
    final cId = await addCriteria(pId, 'দোকান ভাড়া');
    final wId = await addWard(pId, 'ওয়ার্ড ১');
    final thanaWard = await db.getThanaWard(pId);

    await db.saveEntry(wardId: wId, criteriaId: cId, month: 9, year: 2026, amount: 5000, uuidFactory: _uuid.v4());
    await db.saveEntry(
      wardId: thanaWard!.id!,
      criteriaId: cId,
      month: 9,
      year: 2026,
      amount: 3000,
      uuidFactory: _uuid.v4(),
    );

    // Ward-only totals (used app-wide) never include থানার আয়.
    expect(await db.getWardTotal(wId, 9, 2026), 5000);
    expect(await db.getProtisthanTotal(pId, 9, 2026), 5000);
    final criteriaBreakdown = await db.getProtisthanCriteriaBreakdown(pId, 9, 2026);
    expect(criteriaBreakdown.firstWhere((e) => e.key.id == cId).value, 5000);

    // থানার আয় itself sums only the thana ward's entries.
    expect(await db.getThanaIncomeTotal(pId, 9, 2026), 3000);

    // Matrix: real wards unaffected, থানা row carries থানার আয় separately,
    // থানাসহ সর্বমোট combines both.
    final matrix = await db.getMatrixReport(pId, 9, 2026);
    expect(matrix.wards.map((w) => w.id), [wId]);
    expect(matrix.colTotals[cId], 5000);
    expect(matrix.grandTotal, 5000);
    expect(matrix.thanaAmountFor(cId), 3000);
    expect(matrix.thanaRowTotal, 3000);
    expect(matrix.combinedColTotals[cId], 8000);
    expect(matrix.combinedGrandTotal, 8000);
  });

  test('থানা row shows নিসাব(fixed at creation)/আয়(manual)/বাস্তব জমা(=আয়), '
      'but ব্যয় stays absent (never entered on থানার আয় পাতা)', () async {
    final pId = await db.insertProtisthan(
      Protisthan(uuid: 'p-thana-special', name: 'থানা স্পেশাল টেস্ট', createdAt: DateTime.now().toIso8601String()),
      thanaNisab: 10000,
    );
    final wId = await addWard(pId, 'ওয়ার্ড ১');
    final thanaWard = await db.getThanaWard(pId);
    final criteria = await db.getCriteriaForProtisthan(pId);
    final nisab = criteria.firstWhere((c) => c.isFixedTarget);
    final income = criteria.firstWhere((c) => c.specialOrder == 2);
    final expense = criteria.firstWhere((c) => c.specialOrder == 3);
    final deposit = criteria.firstWhere((c) => c.isComputedDeposit);

    // Real ward's own আয়/ব্যয় — unaffected by থানার আয়.
    await db.saveEntry(
      wardId: wId,
      criteriaId: income.id!,
      month: 9,
      year: 2026,
      amount: 8000,
      uuidFactory: _uuid.v4(),
    );
    await db.saveEntry(
      wardId: wId,
      criteriaId: expense.id!,
      month: 9,
      year: 2026,
      amount: 2000,
      uuidFactory: _uuid.v4(),
    );
    // থানার নিজস্ব আয় (manual, থানার আয় পাতায়)।
    await db.saveEntry(
      wardId: thanaWard!.id!,
      criteriaId: income.id!,
      month: 9,
      year: 2026,
      amount: 1500,
      uuidFactory: _uuid.v4(),
    );

    final matrix = await db.getMatrixReport(pId, 9, 2026);
    expect(matrix.thanaRow[nisab.id], 10000); // থানা তৈরির সময়ের ফিক্সড নিসাব
    expect(matrix.thanaRow[income.id], 1500); // ম্যানুয়াল আয়
    expect(matrix.thanaRow[deposit.id], 1500); // বাস্তব জমা = আয় (ব্যয় কখনো এন্ট্রি হয় না)
    expect(matrix.thanaRow.containsKey(expense.id), isFalse); // ব্যয়ের ঘর খালি
    // rowTotal exclusion rule ward-এর মতোই: নিসাব ও আয় বাদে, তাই শুধু
    // বাস্তব জমা(১৫০০) যোগ হয় (ব্যয় অনুপস্থিত = ০, normal খাত নেই)।
    expect(matrix.thanaRowTotal, 1500);
    expect(matrix.combinedGrandTotal, matrix.grandTotal + 1500);
    // Special columns' combined total picks up থানার নিজস্ব মান।
    expect(matrix.combinedColTotals[nisab.id], matrix.colTotals[nisab.id]! + 10000);
    expect(matrix.combinedColTotals[income.id], matrix.colTotals[income.id]! + 1500);
    expect(matrix.combinedColTotals[expense.id], matrix.colTotals[expense.id]); // থানা adds nothing
  });

  test('থানার নিসাব ইনপুট থানা তৈরির সময় নেওয়া হয় এবং পরে এডিট করা যায়', () async {
    final pId = await db.insertProtisthan(
      Protisthan(uuid: 'p-thana-nisab', name: 'থানা নিসাব টেস্ট', createdAt: DateTime.now().toIso8601String()),
      thanaNisab: 5000,
    );
    final thanaWard = await db.getThanaWard(pId);
    expect(thanaWard!.targetAmount, 5000);

    await db.updateThanaWardTarget(pId, 7500);
    final updated = await db.getThanaWard(pId);
    expect(updated!.targetAmount, 7500);
    // থানার নাম/id অপরিবর্তিত থাকে, শুধু নিসাব বদলায়।
    expect(updated.id, thanaWard.id);
    expect(updated.name, 'থানা');
  });

  test('getThanaActualDeposit (special-only) vs getThanaIncomeTotal (combined with normal খাত)', () async {
    final pId = await addProtisthan('থানা আয় বনাম বাস্তব জমা টেস্ট');
    final cId = await addCriteria(pId, 'দোকান ভাড়া');
    final thanaWard = await db.getThanaWard(pId);
    final criteria = await db.getCriteriaForProtisthan(pId);
    final income = criteria.firstWhere((c) => c.specialOrder == 2);

    await db.saveEntry(
      wardId: thanaWard!.id!,
      criteriaId: income.id!,
      month: 9,
      year: 2026,
      amount: 2000,
      uuidFactory: _uuid.v4(),
    );
    await db.saveEntry(wardId: thanaWard.id!, criteriaId: cId, month: 9, year: 2026, amount: 800, uuidFactory: _uuid.v4());

    // শুধু স্পেশাল আয়/বাস্তব জমা — normal খাত অন্তর্ভুক্ত নয়। রিমিট্যান্স
    // পাতার থানার নিসাব হিসাবে ব্যবহৃত।
    expect(await db.getThanaActualDeposit(pId, 9, 2026), 2000);
    // থানা রো-এর সম্পূর্ণ টোটাল — normal খাতসহ। "থানার মাসিক কালেকশন এক
    // নজরে"-র "+ থানার আয়" ধাপে ব্যবহৃত।
    expect(await db.getThanaIncomeTotal(pId, 9, 2026), 2800);
  });
}
