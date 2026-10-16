import 'dart:ffi' show DynamicLibrary;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';
import 'package:tindahan/core/exceptions.dart';
import 'package:tindahan/core/theme/app_theme.dart';
import 'package:tindahan/core/theme/theme_provider.dart';
import 'package:tindahan/data/db/app_database.dart';
import 'package:tindahan/data/db/migrations/m001_initial.dart';
import 'package:tindahan/data/db/seed.dart';
import 'package:tindahan/data/models/product.dart';
import 'package:tindahan/data/repositories/customer_repository.dart';
import 'package:tindahan/data/repositories/product_repository.dart';
import 'package:tindahan/data/repositories/sale_repository.dart';
import 'package:tindahan/data/repositories/stock_repository.dart';
import 'package:tindahan/data/repositories/utang_repository.dart';
import 'package:tindahan/features/products/providers/product_provider.dart';
import 'package:tindahan/features/products/screens/products_screen.dart';
import 'package:tindahan/features/products/widgets/add_edit_product_sheet.dart';
import 'package:tindahan/features/sell/providers/cart_provider.dart';
import 'package:tindahan/features/sell/screens/sell_screen.dart';
import 'package:tindahan/features/utang/providers/utang_provider.dart';
import 'package:tindahan/shared/widgets/barcode_scanner_sheet.dart';

