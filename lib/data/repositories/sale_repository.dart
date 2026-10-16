import 'package:sqflite/sqflite.dart';
import '../../core/exceptions.dart';
import '../db/app_database.dart';
import '../models/cart_item.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';

class SaleRepository {
  final AppDatabase _appDb;
  SaleRepository([AppDatabase? appDb]) : _appDb = appDb ?? AppDatabase.instance;

  Future<Database> get _db async => await _appDb.database;

  /// Creates a sale in a single SQLite transaction.
  /// Deducts stock, writes audit movement, logs snapshot items, and logs utang if credit sale.
  Future<Sale> createSale({
    required List<CartItem> items,
    required String paymentType, // 'cash' or 'utang'
    int? cashReceivedCents,
    int? changeCents,
    int? customerId,
  }) async {
    if (items.isEmpty) {
      throw const ValidationException('Walang laman ang cart.');
    }

    if (paymentType == 'utang' && customerId == null) {
      throw const ValidationException('Pumili ng customer para sa utang transaction.');
    }

    final db = await _db;
    final now = DateTime.now().toUtc().toIso8601String();
    final totalCents = items.fold<int>(0, (sum, item) => sum + item.subtotalCents);

    return await db.transaction<Sale>((txn) async {
      // 1. Enforce Stock Constraint: Stock never goes negative!
      for (final item in items) {
        final prodRows = await txn.query(
          'products',
          columns: ['id', 'name', 'stock_qty'],
          where: 'id = ?',
          whereArgs: [item.product.id],
        );

        if (prodRows.isEmpty) {
          throw ValidationException('Hindi nahanap ang produkto: ${item.product.name}');
        }

        final availableStock = prodRows.first['stock_qty'] as int;
        if (availableStock < item.qty) {
          throw OutOfStockException(
            productName: item.product.name,
            availableQty: availableStock,
            requestedQty: item.qty,
          );
        }
      }

      // 2. Insert Sale master record
      final saleId = await txn.insert('sales', {
        'sold_at': now,
        'total_cents': totalCents,
        'payment_type': paymentType,
        'cash_received_cents': paymentType == 'cash' ? cashReceivedCents : null,
        'change_cents': paymentType == 'cash' ? changeCents : null,
        'customer_id': customerId,
        'status': 'completed',
      });

      // 3. Insert items and decrement stock
      for (final item in items) {
        // Log snapshot into sale_items
        await txn.insert('sale_items', {
          'sale_id': saleId,
          'product_id': item.product.id,
          'product_name': item.product.name,
          'qty': item.qty,
          'unit_price_cents': item.product.priceCents,
          'unit_cost_cents': item.product.costCents,
        });

        // Decrement product stock
        await txn.rawUpdate('''
          UPDATE products
          SET stock_qty = stock_qty - ?, updated_at = ?
          WHERE id = ?
        ''', [item.qty, now, item.product.id]);

        // Audit stock movement
        await txn.insert('stock_movements', {
          'product_id': item.product.id,
          'type': 'sale',
          'qty_change': -item.qty,
          'sale_id': saleId,
          'note': 'Sale #$saleId',
          'created_at': now,
        });
      }

      // 4. Utang charge ledger entry
      if (paymentType == 'utang' && customerId != null) {
        await txn.insert('utang_entries', {
          'customer_id': customerId,
          'type': 'charge',
          'amount_cents': totalCents,
          'sale_id': saleId,
          'note': 'Sale #$saleId credit',
          'created_at': now,
        });
      }

      return Sale(
        id: saleId,
        soldAt: now,
        totalCents: totalCents,
        paymentType: paymentType,
        cashReceivedCents: cashReceivedCents,
        changeCents: changeCents,
        customerId: customerId,
        status: 'completed',
      );
    });
  }

  /// Void an existing sale. Restores inventory and cancels credit charge in a single transaction.
  Future<void> voidSale(int saleId, {required String reason}) async {
    final db = await _db;
    final now = DateTime.now().toUtc().toIso8601String();

    await db.transaction((txn) async {
      final saleRows = await txn.query(
        'sales',
        where: 'id = ?',
        whereArgs: [saleId],
      );

      if (saleRows.isEmpty) {
        throw const ValidationException('Hindi nahanap ang record ng benta.');
      }

      final sale = Sale.fromMap(saleRows.first);
      if (sale.isVoided) {
        throw const ValidationException('Nai-void na ang bentang ito.');
      }

      // 1. Mark sale as voided
      await txn.update(
        'sales',
        {
          'status': 'voided',
          'voided_at': now,
          'void_reason': reason,
        },
        where: 'id = ?',
        whereArgs: [saleId],
      );

      // 2. Fetch sale items and restore stock
      final itemsRows = await txn.query(
        'sale_items',
        where: 'sale_id = ?',
        whereArgs: [saleId],
      );

      for (final row in itemsRows) {
        final item = SaleItem.fromMap(row);

        // Restore stock
        await txn.rawUpdate('''
          UPDATE products
          SET stock_qty = stock_qty + ?, updated_at = ?
          WHERE id = ?
        ''', [item.qty, now, item.productId]);

        // Audit void return movement
        await txn.insert('stock_movements', {
          'product_id': item.productId,
          'type': 'void_return',
          'qty_change': item.qty,
          'sale_id': saleId,
          'note': 'Void return: $reason',
          'created_at': now,
        });
      }
    });
  }

  Future<List<Sale>> getRecentSales({int limit = 50}) async {
    final db = await _db;
    final rows = await db.query(
      'sales',
      orderBy: 'sold_at DESC',
      limit: limit,
    );
    return rows.map((r) => Sale.fromMap(r)).toList();
  }

  Future<List<SaleItem>> getSaleItems(int saleId) async {
    final db = await _db;
    final rows = await db.query(
      'sale_items',
      where: 'sale_id = ?',
      whereArgs: [saleId],
    );
    return rows.map((r) => SaleItem.fromMap(r)).toList();
  }
}
