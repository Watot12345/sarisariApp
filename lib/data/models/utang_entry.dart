/// Utang ledger entry model matching SQLite utang_entries table.
class UtangEntry {
  final int id;
  final int customerId;
  final String type; // 'charge' or 'payment'
  final int amountCents;
  final int? saleId;
  final String? dueDate;
  final String? note;
  final String createdAt;

  const UtangEntry({
    required this.id,
    required this.customerId,
    required this.type,
    required this.amountCents,
    this.saleId,
    this.dueDate,
    this.note,
    required this.createdAt,
  });

  bool get isCharge => type == 'charge';
  bool get isPayment => type == 'payment';

  factory UtangEntry.fromMap(Map<String, dynamic> map) {
    return UtangEntry(
      id: map['id'] as int,
      customerId: map['customer_id'] as int,
      type: map['type'] as String,
      amountCents: map['amount_cents'] as int,
      saleId: map['sale_id'] as int?,
      dueDate: map['due_date'] as String?,
      note: map['note'] as String?,
      createdAt: map['created_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id > 0) 'id': id,
      'customer_id': customerId,
      'type': type,
      'amount_cents': amountCents,
      'sale_id': saleId,
      'due_date': dueDate,
      'note': note,
      'created_at': createdAt,
    };
  }
}