void main() {
  late Database db;
  late AppDatabase appDb;
  late ProductRepository productRepo;
  late StockRepository stockRepo;
  late SaleRepository saleRepo;
  late CustomerRepository customerRepo;
  late UtangRepository utangRepo;

  late ProductProvider productProv;
  late CartProvider cartProv;
  late UtangProvider utangProv;

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
    saleRepo = SaleRepository(appDb);
    customerRepo = CustomerRepository(appDb);
    utangRepo = UtangRepository(appDb);

    productProv = ProductProvider(productRepo: productRepo, stockRepo: stockRepo);
    cartProv = CartProvider(saleRepo: saleRepo);
    utangProv = UtangProvider(customerRepo: customerRepo, utangRepo: utangRepo);

    await productProv.loadProducts();
    await utangProv.loadCustomers();
  });

  tearDown(() async {
    await db.close();
  });

  Widget wrapScreen(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider.value(value: productProv),
        ChangeNotifierProvider.value(value: cartProv),
        ChangeNotifierProvider.value(value: utangProv),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: child,
      ),
    );
  }

  group('Phase 5 - Database Tests (P5-DB-01 to P5-DB-02)', () {
    test('P5-DB-01: ProductRepository.getProductByBarcode looks up active products and ignores soft-deleted ones', () async {
      final prod = productProv.allProducts.firstWhere((p) => p.barcode != null);
      final code = prod.barcode!;

      final found = await productRepo.getProductByBarcode(code);
      expect(found, isNotNull);
      expect(found!.id, equals(prod.id));

      // Soft delete the product -> getProductByBarcode should now return null
      await productRepo.softDeleteProduct(prod.id);
      final afterDelete = await productRepo.getProductByBarcode(code);
      expect(afterDelete, isNull);
    });

    test('P5-DB-02: Duplicate barcode check throws DuplicateBarcodeException when inserting another active product', () async {
      final existing = productProv.allProducts.firstWhere((p) => p.barcode != null);

      expect(
        () => productRepo.insertProduct(
          Product(
            id: 0,
            name: 'Duplicate Barcode Test Item',
            barcode: existing.barcode,
            categoryName: 'Snacks',
            priceCents: 2000,
            costCents: 1500,
            stockQty: 5,
          ),
        ),
        throwsA(isA<DuplicateBarcodeException>()),
      );
    });
  });

  group('Phase 5 - Backend & Provider Logic Tests (P5-BE-01 to P5-BE-02)', () {
    test('P5-BE-01: ProductProvider.findProductByBarcode resolves known barcode and returns null for unknown barcode', () async {
      final knownProd = productProv.allProducts.firstWhere((p) => p.barcode != null);

      final found = await productProv.findProductByBarcode('  ${knownProd.barcode!}  ');
      expect(found, isNotNull);
      expect(found!.id, equals(knownProd.id));

      final unknown = await productProv.findProductByBarcode('9999990000111');
      expect(unknown, isNull);
    });

    test('P5-BE-02: Scanning a known in-stock product adds/increments cart item and updates total centavos', () async {
      final knownProd = productProv.allProducts.firstWhere(
        (p) => p.barcode != null && p.stockQty >= 3,
      );

      final resolved = await productProv.findProductByBarcode(knownProd.barcode!);
      expect(resolved, isNotNull);

      expect(cartProv.addToCart(resolved!), isTrue);
      expect(cartProv.addToCart(resolved), isTrue);
      expect(cartProv.itemCount, equals(2));
      expect(cartProv.totalCents, equals(resolved.priceCents * 2));
    });
  });

  group('Phase 5 - UX & Screen Tests (P5-UX-01 to P5-UX-04)', () {
    testWidgets('P5-UX-01: BarcodeScannerSheet renders viewfinder, toggles flashlight, and returns manual barcode', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      String? returnedCode;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  returnedCode = await BarcodeScannerSheet.show(context);
                },
                child: const Text('Open Scanner'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Scanner'));
      await tester.pumpAndSettle();

      expect(find.text('Align product barcode inside frame'), findsOneWidget);

      // Toggle Flashlight ON
      await tester.tap(find.byKey(const Key('scanner_torch_toggle_btn')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Flashlight ON'), findsOneWidget);

      // Submit empty barcode -> shows validation hint
      await tester.tap(find.byKey(const Key('submit_manual_barcode_btn')));
      await tester.pumpAndSettle();
      expect(find.text('Please enter or scan a valid barcode'), findsOneWidget);

      // Enter manual barcode and tap Use Code
      await tester.enterText(find.byKey(const Key('manual_barcode_input')), '4800016644023');
      await tester.tap(find.byKey(const Key('submit_manual_barcode_btn')));
      await tester.pumpAndSettle();

      expect(returnedCode, equals('4800016644023'));
    });

    testWidgets('P5-UX-02: Scanning a known barcode on SellScreen adds the product directly to the cart', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final knownProd = productProv.allProducts.firstWhere(
        (p) => p.barcode != null && p.stockQty >= 2,
      );

      await tester.pumpWidget(wrapScreen(const SellScreen()));
      await tester.pumpAndSettle();

      // Tap Scan Barcode button on SellScreen
      await tester.tap(find.byKey(const Key('sell_scan_barcode_btn')));
      await tester.pumpAndSettle();

      // Enter the known barcode manually and submit
      await tester.enterText(find.byKey(const Key('manual_barcode_input')), knownProd.barcode!);
      await tester.tap(find.byKey(const Key('submit_manual_barcode_btn')));
      await tester.pumpAndSettle();

      // Verify item is added to cart and FloatingCartBar appears
      expect(cartProv.itemCount, equals(1));
      expect(cartProv.items.first.product.id, equals(knownProd.id));
      expect(find.text('Tingnan'), findsOneWidget);
    });

    testWidgets('P5-UX-03: Scanning an unknown barcode on SellScreen offers registration and pre-fills AddEditProductSheet', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const newBarcode = '4809998887776';

      await tester.pumpWidget(wrapScreen(const SellScreen()));
      await tester.pumpAndSettle();

      // Tap Scan Barcode button on SellScreen
      await tester.tap(find.byKey(const Key('sell_scan_barcode_btn')));
      await tester.pumpAndSettle();

      // Enter unknown barcode and submit
      await tester.enterText(find.byKey(const Key('manual_barcode_input')), newBarcode);
      await tester.tap(find.byKey(const Key('submit_manual_barcode_btn')));
      await tester.pumpAndSettle();

      // Unregistered Barcode dialog appears
      expect(find.text('Unregistered Barcode'), findsOneWidget);
      expect(find.textContaining(newBarcode), findsOneWidget);

      // Tap Register Product -> opens AddEditProductSheet with barcode pre-filled
      await tester.tap(find.text('Register Product'));
      await tester.pumpAndSettle();

      expect(find.byType(AddEditProductSheet), findsOneWidget);
      expect(find.text(newBarcode), findsOneWidget);
    });

    testWidgets('P5-UX-04: Scanning a barcode on ProductsScreen opens Quick Restock for known item or AddEditProductSheet for new item', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final knownProd = productProv.allProducts.firstWhere(
        (p) => p.barcode != null,
      );
      final initialStock = knownProd.stockQty;

      await tester.pumpWidget(wrapScreen(const ProductsScreen()));
      await tester.pumpAndSettle();

      // Tap Scan Barcode button in ProductsScreen AppBar
      await tester.tap(find.byKey(const Key('products_scan_barcode_btn')));
      await tester.pumpAndSettle();

      // Enter known barcode -> opens Quick Restock dialog
      await tester.enterText(find.byKey(const Key('manual_barcode_input')), knownProd.barcode!);
      await tester.tap(find.byKey(const Key('submit_manual_barcode_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Quick Restock: ${knownProd.name}'), findsOneWidget);

      // Confirm +10 restock
      await tester.tap(find.text('I-kumpirma'));
      await tester.pumpAndSettle();

      final updatedProd = productProv.allProducts.firstWhere((p) => p.id == knownProd.id);
      expect(updatedProd.stockQty, equals(initialStock + 10));
    });
  });
}
