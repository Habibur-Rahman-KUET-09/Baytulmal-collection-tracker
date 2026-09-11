class Ward {
  final int? id;
  final String uuid;
  final int protisthanId;
  final String name;
  final String createdAt;

  /// Special criteria #1 (নির্ধারিত লক্ষ্যমাত্রা): a fixed BDT value set once
  /// when the ward is created (editable later), not a per-month Entry. Kept
  /// out of every collection total (ward/protisthan/matrix sums) — it's a
  /// reference target, not money actually collected.
  final double targetAmount;

  const Ward({
    this.id,
    required this.uuid,
    required this.protisthanId,
    required this.name,
    required this.createdAt,
    this.targetAmount = 0,
  });

  Ward copyWith({
    int? id,
    String? uuid,
    int? protisthanId,
    String? name,
    String? createdAt,
    double? targetAmount,
  }) {
    return Ward(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      protisthanId: protisthanId ?? this.protisthanId,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      targetAmount: targetAmount ?? this.targetAmount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uuid': uuid,
      'protisthan_id': protisthanId,
      'name': name,
      'created_at': createdAt,
      'target_amount': targetAmount,
    };
  }

  factory Ward.fromMap(Map<String, dynamic> map) {
    return Ward(
      id: map['id'] as int?,
      uuid: map['uuid'] as String,
      protisthanId: map['protisthan_id'] as int,
      name: map['name'] as String,
      createdAt: map['created_at'] as String,
      targetAmount: (map['target_amount'] as num?)?.toDouble() ?? 0,
    );
  }
}
