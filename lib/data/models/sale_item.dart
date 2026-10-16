/// Snapshot item record of a completed sale matching SQLite sale_items table.
class SaleItem {
  final int id;
  final int saleId;
  final int productId;
  final String productName;
  final int qty;
  final int unitPriceCents;
  final int unitCostCents;

  const SaleItem({
    required this.id,
    required this.saleId,
    required this.productId,
    required this.productName,
    required this.qty,
    required this.unitPriceCents,
    required this.unitCostCents,
  });

  int get subtotalCents => unitPriceCents * qty;
  int get profitCents => (unitPriceCents - unitCostCents) * qty;

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      id: map['id'] as int,
      saleId: map['sale_id'] as int,
      productId: map['product_id'] as int,
      productName: map['product_name'] as String,
      qty: map['qty'] as int,
      unitPriceCents: map['unit_price_cents'] as int,
      unitCostCents: map['unit_cost_cents'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id > 0) 'id': id,
      'sale_id': saleId,
      'product_id': productId,
      'product_name': productName,
      'qty': qty,
      'unit_price_cents': unitPriceCents,
      'unit_cost_cents': unitCostCents,
    };
  }
}
