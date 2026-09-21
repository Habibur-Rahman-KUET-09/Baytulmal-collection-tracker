import 'package:cloud_firestore/cloud_firestore.dart';

import '../db/database_helper.dart';
import '../models/criteria.dart';
import '../models/entry.dart';
import '../models/membership.dart';
import '../models/protisthan.dart';
import '../models/remittance.dart';
import '../models/ward.dart';
import 'auth_service.dart';

/// Bridges the local SQLite cache ([DatabaseHelper]) with Firestore.
///
/// Firestore is the source of truth for multi-device/multi-user data; the
/// local SQLite database stays exactly as it always was — every screen's
/// reports/matrix/trend computations keep reading it unchanged. Every
/// table already carries a `uuid` (FR-7.3), so that's used as the Firestore
/// document id, letting rows be matched across devices without knowing the
/// other device's local autoincrement `id`.
///
/// Firestore schema:
/// ```
/// users/{authUid}                          — {email, displayName}
///   memberships/{protisthanUuid}            — {role, joinedAt} (reverse index)
/// protisthans/{protisthanUuid}              — {name, createdAt}
///   members/{authUid}                       — {email, displayName, role, joinedAt}
///   wards/{wardUuid}                        — {name, createdAt, targetAmount, isThanaWard}
///   criteria/{criteriaUuid}                 — {name, createdAt, specialOrder}
///   entries/{entryUuid}                     — {wardUuid, criteriaUuid, month, year, amount, updatedAt}
///   remittances/{remittanceUuid}            — {month, year, expenseAmount, actualDepositAmount, updatedAt}
/// ```
class CloudSyncService {
  CloudSyncService._();
  static final CloudSyncService instance = CloudSyncService._();

  final FirebaseFirestore _fs = FirebaseFirestore.instance;
  static const int _batchChunkSize = 400; // Firestore batch limit is 500

  CollectionReference<Map<String, dynamic>> get _protisthans => _fs.collection('protisthans');
  CollectionReference<Map<String, dynamic>> get _users => _fs.collection('users');

  String? get _uid => AuthService.instance.currentUser?.uid;

  // -----------------------------------------------------------------------
  // User profile (needed so members can be looked up by email — Firestore
  // has no client-callable "find auth user by email"; a `users` collection
  // populated at sign-in is the standard workaround for a backend-less app)
  // -----------------------------------------------------------------------

