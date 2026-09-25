import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:baytulmal_collection_tracker/db/database_helper.dart';

/// Runs in its own file (so its own process and [DatabaseHelper] singleton):
/// writes a version 5 database, then lets [DatabaseHelper] open and upgrade it.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('upgrading to v6 keeps the alphabetical order lists showed before', () async {
    // Its own directory: other test files use the default one in parallel.
    final dir = await Directory.systemTemp.createTemp('sort_order_migration');
    addTearDown(() => dir.delete(recursive: true));
    await databaseFactory.setDatabasesPath(dir.path);
    final path = join(dir.path, 'baytulmal_collection_tracker.db');

    final old = await databaseFactory.openDatabase(path, options: OpenDatabaseOptions(
      version: 5,
      onCreate: (db, _) async {
        await db.execute('CREATE TABLE protisthan (id INTEGER PRIMARY KEY AUTOINCREMENT, uuid TEXT NOT NULL UNIQUE, '
            'name TEXT NOT NULL, created_at TEXT NOT NULL)');
        await db.execute('CREATE TABLE criteria (id INTEGER PRIMARY KEY AUTOINCREMENT, uuid TEXT NOT NULL UNIQUE, '
            'protisthan_id INTEGER NOT NULL, name TEXT NOT NULL, created_at TEXT NOT NULL, special_order INTEGER)');
        await db.execute('CREATE TABLE ward (id INTEGER PRIMARY KEY AUTOINCREMENT, uuid TEXT NOT NULL UNIQUE, '
            'protisthan_id INTEGER NOT NULL, name TEXT NOT NULL, created_at TEXT NOT NULL, '
            'target_amount REAL NOT NULL DEFAULT 0, is_thana_ward INTEGER NOT NULL DEFAULT 0)');
        await db.execute('CREATE TABLE entry (id INTEGER PRIMARY KEY AUTOINCREMENT, uuid TEXT NOT NULL UNIQUE, '
            'ward_id INTEGER NOT NULL, criteria_id INTEGER NOT NULL, month INTEGER NOT NULL, year INTEGER NOT NULL, '
            'amount REAL NOT NULL DEFAULT 0, updated_at TEXT NOT NULL)');
        await db.execute('CREATE TABLE remittance (id INTEGER PRIMARY KEY AUTOINCREMENT, uuid TEXT NOT NULL UNIQUE, '
            'protisthan_id INTEGER NOT NULL, month INTEGER NOT NULL, year INTEGER NOT NULL, '
            'expense_amount REAL NOT NULL DEFAULT 0, actual_deposit_amount REAL NOT NULL DEFAULT 0, '
            'updated_at TEXT NOT NULL)');
      },
    ));
    const now = '2026-09-01T00:00:00';
    for (final (i, name) in ['খুলনা', 'ঢাকা', 'কুমিল্লা'].indexed) {
      await old.insert('protisthan', {'uuid': 'p$i', 'name': name, 'created_at': now});
    }
    for (final (i, name) in ['৩ নং', '১ নং', '২ নং'].indexed) {
      await old.insert('ward', {'uuid': 'w$i', 'protisthan_id': 1, 'name': name, 'created_at': now});
    }
    await old.insert('ward', {'uuid': 'thana', 'protisthan_id': 1, 'name': 'থানা', 'created_at': now, 'is_thana_ward': 1});
    await old.insert('criteria', {'uuid': 's1', 'protisthan_id': 1, 'name': 'আয়', 'created_at': now, 'special_order': 2});
    for (final (i, name) in ['যাকাত', 'এককালীন'].indexed) {
      await old.insert('criteria', {'uuid': 'c$i', 'protisthan_id': 1, 'name': name, 'created_at': now});
    }
    await old.close();

    final db = DatabaseHelper.instance;
    final protisthans = await db.getAllProtisthan();
    expect(protisthans.map((p) => p.name), ['কুমিল্লা', 'খুলনা', 'ঢাকা']);
    expect(protisthans.map((p) => p.sortOrder), [0, 1, 2]);

    final wards = await db.getWardsForProtisthan(1);
    expect(wards.map((w) => w.name), ['১ নং', '২ নং', '৩ নং']);

    final criteria = await db.getCriteriaForProtisthan(1);
    expect(criteria.first.name, 'আয়');
    expect(criteria.where((c) => !c.isSpecial).map((c) => c.name), ['এককালীন', 'যাকাত']);

    // New rows go after the migrated ones.
    await db.saveSortOrder('ward', [wards[2].id!, wards[0].id!, wards[1].id!]);
    expect((await db.getWardsForProtisthan(1)).map((w) => w.name), ['৩ নং', '১ নং', '২ নং']);
  });
}
