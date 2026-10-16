/// Sale record model matching SQLite sales table.
class Sale {
  final int id;
  final String soldAt; // ISO-8601 UTC
  final int totalCents;
  final String paymentType; // 'cash' or 'utang'
  final int? cashReceivedCents;
  final int? changeCents;
  final int? customerId;
  final String status; // 'completed' or 'voided'
  final String? voidedAt;
  final String? voidReason;

  const Sale({
    required this.id,
    required this.soldAt,
    required this.totalCents,
    required this.paymentType,
    this.cashReceivedCents,
    this.changeCents,
    this.customerId,
    this.status = 'completed',
    this.voidedAt,
    this.voidReason,
  });

  bool get isVoided => status == 'voided';
  bool get isUtang => paymentType == 'utang';
  bool get isCash => paymentType == 'cash';

  factory Sale.fromMap(Map<String, dynamic> map) {
    return Sale(
      id: map['id'] as int,
      soldAt: map['sold_at'] as String,
      totalCents: map['total_cents'] as int,
      paymentType: map['payment_type'] as String,
      cashReceivedCents: map['cash_received_cents'] as int?,
      changeCents: map['change_cents'] as int?,
      customerId: map['customer_id'] as int?,
      status: (map['status'] as String?) ?? 'completed',
      voidedAt: map['voided_at'] as String?,
      voidReason: map['void_reason'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id > 0) 'id': id,
      'sold_at': soldAt,
      'total_cents': totalCents,
      'payment_type': paymentType,
      'cash_received_cents': cashReceivedCents,
      'change_cents': changeCents,
      'customer_id': customerId,
      'status': status,
      'voided_at': voidedAt,
      'void_reason': voidReason,
    };
  }
}
