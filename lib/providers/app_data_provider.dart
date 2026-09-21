import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../db/database_helper.dart';
import '../models/criteria.dart';
import '../models/entry.dart';
import '../models/membership.dart';
import '../models/protisthan.dart';
import '../models/ward.dart';
import '../services/auth_service.dart';
import '../services/cloud_sync_service.dart';

/// App-wide data access point. Holds the Protisthan list (for the home
/// screen) and exposes CRUD passthroughs to [DatabaseHelper]. Screens that
/// show a single Protisthan's detail (wards/criteria/entries) keep their
/// own local state and call [refresh] afterwards so the home screen counts
/// stay in sync.
///
/// The local SQLite database ([db]) stays the fast, always-available data
/// source every screen reads from — reports/matrix/trend code is
/// unchanged. Every write here also pushes to Firestore via
/// [CloudSyncService] (see that class for the schema), and [refresh] pulls
/// down + merges every থানা the signed-in user is a member of, so this
/// device's local cache stays in sync across devices/users. A brand-new
/// Protisthan's creator becomes its `creator` member automatically; a
/// pre-Firebase local থানা with no cloud copy yet is "claimed" (uploaded,
/// creator = whoever is signed in) the first time it's seen after sign-in.
class AppDataProvider extends ChangeNotifier {
  final DatabaseHelper db = DatabaseHelper.instance;
  final CloudSyncService cloud = CloudSyncService.instance;
  static const _uuid = Uuid();

  List<Protisthan> protisthanList = [];
  Map<int, int> wardCounts = {};
  Map<int, int> criteriaCounts = {};

  /// protisthan uuid -> my role in it — only populated for signed-in users.
  /// Screens gating an action by role should read this via
  /// `provider.myRoles[protisthan.uuid]`.
  Map<String, ProtisthanRole> myRoles = {};
  bool isLoading = false;

  String newUuid() => _uuid.v4();
  String nowIso() => DateTime.now().toIso8601String();
  String? get _uid => AuthService.instance.currentUser?.uid;

  ProtisthanRole? roleFor(Protisthan p) => myRoles[p.uuid];

  Future<void> refresh() async {
    isLoading = true;
    notifyListeners();

    final uid = _uid;
    if (uid != null) {
      await cloud.upsertCurrentUserProfile();
      await _claimUnclaimedLocalProtisthans(uid);
      myRoles = await cloud.myMemberships();
      for (final protisthanUuid in myRoles.keys) {
        await cloud.pullAndMergeProtisthan(protisthanUuid, db);
      }
      // Local থানা this device once had but is no longer a member of (e.g.
      // removed, or deleted by someone else) — drop it locally too.
      final localAll = await db.getAllProtisthan();
      for (final p in localAll) {
        if (!myRoles.containsKey(p.uuid)) {
          await db.deleteProtisthan(p.id!);
        }
      }
    } else {
      myRoles = {};
    }

    final all = await db.getAllProtisthan();
    protisthanList = uid == null ? all : all.where((p) => myRoles.containsKey(p.uuid)).toList();
    wardCounts = await db.getWardCountsByProtisthan();
    criteriaCounts = await db.getCriteriaCountsByProtisthan();
    isLoading = false;
    notifyListeners();
  }

  /// Pre-Firebase local data (or a থানা created while offline that never
  /// got a chance to push) has no Firestore doc yet — the first user to
  /// sign in and see it becomes its creator. Idempotent: a থানা already in
  /// Firestore (whether under this uid or claimed already) is left alone.
  Future<void> _claimUnclaimedLocalProtisthans(String uid) async {
    final user = AuthService.instance.currentUser;
    final localProtisthans = await db.getAllProtisthan();
    for (final p in localProtisthans) {
      final myRole = await cloud.getMyRole(p.uuid);
      if (myRole != null) continue;
      final existsRemotely = await cloud.protisthanExists(p.uuid);
      if (existsRemotely) continue; // belongs to someone else — not ours to claim
      final criteria = await db.getCriteriaForProtisthan(p.id!);
      final wards = await db.getWardsForProtisthan(p.id!);
      final thanaWard = await db.getThanaWard(p.id!);
      final allWards = [...wards, ?thanaWard];
      final entries = <Entry>[];
      for (final w in allWards) {
        final wardEntries = await db.getEntriesRawForWard(w.id!);
        entries.addAll(wardEntries);
      }
      final remittances = await db.getRemittancesForProtisthan(p.id!);
      await cloud.pushFullProtisthanBundle(
        p,
        wards: allWards,
        criteria: criteria,
        entries: entries,
        remittances: remittances,
        uid: uid,
        email: user?.email,
        displayName: user?.displayName,
      );
    }
  }

  Future<void> addProtisthan(String name, {double thanaNisab = 0}) async {
    final uuid = newUuid();
    final id = await db.insertProtisthan(
      Protisthan(uuid: uuid, name: name, createdAt: nowIso()),
      thanaNisab: thanaNisab,
    );
    await _pushNewProtisthan(id);
    await refresh();
  }