  Future<void> upsertCurrentUserProfile() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;
    await _users.doc(user.uid).set({
      'email': user.email?.trim().toLowerCase(),
      'displayName': user.displayName,
    }, SetOptions(merge: true));
  }

  /// Null if no registered user has this email — they must sign in at
  /// least once before they can be added to a থানা.
  Future<String?> findUidByEmail(String email) async {
    final q = await _users.where('email', isEqualTo: email.trim().toLowerCase()).limit(1).get();
    if (q.docs.isEmpty) return null;
    return q.docs.first.id;
  }

  // -----------------------------------------------------------------------
  // Membership
  // -----------------------------------------------------------------------

  Future<void> addOrUpdateMember(
    String protisthanUuid,
    String uid,
    ProtisthanRole role, {
    String? email,
    String? displayName,
  }) async {
    final joinedAt = DateTime.now().toIso8601String();
    final batch = _fs.batch();
    batch.set(
      _protisthans.doc(protisthanUuid).collection('members').doc(uid),
      {'email': email, 'displayName': displayName, 'role': role.name, 'joinedAt': joinedAt},
      SetOptions(merge: true),
    );
    batch.set(
      _users.doc(uid).collection('memberships').doc(protisthanUuid),
      {'role': role.name, 'joinedAt': joinedAt},
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  Future<void> removeMember(String protisthanUuid, String uid) async {
    final batch = _fs.batch();
    batch.delete(_protisthans.doc(protisthanUuid).collection('members').doc(uid));
    batch.delete(_users.doc(uid).collection('memberships').doc(protisthanUuid));
    await batch.commit();
  }

  Future<List<Membership>> getMembers(String protisthanUuid) async {
    final snap = await _protisthans.doc(protisthanUuid).collection('members').get();
    return snap.docs.map((d) => Membership.fromFirestore(d.id, d.data())).toList();
  }

  Future<ProtisthanRole?> getMyRole(String protisthanUuid) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final doc = await _protisthans.doc(protisthanUuid).collection('members').doc(uid).get();
      if (!doc.exists) return null;
      return roleFromString(doc.data()!['role'] as String? ?? 'member');
    } on FirebaseException catch (e) {
      // Rules deny reading another user's membership doc — treat as "not
      // a member" rather than crashing the caller (see firestore.rules).
      if (e.code == 'permission-denied') return null;
      rethrow;
    }
  }

  /// protisthanUuid -> my role, for every থানা the signed-in user belongs to.
  Future<Map<String, ProtisthanRole>> myMemberships() async {
    final uid = _uid;
    if (uid == null) return {};
    final snap = await _users.doc(uid).collection('memberships').get();
    return {for (final d in snap.docs) d.id: roleFromString(d.data()['role'] as String? ?? 'member')};
  }

  /// থানা names where the signed-in user is `creator` — account deletion
  /// is blocked while this is non-empty (see AccountScreen): deleting the
  /// account would leave that থানা with no one able to manage roles or
  /// delete it.
  Future<List<String>> myCreatorProtisthanNames() async {
    final memberships = await myMemberships();
    final names = <String>[];
    for (final entry in memberships.entries) {
      if (entry.value != ProtisthanRole.creator) continue;
      final doc = await _protisthans.doc(entry.key).get();
      names.add(doc.data()?['name'] as String? ?? entry.key);
    }
    return names;
  }

  /// Removes the signed-in user from every থানা they belong to and deletes
  /// their `users/{uid}` profile — the Firestore-side cleanup right before
  /// deleting their Firebase Auth account (see AuthService.deleteAccount).
  /// Callers must first confirm [myCreatorProtisthanNames] is empty.
  Future<void> deleteOwnAccountData() async {
    final uid = _uid;
    if (uid == null) return;
    final memberships = await myMemberships();
    for (final protisthanUuid in memberships.keys) {
      await removeMember(protisthanUuid, uid);
    }
    await _users.doc(uid).delete();
  }

  Future<bool> protisthanExists(String protisthanUuid) async {
    try {
      final doc = await _protisthans.doc(protisthanUuid).get();
      return doc.exists;
    } on FirebaseException catch (e) {
      // Rules deny reading a থানা that exists under someone else and
      // this user isn't a member of — safest reading is "yes, it exists
      // (just not ours to claim)" rather than crashing the caller.
      if (e.code == 'permission-denied') return true;
      rethrow;
    }
  }

  // -----------------------------------------------------------------------
  // Push (local write -> Firestore)
  // -----------------------------------------------------------------------

  /// [ownerUid] should only be passed the very first time a থানা is pushed
  /// (brand-new creation or claiming pre-Firebase local data) — it's the
  /// one thing `firestore.rules` trusts to let that same user bootstrap
  /// their own `creator` membership doc right after. Renaming an existing
  /// থানা must omit it so the merge leaves the stored `ownerUid` untouched.
  Future<void> pushProtisthan(Protisthan p, {String? ownerUid}) async {
    final data = <String, dynamic>{'name': p.name, 'createdAt': p.createdAt};
    if (ownerUid != null) data['ownerUid'] = ownerUid;
    await _protisthans.doc(p.uuid).set(data, SetOptions(merge: true));
  }

  Future<void> deleteProtisthanCloud(String protisthanUuid) async {
    final ref = _protisthans.doc(protisthanUuid);
    final members = await ref.collection('members').get();
    final batch = _fs.batch();
    for (final m in members.docs) {
      batch.delete(m.reference);
      batch.delete(_users.doc(m.id).collection('memberships').doc(protisthanUuid));
    }
    batch.delete(ref);
    await batch.commit();
    await _deleteAllDocs(ref.collection('wards'));
    await _deleteAllDocs(ref.collection('criteria'));
    await _deleteAllDocs(ref.collection('entries'));
    await _deleteAllDocs(ref.collection('remittances'));
  }

  Future<void> _deleteAllDocs(CollectionReference<Map<String, dynamic>> ref) async {
    final snap = await ref.get();
    for (var i = 0; i < snap.docs.length; i += _batchChunkSize) {
      final batch = _fs.batch();
      for (final d in snap.docs.skip(i).take(_batchChunkSize)) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }
  }

  Future<void> pushWard(String protisthanUuid, Ward w) async {
    await _protisthans.doc(protisthanUuid).collection('wards').doc(w.uuid).set({
      'name': w.name,
      'createdAt': w.createdAt,
      'targetAmount': w.targetAmount,
      'isThanaWard': w.isThanaWard,
    });
  }

  Future<void> deleteWardCloud(String protisthanUuid, String wardUuid) async {
    final ref = _protisthans.doc(protisthanUuid);
    await ref.collection('wards').doc(wardUuid).delete();
    final entries = await ref.collection('entries').where('wardUuid', isEqualTo: wardUuid).get();
    for (var i = 0; i < entries.docs.length; i += _batchChunkSize) {
      final batch = _fs.batch();
      for (final d in entries.docs.skip(i).take(_batchChunkSize)) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }
  }

  Future<void> pushCriteria(String protisthanUuid, Criteria c) async {
    await _protisthans.doc(protisthanUuid).collection('criteria').doc(c.uuid).set({
      'name': c.name,
      'createdAt': c.createdAt,
      'specialOrder': c.specialOrder,
    });
  }

  Future<void> deleteCriteriaCloud(String protisthanUuid, String criteriaUuid) async {
    final ref = _protisthans.doc(protisthanUuid);
    await ref.collection('criteria').doc(criteriaUuid).delete();
    final entries = await ref.collection('entries').where('criteriaUuid', isEqualTo: criteriaUuid).get();
    for (var i = 0; i < entries.docs.length; i += _batchChunkSize) {
      final batch = _fs.batch();
      for (final d in entries.docs.skip(i).take(_batchChunkSize)) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }
  }

  Future<void> pushEntry(
    String protisthanUuid, {
    required String entryUuid,
    required String wardUuid,
    required String criteriaUuid,
    required int month,
    required int year,
    required double amount,
    required String updatedAt,
  }) async {
    await _protisthans.doc(protisthanUuid).collection('entries').doc(entryUuid).set({
      'wardUuid': wardUuid,
      'criteriaUuid': criteriaUuid,
      'month': month,
      'year': year,
      'amount': amount,
      'updatedAt': updatedAt,
    });
  }

  Future<void> deleteEntryCloud(String protisthanUuid, String entryUuid) async {
    await _protisthans.doc(protisthanUuid).collection('entries').doc(entryUuid).delete();
  }

  Future<void> pushRemittance(String protisthanUuid, Remittance r) async {
    await _protisthans.doc(protisthanUuid).collection('remittances').doc(r.uuid).set({
      'month': r.month,
      'year': r.year,
      'expenseAmount': r.expenseAmount,
      'actualDepositAmount': r.actualDepositAmount,
      'updatedAt': r.updatedAt,
    });
  }

  /// Pushes a whole locally-created থানা (with its already-seeded special
  /// criteria + hidden থানা ward) up to Firestore and makes [uid] its
  /// creator — used both for brand-new থানা creation and for claiming
  /// pre-Firebase local data the first time its owner signs in.
  ///
  /// The creator membership is written FIRST, before any ward/criteria/
  /// entry/remittance doc — `firestore.rules` only allows writing those
  /// once a `members/{uid}` doc for this থানা exists, so this order is
  /// required, not just a nicety.
  Future<void> pushFullProtisthanBundle(
    Protisthan p, {
    required List<Ward> wards,
    required List<Criteria> criteria,
    required List<Entry> entries,
    required List<Remittance> remittances,
    required String uid,
    String? email,
    String? displayName,
  }) async {
    await pushProtisthan(p, ownerUid: uid);
    await addOrUpdateMember(p.uuid, uid, ProtisthanRole.creator, email: email, displayName: displayName);
    for (final w in wards) {
      await pushWard(p.uuid, w);
    }
    for (final c in criteria) {
      await pushCriteria(p.uuid, c);
    }
    final wardUuidByLocalId = {for (final w in wards) w.id!: w.uuid};
    final criteriaUuidByLocalId = {for (final c in criteria) c.id!: c.uuid};
    for (final e in entries) {
      final wardUuid = wardUuidByLocalId[e.wardId];
      final criteriaUuid = criteriaUuidByLocalId[e.criteriaId];
      if (wardUuid == null || criteriaUuid == null) continue;
      await pushEntry(
        p.uuid,
        entryUuid: e.uuid,
        wardUuid: wardUuid,
        criteriaUuid: criteriaUuid,
        month: e.month,
        year: e.year,
        amount: e.amount,
        updatedAt: e.updatedAt,
      );
    }
    for (final r in remittances) {
      await pushRemittance(p.uuid, r);
    }
  }

  // -----------------------------------------------------------------------
  // Pull (Firestore -> local SQLite merge)
  // -----------------------------------------------------------------------

  /// Fetches this থানা's full bundle from Firestore and merges it into the
  /// local SQLite cache by `uuid`, resolving cloud uuid references to local
  /// int foreign keys, and pruning local rows that were deleted remotely.
  Future<void> pullAndMergeProtisthan(String protisthanUuid, DatabaseHelper db) async {
    final pDoc = await _protisthans.doc(protisthanUuid).get();
    if (!pDoc.exists) return;
    final pData = pDoc.data()!;
    await db.upsertRawByUuid('protisthan', {
      'uuid': protisthanUuid,
      'name': pData['name'] as String? ?? '',
      'created_at': pData['createdAt'] as String? ?? DateTime.now().toIso8601String(),
    });
    final localProtisthanId = await db.getLocalIdByUuid('protisthan', protisthanUuid);
    if (localProtisthanId == null) return;

    final ref = _protisthans.doc(protisthanUuid);

    final criteriaSnap = await ref.collection('criteria').get();
    final criteriaKeep = <String>{};
    for (final d in criteriaSnap.docs) {
      criteriaKeep.add(d.id);
      final data = d.data();
      await db.upsertRawByUuid('criteria', {
        'uuid': d.id,
        'protisthan_id': localProtisthanId,
        'name': data['name'] as String? ?? '',
        'created_at': data['createdAt'] as String? ?? DateTime.now().toIso8601String(),
        'special_order': data['specialOrder'] as int?,
      });
    }
    await db.pruneNotInUuids('criteria', 'protisthan_id', localProtisthanId, criteriaKeep);

    final wardSnap = await ref.collection('wards').get();
    final wardKeep = <String>{};
    for (final d in wardSnap.docs) {
      wardKeep.add(d.id);
      final data = d.data();
      await db.upsertRawByUuid('ward', {
        'uuid': d.id,
        'protisthan_id': localProtisthanId,
        'name': data['name'] as String? ?? '',
        'created_at': data['createdAt'] as String? ?? DateTime.now().toIso8601String(),
        'target_amount': (data['targetAmount'] as num?)?.toDouble() ?? 0,
        'is_thana_ward': (data['isThanaWard'] as bool? ?? false) ? 1 : 0,
      });
    }
    await db.pruneNotInUuids('ward', 'protisthan_id', localProtisthanId, wardKeep);

    // uuid -> local id maps, needed to resolve entries' foreign keys.
    final wardLocalIds = <String, int>{};
    for (final uuid in wardKeep) {
      final id = await db.getLocalIdByUuid('ward', uuid);
      if (id != null) wardLocalIds[uuid] = id;
    }
    final criteriaLocalIds = <String, int>{};
    for (final uuid in criteriaKeep) {
      final id = await db.getLocalIdByUuid('criteria', uuid);
      if (id != null) criteriaLocalIds[uuid] = id;
    }

    final entrySnap = await ref.collection('entries').get();
    final entryKeepByWard = <int, Set<String>>{};
    for (final d in entrySnap.docs) {
      final data = d.data();
      final wardUuid = data['wardUuid'] as String?;
      final criteriaUuid = data['criteriaUuid'] as String?;
      final wardLocalId = wardLocalIds[wardUuid];
      final criteriaLocalId = criteriaLocalIds[criteriaUuid];
      if (wardLocalId == null || criteriaLocalId == null) continue; // dangling ref, skip
      entryKeepByWard.putIfAbsent(wardLocalId, () => {}).add(d.id);
      await db.upsertRawByUuid('entry', {
        'uuid': d.id,
        'ward_id': wardLocalId,
        'criteria_id': criteriaLocalId,
        'month': data['month'] as int,
        'year': data['year'] as int,
        'amount': (data['amount'] as num?)?.toDouble() ?? 0,
        'updated_at': data['updatedAt'] as String? ?? DateTime.now().toIso8601String(),
      });
    }
    for (final wardLocalId in wardLocalIds.values) {
      await db.pruneNotInUuids('entry', 'ward_id', wardLocalId, entryKeepByWard[wardLocalId] ?? {});
    }

    final remittanceSnap = await ref.collection('remittances').get();
    final remittanceKeep = <String>{};
    for (final d in remittanceSnap.docs) {
      remittanceKeep.add(d.id);
      final data = d.data();
      await db.upsertRawByUuid('remittance', {
        'uuid': d.id,
        'protisthan_id': localProtisthanId,
        'month': data['month'] as int,
        'year': data['year'] as int,
        'expense_amount': (data['expenseAmount'] as num?)?.toDouble() ?? 0,
        'actual_deposit_amount': (data['actualDepositAmount'] as num?)?.toDouble() ?? 0,
        'updated_at': data['updatedAt'] as String? ?? DateTime.now().toIso8601String(),
      });
    }
    await db.pruneNotInUuids('remittance', 'protisthan_id', localProtisthanId, remittanceKeep);
  }

  Future<void> deleteLocalProtisthan(String protisthanUuid, DatabaseHelper db) async {
    final localId = await db.getLocalIdByUuid('protisthan', protisthanUuid);
    if (localId != null) {
      await db.deleteProtisthan(localId);
    }
  }
}
