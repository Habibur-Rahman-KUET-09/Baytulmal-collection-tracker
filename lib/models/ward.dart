class Ward {
  final int? id;
  final String uuid;
  final int protisthanId;
  final String name;
  final String createdAt;

  /// Special criteria #1 (ধার্যকৃত নিসাব): a fixed BDT value set once when
  /// the ward is created (editable later), not a per-month Entry. Kept out
  /// of every collection total (ward/protisthan/matrix sums) — it's a
  /// reference target, not money actually collected.
  final double targetAmount;

  /// Marks this as the one hidden "থানা" ward auto-created for every
  /// Protisthan (see [DatabaseHelper.ensureThanaWard]) — it reuses the
  /// ordinary ward/entry machinery so থানার নিজস্ব normal-খাত collections
  /// (থানার আয়) can be tracked the same way a real ward's are, without a
  /// separate table. It never appears in ward lists/counts/pickers (see
  /// [DatabaseHelper.getWardsForProtisthan]), has no ধার্যকৃত
  /// নিসাব/আয়/ব্যয়/বাস্তব জমা of its own, and shows up in the matrix
  /// report as a distinct "থানা" row instead of a normal ward row.
  final bool isThanaWard;

  const Ward({
    this.id,
    required this.uuid,
    required this.protisthanId,
    required this.name,
    required this.createdAt,
    this.targetAmount = 0,
    this.isThanaWard = false,
  });

  Ward copyWith({
    int? id,
    String? uuid,
    int? protisthanId,
    String? name,
    String? createdAt,
    double? targetAmount,
    bool? isThanaWard,
  }) {
    return Ward(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      protisthanId: protisthanId ?? this.protisthanId,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      targetAmount: targetAmount ?? this.targetAmount,
      isThanaWard: isThanaWard ?? this.isThanaWard,
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
      'is_thana_ward': isThanaWard ? 1 : 0,
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
      isThanaWard: (map['is_thana_ward'] as int?) == 1,
    );
  }
}
