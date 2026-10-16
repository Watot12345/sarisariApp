import 'dart:ffi' show DynamicLibrary;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';
import 'package:tindahan/core/strings.dart';
import 'package:tindahan/core/theme/app_theme.dart';
import 'package:tindahan/core/theme/theme_provider.dart';
import 'package:tindahan/data/db/app_database.dart';
import 'package:tindahan/data/db/migrations/m001_initial.dart';
import 'package:tindahan/data/db/seed.dart';
import 'package:tindahan/data/models/product.dart';
import 'package:tindahan/data/repositories/product_repository.dart';
import 'package:tindahan/data/repositories/stock_repository.dart';
import 'package:tindahan/features/products/providers/product_provider.dart';
import 'package:tindahan/features/products/screens/products_screen.dart';

void main() {
  late Database db;
  late AppDatabase appDb;
  late ProductRepository productRepo;
  late StockRepository stockRepo;
  late ProductProvider productProv;

  setUp(() async {
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
    productRepo = ProductRepository(appDb);
    stockRepo = StockRepository(appDb);
    productProv = ProductProvider(productRepo: productRepo, stockRepo: stockRepo);
    await productProv.loadProducts();
  });

  tearDown(() async {
    await db.close();
  });

  Widget wrapProductsScreen() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider.value(value: productProv),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const ProductsScreen(),
      ),
    );
  }

  group('Phase 3 - Database Tests (P3-DB-01 to P3-DB-04)', () {
    test('P3-DB-01: Adding a product with initial stock creates a stock_movements row', () async {
      const newProd = Product(
        id: 0,
        name: 'Bear Brand Swak Pack',
        categoryId: 1,
        priceCents: 1300,
        costCents: 1050,
        stockQty: 15,
        lowStockLevel: 5,
      );

      final newId = await productRepo.insertProduct(newProd);
      final movements = await stockRepo.getMovementsForProduct(newId);

      expect(movements.length, equals(1));
      expect(movements.first.type, equals('adjustment'));
      expect(movements.first.qtyChange, equals(15));
      expect(movements.first.note, equals('Initial inventory'));
    });

    test('P3-DB-02: Updating a product stock quantity logs an adjustment in stock_movements', () async {
      final prod = (await productRepo.getProductById(1))!;
      final oldStock = prod.stockQty;

      await productRepo.updateProduct(prod.copyWith(stockQty: oldStock + 7));

      final movements = await stockRepo.getMovementsForProduct(1);
      expect(movements.isNotEmpty, isTrue);
      expect(movements.first.type, equals('adjustment'));
      expect(movements.first.qtyChange, equals(7));
    });

    test('P3-DB-03: Soft delete hides product from active list while keeping DB record for reports', () async {
      await productRepo.softDeleteProduct(1);

      final activeLookup = await productRepo.getProductById(1);
      expect(activeLookup, isNull);

      // Still exists in raw table with is_active = 0 for historical sales reports
      final rawRows = await db.query('products', where: 'id = ?', whereArgs: [1]);
      expect(rawRows.length, equals(1));
      expect(rawRows.first['is_active'], equals(0));
    });

    test('P3-DB-04: Restock, manual adjustment, and tingi pack break each record stock_movements rows', () async {
      // 1. Restock +12 with updated unit cost
      final p1 = (await productRepo.getProductById(1))!;
      await stockRepo.restock(1, 12, unitCostCents: 1300, note: 'Bagong stock');
      var m1 = await stockRepo.getMovementsForProduct(1);
      expect(m1.first.type, equals('restock'));
      expect(m1.first.qtyChange, equals(12));

      // 2. Manual adjustment (e.g. Damaged / Spoilage -2 pcs)
      final currentStock = p1.stockQty + 12;
      await stockRepo.adjustStock(1, currentStock - 2, note: 'Damaged (Nasira / Nabutas)');
      m1 = await stockRepo.getMovementsForProduct(1);
      expect(m1.first.type, equals('adjustment'));
      expect(m1.first.qtyChange, equals(-2));
      expect(m1.first.note, contains('Damaged'));

      // 3. Tingi pack break creates pack_break_out (-1) and pack_break_in (+piecesPerPack)
      final allProds = await productRepo.getProducts();
      final packProd = allProds.firstWhere((p) => p.pieceProductId != null && (p.piecesPerPack ?? 0) > 1);
      await stockRepo.breakPack(packProd.id);

      final packMoves = await stockRepo.getMovementsForProduct(packProd.id);
      final pieceMoves = await stockRepo.getMovementsForProduct(packProd.pieceProductId!);
      expect(packMoves.first.type, equals('pack_break_out'));
      expect(packMoves.first.qtyChange, equals(-1));
      expect(pieceMoves.first.type, equals('pack_break_in'));
      expect(pieceMoves.first.qtyChange, equals(packProd.piecesPerPack));
    });
  });

  group('Phase 3 - Backend & Provider Logic Tests (P3-BE-01 to P3-BE-04)', () {
    test('P3-BE-01: ProductProvider filters by search query, category, and low-stock status', () async {
      // Category filter
      productProv.setCategory('Noodles');
      expect(productProv.filteredProducts.isNotEmpty, isTrue);
      expect(productProv.filteredProducts.every((p) => p.categoryName == 'Noodles'), isTrue);

      // Search query filter
      productProv.setCategory('All');
      productProv.setSearchQuery('Kalamansi');
      expect(productProv.filteredProducts.length, equals(1));
      expect(productProv.filteredProducts.first.name, contains('Kalamansi'));

      // Low-stock filter
      productProv.setSearchQuery('');
      productProv.toggleLowStockFilter();
      expect(productProv.filterLowStockOnly, isTrue);
      expect(
        productProv.filteredProducts.every((p) => p.isLowStock || p.isOutOfStock),
        isTrue,
      );
    });

    test('P3-BE-02: ProductProvider adds product with new custom category and updates product details', () async {
      const customProd = Product(
        id: 0,
        name: 'Pandesal Balot (10 pcs)',
        priceCents: 2500,
        costCents: 2000,
        stockQty: 10,
        lowStockLevel: 3,
      );

      await productProv.addProduct(customProd, categoryName: 'Tinapay');

      final added = productProv.allProducts.firstWhere((p) => p.name == 'Pandesal Balot (10 pcs)');
      expect(added.categoryName, equals('Tinapay'));
      expect(added.priceCents, equals(2500));
      expect(added.stockQty, equals(10));
      expect(productProv.categories.contains('Tinapay'), isTrue);

      // Update price to ₱30.00 (3000 cents)
      await productProv.updateProduct(added.copyWith(priceCents: 3000), categoryName: 'Tinapay');
      final updated = productProv.allProducts.firstWhere((p) => p.id == added.id);
      expect(updated.priceCents, equals(3000));
    });

    test('P3-BE-03: Barcode uniqueness check rejects duplicate barcodes but allows self-edit', () async {
      final prodWithBarcode = productProv.allProducts.firstWhere((p) => p.barcode != null);
      final barcode = prodWithBarcode.barcode!;

      // Another product trying to use this barcode -> false
      expect(await productProv.isBarcodeUnique(barcode), isFalse);

      // Editing the same product with its own barcode -> true
      expect(
        await productProv.isBarcodeUnique(barcode, excludeProductId: prodWithBarcode.id),
        isTrue,
      );

      // Brand new barcode -> true
      expect(await productProv.isBarcodeUnique('9998887776665'), isTrue);
    });

    test('P3-BE-04: ProductProvider.breakPack converts 1 mother pack into tingi pieces', () async {
      final packProd = productProv.allProducts.firstWhere(
        (p) => p.pieceProductId != null && (p.piecesPerPack ?? 0) > 1,
      );
      final pieceProdBefore = productProv.allProducts.firstWhere(
        (p) => p.id == packProd.pieceProductId,
      );

      await productProv.breakPack(packProd.id);

      final packAfter = productProv.allProducts.firstWhere((p) => p.id == packProd.id);
      final pieceAfter = productProv.allProducts.firstWhere((p) => p.id == pieceProdBefore.id);

      expect(packAfter.stockQty, equals(packProd.stockQty - 1));
      expect(pieceAfter.stockQty, equals(pieceProdBefore.stockQty + packProd.piecesPerPack!));
    });
  });

  group('Phase 3 - UX & Screen Tests (P3-UX-01 to P3-UX-05)', () {
    testWidgets('P3-UX-01: ProductsScreen search, category chips, and Mababa low-stock filter work interactively', (tester) async {
      await tester.pumpWidget(wrapProductsScreen());
      await tester.pumpAndSettle();

      // Search for "Kopiko"
      await tester.enterText(find.byType(TextField), 'Kopiko');
      await tester.pumpAndSettle();
      expect(productProv.filteredProducts.length, equals(1));
      expect(productProv.filteredProducts.first.name, contains('Kopiko'));

      // Clear search
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();
      expect(productProv.searchQuery, isEmpty);

      // Tap Mababa low-stock filter chip
      await tester.tap(find.textContaining('Mababa'));
      await tester.pumpAndSettle();
      expect(productProv.filterLowStockOnly, isTrue);
    });

    testWidgets('P3-UX-02: AddEditProductSheet validates inputs, displays live profit margin, and adds new product', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrapProductsScreen());
      await tester.pumpAndSettle();

      // Tap FAB to open AddEditProductSheet
      await tester.tap(find.text(AppStrings.addProduct));
      await tester.pumpAndSettle();

      expect(find.text('Magdagdag ng Produkto'), findsOneWidget);

      // Enter product name, selling price (₱20.00), and cost (₱15.00)
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Pangalan ng Produkto *'),
        'Choco Mucho White',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Presyo (₱) *'),
        '20.00',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Puhunan (₱)'),
        '15.00',
      );
      await tester.pumpAndSettle();

      // Verify live profit margin indicator appears ("Tubo bawat piraso:" ₱5.00 (25.0%))
      expect(find.text('Tubo bawat piraso:'), findsOneWidget);
      expect(find.textContaining('25.0%'), findsOneWidget);

      // Scroll down and tap "Idagdag sa Tindahan"
      final saveBtn = find.text('Idagdag sa Tindahan');
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Verify new product is added to ProductProvider
      expect(productProv.allProducts.any((p) => p.name == 'Choco Mucho White'), isTrue);
    });

    testWidgets('P3-UX-03: ProductDetailSheet displays profit details and adjusts stock with reason', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrapProductsScreen());
      await tester.pumpAndSettle();

      final targetProd = productProv.filteredProducts.first;
      final initialQty = targetProd.stockQty;

      // Tap product card to open ProductDetailSheet
      await tester.tap(find.text(targetProd.name));
      await tester.pumpAndSettle();

      expect(find.text('Presyo ng Benta'), findsOneWidget);
      expect(find.text('Kasalukuyang Stock'), findsOneWidget);

      // Tap "I-adjust" button
      await tester.tap(find.text('I-adjust'));
      await tester.pumpAndSettle();

      expect(find.text('I-adjust ang Stock: ${targetProd.name}'), findsOneWidget);

      // Tap '+' icon in adjustment dialog to increment stock by 1
      await tester.tap(find.byIcon(Icons.add).last);
      await tester.pumpAndSettle();

      // Save adjustment
      await tester.tap(find.text('I-save ang Adjustment'));
      await tester.pumpAndSettle();

      final updated = productProv.allProducts.firstWhere((p) => p.id == targetProd.id);
      expect(updated.stockQty, equals(initialQty + 1));
    });

    testWidgets('P3-UX-04: ProductDetailSheet breaks mother pack into tingi pieces via Buksan (Break)', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrapProductsScreen());
      await tester.pumpAndSettle();

      final packProd = productProv.allProducts.firstWhere(
        (p) => p.pieceProductId != null && (p.piecesPerPack ?? 0) > 1,
      );
      final pieceBefore = productProv.allProducts.firstWhere(
        (p) => p.id == packProd.pieceProductId,
      );

      // Search for the mother pack so it is at the top of the list
      await tester.enterText(find.byType(TextField), packProd.name);
      await tester.pumpAndSettle();

      expect(find.text('PACK'), findsOneWidget);

      // Open ProductDetailSheet for the mother pack (tap thePACK badge on the card)
      await tester.tap(find.text('PACK'));
      await tester.pumpAndSettle();

      expect(find.text('Tingi Pack Available'), findsOneWidget);

      // Tap "Buksan (Break)"
      await tester.tap(find.text('Buksan (Break)'));
      await tester.pumpAndSettle();

      final packAfter = productProv.allProducts.firstWhere((p) => p.id == packProd.id);
      final pieceAfter = productProv.allProducts.firstWhere((p) => p.id == pieceBefore.id);
      expect(packAfter.stockQty, equals(packProd.stockQty - 1));
      expect(pieceAfter.stockQty, equals(pieceBefore.stockQty + packProd.piecesPerPack!));
    });

    testWidgets('P3-UX-05: Soft-deleting a product from ProductsScreen confirms and removes it from active list', (tester) async {
      await tester.pumpWidget(wrapProductsScreen());
      await tester.pumpAndSettle();

      final targetProd = productProv.filteredProducts.first;

      // Tap delete icon on the first product row
      await tester.tap(find.byIcon(Icons.delete_outline_rounded).first);
      await tester.pumpAndSettle();

      expect(find.text('I-delete si ${targetProd.name}?'), findsOneWidget);

      // Confirm deletion
      await tester.tap(find.text('Oo, I-delete'));
      await tester.pumpAndSettle();

      expect(productProv.allProducts.any((p) => p.id == targetProd.id), isFalse);
    });
  });
}
