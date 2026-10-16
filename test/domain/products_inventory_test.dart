import 'dart:ffi';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';
import 'package:tindahan/data/db/app_database.dart';
import 'package:tindahan/data/db/migrations/m001_initial.dart';
import 'package:tindahan/data/db/seed.dart';
import 'package:tindahan/data/models/product.dart';
import 'package:tindahan/data/repositories/product_repository.dart';
import 'package:tindahan/data/repositories/stock_repository.dart';
import 'package:tindahan/features/products/providers/product_provider.dart';

class TestInventoryDbProvider {
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
  late TestInventoryDbProvider testDb;
  late ProductRepository productRepo;
  late StockRepository stockRepo;
  late ProductProvider productProv;

  setUp(() async {
    testDb = TestInventoryDbProvider();
    await testDb.init();
    productRepo = ProductRepository(testDb.appDb);
    stockRepo = StockRepository(testDb.appDb);
    productProv = ProductProvider(
      productRepo: productRepo,
      stockRepo: stockRepo,
    );
    await productProv.loadProducts();
  });

  tearDown(() async {
    await testDb.dispose();
  });

  group('Phase 3: Products and Inventory Tests', () {
    test('PR-01: Product search, category chips, and low-stock filter work accurately', () async {
      // 1. Initial list has seeded products
      expect(productProv.filteredProducts.isNotEmpty, isTrue);

      // 2. Search query filter
      productProv.setSearchQuery('Canton');
      expect(productProv.filteredProducts.every((p) => p.name.contains('Canton')), isTrue);
      productProv.setSearchQuery('');

      // 3. Category filter
      productProv.setCategory('Drinks');
      expect(productProv.filteredProducts.every((p) => p.categoryName == 'Drinks'), isTrue);
      productProv.setCategory('All');

      // 4. Low stock filter
      productProv.toggleLowStockFilter();
      expect(
        productProv.filteredProducts.every((p) => p.stockQty <= p.lowStockLevel),
        isTrue,
      );
    });

    test('PR-02: Adding a new product saves to SQLite and records initial stock movement', () async {
      const newProduct = Product(
        id: 0,
        name: 'Chippy Barbecue 110g',
        barcode: '4800016001122',
        priceCents: 3500,
        costCents: 2800,
        stockQty: 25,
        lowStockLevel: 5,
      );

      await productProv.addProduct(newProduct, categoryName: 'Snacks');

      final found = productProv.allProducts.firstWhere((p) => p.name == 'Chippy Barbecue 110g');
      expect(found.priceCents, equals(3500));
      expect(found.stockQty, equals(25));
      expect(found.categoryName, equals('Snacks'));

      // Check stock movement was written
      final movements = await stockRepo.getMovementsForProduct(found.id);
      expect(movements.isNotEmpty, isTrue);
      expect(movements.first.type, equals('adjustment'));
      expect(movements.first.qtyChange, equals(25));
    });

    test('PR-03: Updating an existing product persists changes cleanly', () async {
      final existing = productProv.allProducts.first;
      final updated = existing.copyWith(
        name: '${existing.name} (Updated)',
        priceCents: existing.priceCents + 500,
      );

      await productProv.updateProduct(updated);

      final reloaded = productProv.allProducts.firstWhere((p) => p.id == existing.id);
      expect(reloaded.name, contains('(Updated)'));
      expect(reloaded.priceCents, equals(existing.priceCents + 500));
    });

    test('PR-04: Barcode uniqueness validation correctly detects duplicates', () async {
      final existing = productProv.allProducts.firstWhere((p) => p.barcode != null);
      final barcode = existing.barcode!;

      // Another product using this barcode is duplicate
      final isUniqueForOther = await productProv.isBarcodeUnique(barcode, excludeProductId: 9999);
      expect(isUniqueForOther, isFalse);

      // Same product updating itself with same barcode is permitted
      final isUniqueForSelf = await productProv.isBarcodeUnique(barcode, excludeProductId: existing.id);
      expect(isUniqueForSelf, isTrue);
    });

    test('PR-05: Restocking increments inventory and creates a stock_movements row', () async {
      final target = productProv.allProducts.first;
      final initialStock = target.stockQty;

      await productProv.restockProduct(
        target.id,
        15,
        unitCostCents: 1200,
        note: 'Supplier Delivery Test',
      );

      final afterRestock = productProv.allProducts.firstWhere((p) => p.id == target.id);
      expect(afterRestock.stockQty, equals(initialStock + 15));

      final movements = await stockRepo.getMovementsForProduct(target.id);
      final restockMovement = movements.firstWhere((m) => m.type == 'restock');
      expect(restockMovement.qtyChange, equals(15));
      expect(restockMovement.unitCostCents, equals(1200));
      expect(restockMovement.note, equals('Supplier Delivery Test'));
    });

    test('PR-06: Manual stock adjustment updates stock and logs audit trail', () async {
      final target = productProv.allProducts.first;

      await productProv.adjustStock(
        target.id,
        42,
        reason: 'Recount (Aktwal na bilang)',
      );

      final afterAdjust = productProv.allProducts.firstWhere((p) => p.id == target.id);
      expect(afterAdjust.stockQty, equals(42));

      final movements = await stockRepo.getMovementsForProduct(target.id);
      final adjustMovement = movements.firstWhere((m) => m.type == 'adjustment');
      expect(adjustMovement.note, contains('Recount'));
    });

    test('PR-07: Tingi breakPack decrements pack and increments piece atomically', () async {
      // 1. Create a piece product (e.g. single stick)
      const pieceItem = Product(
        id: 0,
        name: 'Winston Red (Stick Tingi)',
        priceCents: 900,
        costCents: 750,
        stockQty: 0,
      );
      await productProv.addProduct(pieceItem, categoryName: 'Cigarettes');
      final pieceId = productProv.allProducts.firstWhere((p) => p.name == pieceItem.name).id;

      // 2. Create mother pack linked to piece
      final packItem = Product(
        id: 0,
        name: 'Winston Red Pack (20s)',
        priceCents: 17000,
        costCents: 15000,
        stockQty: 5,
        pieceProductId: pieceId,
        piecesPerPack: 20,
      );
      await productProv.addProduct(packItem, categoryName: 'Cigarettes');
      final packId = productProv.allProducts.firstWhere((p) => p.name == packItem.name).id;

      // 3. Break 1 pack
      await productProv.breakPack(packId);

      final packAfter = productProv.allProducts.firstWhere((p) => p.id == packId);
      final pieceAfter = productProv.allProducts.firstWhere((p) => p.id == pieceId);

      expect(packAfter.stockQty, equals(4)); // 5 - 1
      expect(pieceAfter.stockQty, equals(20)); // 0 + 20

      // Verify stock movements
      final packMovements = await stockRepo.getMovementsForProduct(packId);
      expect(packMovements.any((m) => m.type == 'pack_break_out' && m.qtyChange == -1), isTrue);

      final pieceMovements = await stockRepo.getMovementsForProduct(pieceId);
      expect(pieceMovements.any((m) => m.type == 'pack_break_in' && m.qtyChange == 20), isTrue);
    });

    test('PR-08: Soft-delete sets is_active = 0 and hides product from list', () async {
      const prod = Product(
        id: 0,
        name: 'Obsolete Item',
        priceCents: 1000,
        costCents: 800,
        stockQty: 10,
      );
      await productProv.addProduct(prod);
      final id = productProv.allProducts.firstWhere((p) => p.name == 'Obsolete Item').id;

      // Delete
      await productProv.deleteProduct(id);

      expect(productProv.allProducts.any((p) => p.id == id), isFalse);

      // Verify it is preserved in SQLite as is_active = 0
      final dbRows = await testDb.db.query('products', where: 'id = ?', whereArgs: [id]);
      expect(dbRows.isNotEmpty, isTrue);
      expect(dbRows.first['is_active'], equals(0));
    });
  });
}
