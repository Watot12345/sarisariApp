import 'package:sqflite/sqflite.dart';
import '../../core/exceptions.dart';
import '../db/app_database.dart';
import '../models/stock_movement.dart';

class StockRepository {
  final AppDatabase _appDb;
  StockRepository([AppDatabase? appDb]) : _appDb = appDb ?? AppDatabase.instance;

  Future<Database> get _db async => await _appDb.database;

  /// Restock inventory. Atomically increments stock and records stock movement.
  Future<void> restock(
    int productId,
    int addQty, {
    int? unitCostCents,
    String? note,
  }) async {
    if (addQty <= 0) {
      throw const ValidationException('Kailangang mas mataas sa zero ang idadagdag na stock.');
    }

    final db = await _db;
    final now = DateTime.now().toUtc().toIso8601String();

    await db.transaction((txn) async {
      final rows = await txn.query(
        'products',
        columns: ['id', 'name', 'stock_qty', 'cost_cents'],
        where: 'id = ?',
        whereArgs: [productId],
      );

      if (rows.isEmpty) {
        throw const ValidationException('Hindi nahanap ang produkto.');
      }

      final currentStock = rows.first['stock_qty'] as int;
      final newStock = currentStock + addQty;

      // Update product stock and optionally cost
      final Map<String, dynamic> updateValues = {
        'stock_qty': newStock,
        'updated_at': now,
      };
      if (unitCostCents != null && unitCostCents > 0) {
        updateValues['cost_cents'] = unitCostCents;
      }

      await txn.update(
        'products',
        updateValues,
        where: 'id = ?',
        whereArgs: [productId],
      );

      // Audit movement
      await txn.insert('stock_movements', {
        'product_id': productId,
        'type': 'restock',
        'qty_change': addQty,
        'unit_cost_cents': unitCostCents ?? (rows.first['cost_cents'] as int?),
        'note': note ?? 'Manual restock',
        'created_at': now,
      });
    });
  }

  /// Adjust stock to a specific target count. Stock cannot be negative.
  Future<void> adjustStock(
    int productId,
    int targetQty, {
    String? note,
  }) async {
    if (targetQty < 0) {
      throw const ValidationException('Hindi maaaring maging negative ang bilang ng stock.');
    }

    final db = await _db;
    final now = DateTime.now().toUtc().toIso8601String();

    await db.transaction((txn) async {
      final rows = await txn.query(
        'products',
        columns: ['id', 'name', 'stock_qty'],
        where: 'id = ?',
        whereArgs: [productId],
      );

      if (rows.isEmpty) {
        throw const ValidationException('Hindi nahanap ang produkto.');
      }

      final currentStock = rows.first['stock_qty'] as int;
      final diff = targetQty - currentStock;

      if (diff == 0) return; // No change

      await txn.update(
        'products',
        {'stock_qty': targetQty, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [productId],
      );

      await txn.insert('stock_movements', {
        'product_id': productId,
        'type': 'adjustment',
        'qty_change': diff,
        'note': note ?? 'Inventory adjustment',
        'created_at': now,
      });
    });
  }

  /// Tingi feature: Breaks 1 pack product into pieces of pieceProductId.
  Future<void> breakPack(int packProductId) async {
    final db = await _db;
    final now = DateTime.now().toUtc().toIso8601String();

    await db.transaction((txn) async {
      final packRows = await txn.query(
        'products',
        where: 'id = ?',
        whereArgs: [packProductId],
      );

      if (packRows.isEmpty) {
        throw const ValidationException('Hindi nahanap ang mother pack.');
      }

      final pack = packRows.first;
      final packStock = pack['stock_qty'] as int;
      final pieceId = pack['piece_product_id'] as int?;
      final piecesPerPack = pack['pieces_per_pack'] as int?;

      if (pieceId == null || piecesPerPack == null || piecesPerPack <= 1) {
        throw const ValidationException('Walang nakatakdang tingi link ang produktong ito.');
      }

      if (packStock <= 0) {
        throw OutOfStockException(
          productName: pack['name'] as String,
          availableQty: packStock,
          requestedQty: 1,
        );
      }

      final pieceRows = await txn.query(
        'products',
        where: 'id = ?',
        whereArgs: [pieceId],
      );
      if (pieceRows.isEmpty) {
        throw const ValidationException('Hindi nahanap ang tingi item sa database.');
      }

      // 1. Decrement pack stock by 1
      await txn.update(
        'products',
        {'stock_qty': packStock - 1, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [packProductId],
      );
      await txn.insert('stock_movements', {
        'product_id': packProductId,
        'type': 'pack_break_out',
        'qty_change': -1,
        'note': 'Opened 1 pack for tingi',
        'created_at': now,
      });

      // 2. Increment piece stock by piecesPerPack
      final pieceStock = pieceRows.first['stock_qty'] as int;
      await txn.update(
        'products',
        {'stock_qty': pieceStock + piecesPerPack, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [pieceId],
      );
      await txn.insert('stock_movements', {
        'product_id': pieceId,
        'type': 'pack_break_in',
        'qty_change': piecesPerPack,
        'note': 'Added from breaking 1 pack',
        'created_at': now,
      });
    });
  }

  Future<List<StockMovement>> getMovementsForProduct(int productId) async {
    final db = await _db;
    final rows = await db.query(
      'stock_movements',
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'created_at DESC',
    );
    return rows.map((r) => StockMovement.fromMap(r)).toList();
  }
}