  Future<void> _pushNewProtisthan(int localId) async {
    final uid = _uid;
    if (uid == null) return;
    final user = AuthService.instance.currentUser;
    final p = await db.getProtisthan(localId);
    if (p == null) return;
    final criteria = await db.getCriteriaForProtisthan(localId);
    final thanaWard = await db.getThanaWard(localId);
    final wards = [?thanaWard];
    await cloud.pushFullProtisthanBundle(
      p,
      wards: wards,
      criteria: criteria,
      entries: const [],
      remittances: const [],
      uid: uid,
      email: user?.email,
      displayName: user?.displayName,
    );
  }

  Future<void> renameProtisthan(Protisthan p, String newName, {double? thanaNisab}) async {
    await db.updateProtisthan(p.copyWith(name: newName));
    if (thanaNisab != null) {
      await db.updateThanaWardTarget(p.id!, thanaNisab);
    }
    if (_uid != null) {
      await cloud.pushProtisthan(p.copyWith(name: newName));
      if (thanaNisab != null) {
        final thanaWard = await db.getThanaWard(p.id!);
        if (thanaWard != null) await cloud.pushWard(p.uuid, thanaWard);
      }
    }
    await refresh();
  }

  Future<void> deleteProtisthan(int id) async {
    final p = await db.getProtisthan(id);
    await db.deleteProtisthan(id);
    if (p != null && _uid != null) {
      await cloud.deleteProtisthanCloud(p.uuid);
    }
    await refresh();
  }

  Future<int> addCriteria(int protisthanId, String name) async {
    final id = await db.insertCriteria(
      Criteria(uuid: newUuid(), protisthanId: protisthanId, name: name, createdAt: nowIso()),
    );
    if (_uid != null) {
      final p = await db.getProtisthan(protisthanId);
      final c = await db.getCriteriaById(id);
      if (p != null && c != null) await cloud.pushCriteria(p.uuid, c);
    }
    await refresh();
    return id;
  }

  Future<void> renameCriteria(Criteria c, String newName) async {
    final updated = c.copyWith(name: newName);
    await db.updateCriteria(updated);
    if (_uid != null) {
      final p = await db.getProtisthan(c.protisthanId);
      if (p != null) await cloud.pushCriteria(p.uuid, updated);
    }
    await refresh();
  }

  Future<void> deleteCriteria(int id) async {
    final c = await db.getCriteriaById(id);
    await db.deleteCriteria(id);
    if (c != null && _uid != null) {
      final p = await db.getProtisthan(c.protisthanId);
      if (p != null) await cloud.deleteCriteriaCloud(p.uuid, c.uuid);
    }
    await refresh();
  }

  Future<int> addWard(int protisthanId, String name, {double targetAmount = 0}) async {
    final id = await db.insertWard(
      Ward(
        uuid: newUuid(),
        protisthanId: protisthanId,
        name: name,
        createdAt: nowIso(),
        targetAmount: targetAmount,
      ),
    );
    if (_uid != null) {
      final p = await db.getProtisthan(protisthanId);
      final w = await db.getWard(id);
      if (p != null && w != null) await cloud.pushWard(p.uuid, w);
    }
    await refresh();
    return id;
  }

  Future<void> updateWardInfo(Ward w, {required String name, required double targetAmount}) async {
    final updated = w.copyWith(name: name, targetAmount: targetAmount);
    await db.updateWard(updated);
    if (_uid != null) {
      final p = await db.getProtisthan(w.protisthanId);
      if (p != null) await cloud.pushWard(p.uuid, updated);
    }
    await refresh();
  }

  Future<void> deleteWard(int id) async {
    final w = await db.getWard(id);
    await db.deleteWard(id);
    if (w != null && _uid != null) {
      final p = await db.getProtisthan(w.protisthanId);
      if (p != null) await cloud.deleteWardCloud(p.uuid, w.uuid);
    }
    await refresh();
  }

  /// Saves (or, if [amount] is null, deletes) a single entry and mirrors
  /// the change to Firestore. [protisthan]/[ward]/[criteria] are the full
  /// model objects (not just ids) because their `uuid`s are the Firestore
  /// doc keys — every entry screen already has these loaded.
  Future<void> saveEntry({
    required Protisthan protisthan,
    required Ward ward,
    required Criteria criteria,
    required int month,
    required int year,
    required double? amount,
  }) async {
    final result = await db.saveEntry(
      wardId: ward.id!,
      criteriaId: criteria.id!,
      month: month,
      year: year,
      amount: amount,
      uuidFactory: newUuid(),
    );
    if (result == null || _uid == null) return;
    if (result.deleted) {
      await cloud.deleteEntryCloud(protisthan.uuid, result.uuid);
    } else {
      await cloud.pushEntry(
        protisthan.uuid,
        entryUuid: result.uuid,
        wardUuid: ward.uuid,
        criteriaUuid: criteria.uuid,
        month: month,
        year: year,
        amount: amount!,
        updatedAt: nowIso(),
      );
    }
  }

  Future<void> saveRemittance({
    required Protisthan protisthan,
    required int month,
    required int year,
    required double expenseAmount,
    required double actualDepositAmount,
  }) async {
    await db.saveRemittance(
      protisthanId: protisthan.id!,
      month: month,
      year: year,
      expenseAmount: expenseAmount,
      actualDepositAmount: actualDepositAmount,
    );
    if (_uid == null) return;
    final r = await db.getRemittance(protisthan.id!, month, year);
    if (r != null) await cloud.pushRemittance(protisthan.uuid, r);
  }
}
