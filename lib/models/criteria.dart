class Criteria {
  final int? id;
  final String uuid;
  final int protisthanId;
  final String name;
  final String createdAt;

  /// Marks this as one of the three "special" criteria that together
  /// satisfy লক্ষ্যমাত্রা − খরচ = জমা:
  ///   ১ = লক্ষ্যমাত্রা — not backed by an Entry at all; its value is
  ///       always the ward's fixed [Ward.targetAmount], fixed at ward
  ///       creation and never re-typed per month. Excluded from every
  ///       row/column/grand total (it's a reference figure, not money
  ///       actually collected) — see [DatabaseHelper.getMatrixReport].
  ///   ২ = খরচ — an ordinary per-month Entry.
  ///   ৩ = সিনিয়র ম্যানেজমেন্ট এ জমা — an ordinary per-month Entry.
  /// `null` means a normal, user-defined criteria. ২ and ৩ otherwise behave
  /// exactly like any other criteria (same Entry rows, same matrix/summary
  /// aggregation) — this flag only changes how they're presented (ordering,
  /// highlighting) and that they can't be deleted.
  final int? specialOrder;

  const Criteria({
    this.id,
    required this.uuid,
    required this.protisthanId,
    required this.name,
    required this.createdAt,
    this.specialOrder,
  });

  bool get isSpecial => specialOrder != null;

  /// লক্ষ্যমাত্রা — the one special criteria with no Entry of its own;
  /// its value always comes from [Ward.targetAmount] instead.
  bool get isFixedTarget => specialOrder == 1;

  Criteria copyWith({
    int? id,
    String? uuid,
    int? protisthanId,
    String? name,
    String? createdAt,
    int? specialOrder,
  }) {
    return Criteria(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      protisthanId: protisthanId ?? this.protisthanId,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      specialOrder: specialOrder ?? this.specialOrder,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uuid': uuid,
      'protisthan_id': protisthanId,
      'name': name,
      'created_at': createdAt,
      'special_order': specialOrder,
    };
  }

  factory Criteria.fromMap(Map<String, dynamic> map) {
    return Criteria(
      id: map['id'] as int?,
      uuid: map['uuid'] as String,
      protisthanId: map['protisthan_id'] as int,
      name: map['name'] as String,
      createdAt: map['created_at'] as String,
      specialOrder: map['special_order'] as int?,
    );
  }
}
