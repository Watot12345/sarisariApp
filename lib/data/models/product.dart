/// Product data model aligned with SQLite schema and integer centavos.
class Product {
  final int id;
  final String name;
  final String? barcode;
  final int? categoryId;
  final String categoryName;
  final int priceCents; // e.g. 1500 = ₱15.00
  final int costCents;  // e.g. 1200 = ₱12.00
  final int stockQty;
  final int lowStockLevel;
  final int? pieceProductId;
  final int? piecesPerPack;
  final String? expiryDate;
  final String? imagePath;
  final bool isActive;
  final String? createdAt;
  final String? updatedAt;

  const Product({
    required this.id,
    required this.name,
    this.barcode,
    this.categoryId,
    this.categoryName = 'General',
    required this.priceCents,
    required this.costCents,
    required this.stockQty,
    this.lowStockLevel = 5,
    this.pieceProductId,
    this.piecesPerPack,
    this.expiryDate,
    this.imagePath,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  bool get isLowStock => stockQty <= lowStockLevel && stockQty > 0;
  bool get isOutOfStock => stockQty <= 0;

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int,
      name: map['name'] as String,
      barcode: map['barcode'] as String?,
      categoryId: map['category_id'] as int?,
      categoryName: (map['category_name'] as String?) ?? 'General',
      priceCents: map['price_cents'] as int,
      costCents: (map['cost_cents'] as int?) ?? 0,
      stockQty: (map['stock_qty'] as int?) ?? 0,
      lowStockLevel: (map['low_stock_level'] as int?) ?? 5,
      pieceProductId: map['piece_product_id'] as int?,
      piecesPerPack: map['pieces_per_pack'] as int?,
      expiryDate: map['expiry_date'] as String?,
      imagePath: map['image_path'] as String?,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    final now = DateTime.now().toUtc().toIso8601String();
    return {
      if (id > 0) 'id': id,
      'name': name,
      'barcode': barcode,
      'category_id': categoryId,
      'price_cents': priceCents,
      'cost_cents': costCents,
      'stock_qty': stockQty,
      'low_stock_level': lowStockLevel,
      'piece_product_id': pieceProductId,
      'pieces_per_pack': piecesPerPack,
      'expiry_date': expiryDate,
      'image_path': imagePath,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt ?? now,
      'updated_at': updatedAt ?? now,
    };
  }

  Product copyWith({
    int? id,
    String? name,
    String? barcode,
    int? categoryId,
    String? categoryName,
    int? priceCents,
    int? costCents,
    int? stockQty,
    int? lowStockLevel,
    int? pieceProductId,
    int? piecesPerPack,
    String? expiryDate,
    String? imagePath,
    bool? isActive,
    String? createdAt,
    String? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      priceCents: priceCents ?? this.priceCents,
      costCents: costCents ?? this.costCents,
      stockQty: stockQty ?? this.stockQty,
      lowStockLevel: lowStockLevel ?? this.lowStockLevel,
      pieceProductId: pieceProductId ?? this.pieceProductId,
      piecesPerPack: piecesPerPack ?? this.piecesPerPack,
      expiryDate: expiryDate ?? this.expiryDate,
      imagePath: imagePath ?? this.imagePath,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
