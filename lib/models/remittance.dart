/// A single protisthan+month's "higher management" remittance record: how
/// much was spent locally (expense) and how much was actually deposited
/// upward, so it can be compared against the theoretical
/// (total collection − expense) figure.
class Remittance {
  final int? id;
  final String uuid;
  final int protisthanId;
  final int month;
  final int year;
  final double expenseAmount;
  final double actualDepositAmount;
  final String updatedAt;

  const Remittance({
    this.id,
    required this.uuid,
    required this.protisthanId,
    required this.month,
    required this.year,
    this.expenseAmount = 0,
    this.actualDepositAmount = 0,
    required this.updatedAt,
  });

  Remittance copyWith({
    int? id,
    String? uuid,
    int? protisthanId,
    int? month,
    int? year,
    double? expenseAmount,
    double? actualDepositAmount,
    String? updatedAt,
  }) {
    return Remittance(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      protisthanId: protisthanId ?? this.protisthanId,
      month: month ?? this.month,
      year: year ?? this.year,
      expenseAmount: expenseAmount ?? this.expenseAmount,
      actualDepositAmount: actualDepositAmount ?? this.actualDepositAmount,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uuid': uuid,
      'protisthan_id': protisthanId,
      'month': month,
      'year': year,
      'expense_amount': expenseAmount,
      'actual_deposit_amount': actualDepositAmount,
      'updated_at': updatedAt,
    };
  }

  factory Remittance.fromMap(Map<String, dynamic> map) {
    return Remittance(
      id: map['id'] as int?,
      uuid: map['uuid'] as String,
      protisthanId: map['protisthan_id'] as int,
      month: map['month'] as int,
      year: map['year'] as int,
      expenseAmount: (map['expense_amount'] as num).toDouble(),
      actualDepositAmount: (map['actual_deposit_amount'] as num).toDouble(),
      updatedAt: map['updated_at'] as String,
    );
  }
}
