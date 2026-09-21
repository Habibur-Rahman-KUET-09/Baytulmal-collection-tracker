/// A Protisthan's (থানা) 4-level role-based access model. Stored in
/// Firestore at `protisthans/{uuid}/members/{authUid}` and mirrored to
/// `users/{authUid}/memberships/{protisthanUuid}` (see
/// [CloudSyncService]) so "which থানাs am I a member of" can be queried
/// without a Firestore collectionGroup index.
enum ProtisthanRole { creator, admin, collector, member }

extension ProtisthanRoleX on ProtisthanRole {
  String get label {
    switch (this) {
      case ProtisthanRole.creator:
        return 'নির্মাতা';
      case ProtisthanRole.admin:
        return 'অ্যাডমিন';
      case ProtisthanRole.collector:
        return 'কালেক্টর';
      case ProtisthanRole.member:
        return 'সদস্য';
    }
  }

  /// আয়/ব্যয়/এন্ট্রি ফর্ম পূরণ করতে পারবে কি না।
  bool get canEnterData =>
      this == ProtisthanRole.creator || this == ProtisthanRole.admin || this == ProtisthanRole.collector;

  /// ওয়ার্ড/খাত/রেমিট্যান্স-এর মতো কাঠামোগত সেটিংস বদলাতে পারবে কি না।
  bool get canManageStructure => this == ProtisthanRole.creator || this == ProtisthanRole.admin;

  /// ইউজার যোগ/বাদ/রোল পরিবর্তন করতে পারবে কি না।
  bool get canManageUsers => this == ProtisthanRole.creator || this == ProtisthanRole.admin;

  /// পুরো থানা মুছে ফেলতে পারবে কি না — শুধু নির্মাতা।
  bool get canDeleteProtisthan => this == ProtisthanRole.creator;
}

ProtisthanRole roleFromString(String value) {
  return ProtisthanRole.values.firstWhere(
    (r) => r.name == value,
    orElse: () => ProtisthanRole.member,
  );
}

/// One member of a Protisthan (থানা), as stored in Firestore.
class Membership {
  final String uid;
  final String? email;
  final String? displayName;
  final ProtisthanRole role;
  final String joinedAt;

  const Membership({
    required this.uid,
    this.email,
    this.displayName,
    required this.role,
    required this.joinedAt,
  });

  Membership copyWith({ProtisthanRole? role}) {
    return Membership(
      uid: uid,
      email: email,
      displayName: displayName,
      role: role ?? this.role,
      joinedAt: joinedAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'role': role.name,
      'joinedAt': joinedAt,
    };
  }

  factory Membership.fromFirestore(String uid, Map<String, dynamic> data) {
    return Membership(
      uid: uid,
      email: data['email'] as String?,
      displayName: data['displayName'] as String?,
      role: roleFromString(data['role'] as String? ?? 'member'),
      joinedAt: data['joinedAt'] as String? ?? '',
    );
  }
}
