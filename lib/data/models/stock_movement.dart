/// Stock audit trail movement matching SQLite stock_movements table.
class StockMovement {
  final int id;
  final int productId;
  final String type; // 'sale','void_return','restock','adjustment','pack_break_out','pack_break_in','expired'
  final int qtyChange; // negative = stock out, positive = stock in
  final int? unitCostCents;
  final int? saleId;
  final String? note;
  final String createdAt;

  const StockMovement({
    required this.id,
    required this.productId,
    required this.type,
    required this.qtyChange,
    this.unitCostCents,
    this.saleId,
    this.note,
    required this.createdAt,
  });

  factory StockMovement.fromMap(Map<String, dynamic> map) {
    return StockMovement(
      id: map['id'] as int,
      productId: map['product_id'] as int,
      type: map['type'] as String,
      qtyChange: map['qty_change'] as int,
      unitCostCents: map['unit_cost_cents'] as int?,
      saleId: map['sale_id'] as int?,
      note: map['note'] as String?,
      createdAt: map['created_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id > 0) 'id': id,
      'product_id': productId,
      'type': type,
      'qty_change': qtyChange,
      'unit_cost_cents': unitCostCents,
      'sale_id': saleId,
      'note': note,
      'created_at': createdAt,
    };
  }
}
