class Entry {
  final int? id;
  final String uuid;
  final int wardId;
  final int criteriaId;
  final int month; // 1-12
  final int year;
  final double amount; // BDT, >= 0
  final String updatedAt;

  const Entry({
    this.id,
    required this.uuid,
    required this.wardId,
    required this.criteriaId,
    required this.month,
    required this.year,
    required this.amount,
    required this.updatedAt,
  });

  Entry copyWith({
    int? id,
    String? uuid,
    int? wardId,
    int? criteriaId,
    int? month,
    int? year,
    double? amount,
    String? updatedAt,
  }) {
    return Entry(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      wardId: wardId ?? this.wardId,
      criteriaId: criteriaId ?? this.criteriaId,
      month: month ?? this.month,
      year: year ?? this.year,
      amount: amount ?? this.amount,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uuid': uuid,
      'ward_id': wardId,
      'criteria_id': criteriaId,
      'month': month,
      'year': year,
      'amount': amount,
      'updated_at': updatedAt,
    };
  }

  factory Entry.fromMap(Map<String, dynamic> map) {
    return Entry(
      id: map['id'] as int?,
      uuid: map['uuid'] as String,
      wardId: map['ward_id'] as int,
      criteriaId: map['criteria_id'] as int,
      month: map['month'] as int,
      year: map['year'] as int,
      amount: (map['amount'] as num).toDouble(),
      updatedAt: map['updated_at'] as String,
    );
  }
}
