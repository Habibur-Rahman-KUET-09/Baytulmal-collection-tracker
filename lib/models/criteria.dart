class Criteria {
  final int? id;
  final String uuid;
  final int protisthanId;
  final String name;
  final String createdAt;

  /// Marks this as one of the four "special" criteria per ward, together
  /// satisfying আয় − ব্যয় = বাস্তব জমা:
  ///   ১ = ধার্যকৃত নিসাব — not backed by an Entry at all; its value is
  ///       always the ward's fixed [Ward.targetAmount], fixed at ward
  ///       creation and never re-typed per month.
  ///   ২ = আয় — an ordinary per-month Entry.
  ///   ৩ = ব্যয় — an ordinary per-month Entry.
  ///   ৪ = বাস্তব জমা — not backed by an Entry either; always computed as
  ///       আয়(২) − ব্যয়(৩) for that ward+month.
  /// ১ and ২ are excluded from every ward/matrix row+grand total (see
  /// [DatabaseHelper.getMatrixReport]) — ১ is a reference figure rather
  /// than money collected, and ২ doesn't need to be summed directly since
  /// its value already flows through via ৩+৪ (৩ + ৪ = ব্যয় + (আয়−ব্যয়) =
  /// আয়, so counting ৩ and ৪ nets out to exactly ২ without double-counting).
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

  /// ধার্যকৃত নিসাব — its value always comes from [Ward.targetAmount],
  /// never an Entry.
  bool get isFixedTarget => specialOrder == 1;

  /// বাস্তব জমা — its value is always আয়(২) − ব্যয়(৩) for that ward+month,
  /// never an Entry.
  bool get isComputedDeposit => specialOrder == 4;

  /// Neither ধার্যকৃত নিসাব nor বাস্তব জমা ever has an Entry — both are
  /// always computed/derived instead of typed.
  bool get hasNoEntry => isFixedTarget || isComputedDeposit;

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
