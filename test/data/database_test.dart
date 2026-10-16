import 'dart:ffi';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';
import 'package:tindahan/data/db/app_database.dart';
import 'package:tindahan/data/db/migrations/m001_initial.dart';
import 'package:tindahan/data/db/seed.dart';
import 'package:tindahan/data/models/product.dart';

// Test wrapper providing in-memory SQLite database
class TestDatabaseProvider {
  late Database db;
  late AppDatabase appDb;

  Future<void> init() async {
    open.overrideFor(
      OperatingSystem.linux,
      () => DynamicLibrary.open('libsqlite3.so.0'),
    );
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await db.execute('PRAGMA foreign_keys = ON;');
    await M001Initial.create(db);
    await DatabaseSeeder.seedIfEmpty(db);
    appDb = AppDatabase.forTesting(db);
  }

  Future<void> dispose() async {
    await db.close();
  }
}

void main() {
  late TestDatabaseProvider testDb;

  setUp(() async {
    testDb = TestDatabaseProvider();
    await testDb.init();
  });

  tearDown(() async {
    await testDb.dispose();
  });

  group('Database Tests (DB-01 to DB-05)', () {
    test('DB-01: Initial Sari-Sari store seed data populates products, categories, and customers', () async {
      final prodRows = await testDb.db.query('products');
      expect(prodRows.length, greaterThanOrEqualTo(15));

      final luckyMe = prodRows.firstWhere((r) => r['name'] == 'Lucky Me Pancit Canton Kalamansi');
      expect(luckyMe['price_cents'], equals(1500));
      expect(luckyMe['stock_qty'], equals(24));

      final catRows = await testDb.db.query('categories');
      expect(catRows.isNotEmpty, isTrue);

      final custRows = await testDb.db.query('customers');
      expect(custRows.isNotEmpty, isTrue);
    });

    test('DB-02: Unique barcode constraint prevents duplicate product barcodes', () async {
      final now = DateTime.now().toUtc().toIso8601String();
      const productA = {
        'name': 'Duplicate Test 1',
        'barcode': '1234567890123',
        'price_cents': 1000,
        'cost_cents': 800,
        'stock_qty': 5,
        'low_stock_level': 2,
        'is_active': 1,
      };

      await testDb.db.insert('products', {...productA, 'created_at': now, 'updated_at': now});

      expect(
        () async {
          await testDb.db.insert('products', {
            ...productA,
            'name': 'Duplicate Test 2',
            'created_at': now,
            'updated_at': now,
          });
        },
        throwsA(isA<DatabaseException>()),
      );
    });

    test('DB-03: Stock cannot go negative (SQLite CHECK constraint enforced)', () async {
      expect(
        () async {
          await testDb.db.rawUpdate(
            'UPDATE products SET stock_qty = -5 WHERE id = 1',
          );
        },
        throwsA(isA<DatabaseException>()),
      );
    });

    test('DB-04: Sale transaction atomically decrements stock and logs sale_items + stock_movements', () async {
      final prodRows = await testDb.db.query('products', where: 'id = ?', whereArgs: [1]);
      final initialProduct = Product.fromMap(prodRows.first);
      final initialStock = initialProduct.stockQty;

      final now = DateTime.now().toUtc().toIso8601String();
      await testDb.db.transaction((txn) async {
        final saleId = await txn.insert('sales', {
          'sold_at': now,
          'total_cents': 3 * initialProduct.priceCents,
          'payment_type': 'cash',
          'cash_received_cents': 5000,
          'change_cents': 5000 - (3 * initialProduct.priceCents),
          'status': 'completed',
        });

        await txn.insert('sale_items', {
          'sale_id': saleId,
          'product_id': initialProduct.id,
          'product_name': initialProduct.name,
          'qty': 3,
          'unit_price_cents': initialProduct.priceCents,
          'unit_cost_cents': initialProduct.costCents,
        });

        await txn.rawUpdate(
          'UPDATE products SET stock_qty = stock_qty - ? WHERE id = ?',
          [3, initialProduct.id],
        );

        await txn.insert('stock_movements', {
          'product_id': initialProduct.id,
          'type': 'sale',
          'qty_change': -3,
          'sale_id': saleId,
          'note': 'Sale #$saleId',
          'created_at': now,
        });
      });

      final updatedProd = await testDb.db.query('products', where: 'id = ?', whereArgs: [1]);
      expect(updatedProd.first['stock_qty'], equals(initialStock - 3));

      final movements = await testDb.db.query('stock_movements', where: 'product_id = ?', whereArgs: [1]);
      expect(movements.isNotEmpty, isTrue);
      expect(movements.last['qty_change'], equals(-3));
    });

    test('DB-05: Utang ledger increases balance on credit charge and decreases on payment', () async {
      final initialBalanceRows = await testDb.db.rawQuery('''
        SELECT COALESCE(SUM(CASE WHEN type = 'charge' THEN amount_cents ELSE -amount_cents END), 0) AS bal
        FROM utang_entries WHERE customer_id = 1
      ''');
      final initialBal = (initialBalanceRows.first['bal'] as int);

      final now = DateTime.now().toUtc().toIso8601String();
      await testDb.db.insert('utang_entries', {
        'customer_id': 1,
        'type': 'charge',
        'amount_cents': 20000,
        'note': 'Test credit',
        'created_at': now,
      });

      final afterChargeRows = await testDb.db.rawQuery('''
        SELECT COALESCE(SUM(CASE WHEN type = 'charge' THEN amount_cents ELSE -amount_cents END), 0) AS bal
        FROM utang_entries WHERE customer_id = 1
      ''');
      expect(afterChargeRows.first['bal'], equals(initialBal + 20000));

      await testDb.db.insert('utang_entries', {
        'customer_id': 1,
        'type': 'payment',
        'amount_cents': 10000,
        'note': 'Partial payment',
        'created_at': now,
      });

      final afterPayRows = await testDb.db.rawQuery('''
        SELECT COALESCE(SUM(CASE WHEN type = 'charge' THEN amount_cents ELSE -amount_cents END), 0) AS bal
        FROM utang_entries WHERE customer_id = 1
      ''');
      expect(afterPayRows.first['bal'], equals(initialBal + 20000 - 10000));
    });
  });
}
