class Criteria {
  final int? id;
  final String uuid;
  final int protisthanId;
  final String name;
  final String createdAt;

  /// Marks this as one of the two "special" per-month criteria (২ = আদায়,
  /// ৩ = বকেয়া) that, together with the ward's fixed [Ward.targetAmount]
  /// (special criteria ১), should satisfy আদায় + বকেয়া = নির্ধারিত
  /// লক্ষ্যমাত্রা. `null` means a normal, user-defined criteria. Otherwise
  /// behaves exactly like any other criteria (same Entry rows, same
  /// matrix/summary aggregation) — this flag only changes how it's
  /// presented (ordering, highlighting) and that it can't be deleted.
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
