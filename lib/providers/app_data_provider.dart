import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../db/database_helper.dart';
import '../models/criteria.dart';
import '../models/protisthan.dart';
import '../models/ward.dart';

/// App-wide data access point. Holds the Protisthan list (for the home
/// screen) and exposes CRUD passthroughs to [DatabaseHelper]. Screens that
/// show a single Protisthan's detail (wards/criteria/entries) keep their
/// own local state and call [refresh] afterwards so the home screen counts
/// stay in sync.
class AppDataProvider extends ChangeNotifier {
  final DatabaseHelper db = DatabaseHelper.instance;
  static const _uuid = Uuid();

  List<Protisthan> protisthanList = [];
  Map<int, int> wardCounts = {};
  Map<int, int> criteriaCounts = {};
  bool isLoading = false;

  String newUuid() => _uuid.v4();
  String nowIso() => DateTime.now().toIso8601String();

  Future<void> refresh() async {
    isLoading = true;
    notifyListeners();
    protisthanList = await db.getAllProtisthan();
    wardCounts = await db.getWardCountsByProtisthan();
    criteriaCounts = await db.getCriteriaCountsByProtisthan();
    isLoading = false;
    notifyListeners();
  }

  Future<void> addProtisthan(String name) async {
    await db.insertProtisthan(Protisthan(uuid: newUuid(), name: name, createdAt: nowIso()));
    await refresh();
  }

  Future<void> renameProtisthan(Protisthan p, String newName) async {
    await db.updateProtisthan(p.copyWith(name: newName));
    await refresh();
  }

  Future<void> deleteProtisthan(int id) async {
    await db.deleteProtisthan(id);
    await refresh();
  }

  Future<int> addCriteria(int protisthanId, String name) async {
    final id = await db.insertCriteria(
      Criteria(uuid: newUuid(), protisthanId: protisthanId, name: name, createdAt: nowIso()),
    );
    await refresh();
    return id;
  }

  Future<void> renameCriteria(Criteria c, String newName) async {
    await db.updateCriteria(c.copyWith(name: newName));
    await refresh();
  }

  Future<void> deleteCriteria(int id) async {
    await db.deleteCriteria(id);
    await refresh();
  }

  Future<int> addWard(int protisthanId, String name) async {
    final id = await db.insertWard(
      Ward(uuid: newUuid(), protisthanId: protisthanId, name: name, createdAt: nowIso()),
    );
    await refresh();
    return id;
  }

  Future<void> renameWard(Ward w, String newName) async {
    await db.updateWard(w.copyWith(name: newName));
    await refresh();
  }

  Future<void> deleteWard(int id) async {
    await db.deleteWard(id);
    await refresh();
  }
}
