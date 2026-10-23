import 'package:sqflite/sqflite.dart';
import '../../core/exceptions.dart';
import '../../core/utils/currency_formatter.dart';
import '../db/app_database.dart';
import '../models/category.dart';
import '../models/product.dart';
import 'activity_log_repository.dart';

class ProductRepository {
  final AppDatabase _appDb;
  final ActivityLogRepository _activityRepo;
  ProductRepository([AppDatabase? appDb])
      : _appDb = appDb ?? AppDatabase.instance,
        _activityRepo = ActivityLogRepository(appDb);

  Future<Database> get _db async => await _appDb.database;

  /// Fetches all active products with optional search query, category, and low stock filters.
  Future<List<Product>> getProducts({
    String? searchQuery,
    String? categoryName,
    bool lowStockOnly = false,
  }) async {
    final db = await _db;

    String sql = '''
      SELECT p.*, c.name AS category_name
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      WHERE p.is_active = 1
    ''';
    final List<dynamic> args = [];

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final term = '%${searchQuery.trim()}%';
      sql += ' AND (p.name LIKE ? OR p.barcode LIKE ?)';
      args.addAll([term, term]);
    }

    if (categoryName != null && categoryName != 'All' && categoryName.isNotEmpty) {
      sql += ' AND c.name = ?';
      args.add(categoryName);
    }

    if (lowStockOnly) {
      sql += ' AND (p.stock_qty <= p.low_stock_level)';
    }

    sql += ' ORDER BY p.name ASC';

    final rows = await db.rawQuery(sql, args);
    return rows.map((r) => Product.fromMap(r)).toList();
  }

  Future<Product?> getProductById(int id) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT p.*, c.name AS category_name
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      WHERE p.id = ? AND p.is_active = 1
    ''', [id]);

    if (rows.isEmpty) return null;
    return Product.fromMap(rows.first);
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT p.*, c.name AS category_name
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      WHERE p.barcode = ? AND p.is_active = 1
    ''', [barcode]);

    if (rows.isEmpty) return null;
    return Product.fromMap(rows.first);
  }

  Future<int> insertProduct(Product product) async {
    final db = await _db;

    if (product.barcode != null && product.barcode!.isNotEmpty) {
      final existing = await getProductByBarcode(product.barcode!);
      if (existing != null) {
        throw DuplicateBarcodeException(product.barcode!);
      }
    }

    return await db.transaction<int>((txn) async {
      final id = await txn.insert('products', product.toMap());
      if (product.stockQty > 0) {
        final now = DateTime.now().toUtc().toIso8601String();
        await txn.insert('stock_movements', {
          'product_id': id,
          'type': 'adjustment',
          'qty_change': product.stockQty,
          'unit_cost_cents': product.costCents,
          'note': 'Initial inventory',
          'created_at': now,
        });
      }
      await _activityRepo.logActivity(
        actionType: 'product_added',
        title: 'Added Product: ${product.name}',
        description: 'Price: ${CurrencyFormatter.format(product.priceCents)} • Initial Stock: ${product.stockQty}',
        txn: txn,
      );
      return id;
    });
  }

  Future<void> updateProduct(Product product) async {
    final db = await _db;

    if (product.barcode != null && product.barcode!.isNotEmpty) {
      final existing = await getProductByBarcode(product.barcode!);
      if (existing != null && existing.id != product.id) {
        throw DuplicateBarcodeException(product.barcode!);
      }
    }

    await db.transaction((txn) async {
      final oldRows = await txn.query(
        'products',
        columns: ['stock_qty'],
        where: 'id = ?',
        whereArgs: [product.id],
      );
      final oldStock = oldRows.isNotEmpty ? (oldRows.first['stock_qty'] as int) : product.stockQty;
      final diff = product.stockQty - oldStock;

      await txn.update(
        'products',
        product.toMap(),
        where: 'id = ?',
        whereArgs: [product.id],
      );

      if (diff != 0) {
        final now = DateTime.now().toUtc().toIso8601String();
        await txn.insert('stock_movements', {
          'product_id': product.id,
          'type': 'adjustment',
          'qty_change': diff,
          'unit_cost_cents': product.costCents,
          'note': 'Product edit stock adjustment',
          'created_at': now,
        });
      }

      await _activityRepo.logActivity(
        actionType: 'product_edited',
        title: 'Updated Product: ${product.name}',
        description: 'Price: ${CurrencyFormatter.format(product.priceCents)} • Stock: ${product.stockQty}',
        txn: txn,
      );
    });
  }

  Future<void> softDeleteProduct(int id) async {
    final db = await _db;
    final prod = await getProductById(id);
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      'products',
      {'is_active': 0, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _activityRepo.logActivity(
      actionType: 'product_deleted',
      title: 'Deleted Product: ${prod?.name ?? '#$id'}',
      description: 'Removed product from active store catalog',
    );
  }

  Future<List<Category>> getCategories() async {
    final db = await _db;
    final rows = await db.query('categories', orderBy: 'name ASC');
    return rows.map((r) => Category.fromMap(r)).toList();
  }

  Future<int> getOrCreateCategory(String name) async {
    final db = await _db;
    final existing = await db.query(
      'categories',
      where: 'name = ?',
      whereArgs: [name.trim()],
    );

    if (existing.isNotEmpty) {
      return existing.first['id'] as int;
    }

    return await db.insert('categories', {'name': name.trim()});
  }
}
