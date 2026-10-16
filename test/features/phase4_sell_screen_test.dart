import 'dart:ffi' show DynamicLibrary;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';
import 'package:tindahan/core/exceptions.dart';
import 'package:tindahan/core/localization/language_provider.dart';
import 'package:tindahan/core/strings.dart';
import 'package:tindahan/core/theme/app_theme.dart';
import 'package:tindahan/core/theme/theme_provider.dart';
import 'package:tindahan/data/db/app_database.dart';
import 'package:tindahan/data/db/migrations/m001_initial.dart';
import 'package:tindahan/data/db/seed.dart';
import 'package:tindahan/data/models/cart_item.dart';
import 'package:tindahan/data/models/customer.dart';
import 'package:tindahan/data/models/product.dart';
import 'package:tindahan/data/repositories/customer_repository.dart';
import 'package:tindahan/data/repositories/product_repository.dart';
import 'package:tindahan/data/repositories/sale_repository.dart';
import 'package:tindahan/data/repositories/stock_repository.dart';
import 'package:tindahan/data/repositories/utang_repository.dart';
import 'package:tindahan/domain/sale_calculator.dart';
import 'package:tindahan/features/gamification/gamification_provider.dart';
import 'package:tindahan/features/products/providers/product_provider.dart';
import 'package:tindahan/features/sell/providers/cart_provider.dart';
import 'package:tindahan/features/sell/screens/sell_screen.dart';
import 'package:tindahan/features/utang/providers/utang_provider.dart';

void main() {
  late Database db;
  late AppDatabase appDb;
  late SaleRepository saleRepo;
  late ProductRepository productRepo;
  late StockRepository stockRepo;
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
    saleRepo = SaleRepository(appDb);
    productRepo = ProductRepository(appDb);
    stockRepo = StockRepository(appDb);
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

  Widget wrapSellScreen() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => GamificationProvider()),
        ChangeNotifierProvider.value(value: productProv),
        ChangeNotifierProvider.value(value: cartProv),
        ChangeNotifierProvider.value(value: utangProv),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const SellScreen(),
      ),
    );
  }

  group('Phase 4 - Database Tests (P4-DB-01 to P4-DB-03)', () {
    test('P4-DB-01: Cash sale transaction inserts sales, sale_items snapshots, decrements stock, and logs stock_movements', () async {
      final prod = productProv.allProducts.firstWhere((p) => p.stockQty >= 5);
      final initialStock = prod.stockQty;

      final sale = await saleRepo.createSale(
        items: [CartItem(product: prod, qty: 3)],
        paymentType: 'cash',
        cashReceivedCents: 10000,
        changeCents: 10000 - (prod.priceCents * 3),
      );

      expect(sale.id, greaterThan(0));
      expect(sale.totalCents, equals(prod.priceCents * 3));
      expect(sale.status, equals('completed'));

      // Check decremented product stock
      final updatedProd = await productRepo.getProductById(prod.id);
      expect(updatedProd!.stockQty, equals(initialStock - 3));

      // Check sale_items snapshot
      final saleItems = await saleRepo.getSaleItems(sale.id);
      expect(saleItems.length, equals(1));
      expect(saleItems.first.productName, equals(prod.name));
      expect(saleItems.first.unitPriceCents, equals(prod.priceCents));
      expect(saleItems.first.unitCostCents, equals(prod.costCents));

      // Check stock_movements row
      final movements = await stockRepo.getMovementsForProduct(prod.id);
      final saleMov = movements.firstWhere((m) => m.saleId == sale.id && m.type == 'sale');
      expect(saleMov.qtyChange, equals(-3));
    });

    test('P4-DB-02: Utang credit sale transaction atomically creates utang_entries charge and updates customer balance', () async {
      final prod = productProv.allProducts.firstWhere((p) => p.stockQty >= 5);
      final cust = utangProv.allCustomers.first;
      final initialBalance = await utangRepo.getCustomerBalance(cust.id);

      final sale = await saleRepo.createSale(
        items: [CartItem(product: prod, qty: 2)],
        paymentType: 'utang',
        customerId: cust.id,
      );

      final newBalance = await utangRepo.getCustomerBalance(cust.id);
      expect(newBalance, equals(initialBalance + sale.totalCents));
    });

    test('P4-DB-03: Voiding a sale restores stock, logs void_return, reverses utang balance, and prevents double-void', () async {
      final prod = productProv.allProducts.firstWhere((p) => p.stockQty >= 5);
      final cust = utangProv.allCustomers.first;
      final initialStock = prod.stockQty;
      final initialBalance = await utangRepo.getCustomerBalance(cust.id);

      final sale = await saleRepo.createSale(
        items: [CartItem(product: prod, qty: 2)],
        paymentType: 'utang',
        customerId: cust.id,
      );

      // Void the sale
      await saleRepo.voidSale(sale.id, reason: 'Maling pindot');

      // Stock restored
      final restoredProd = await productRepo.getProductById(prod.id);
      expect(restoredProd!.stockQty, equals(initialStock));

      // Void return logged in stock_movements
      final movements = await stockRepo.getMovementsForProduct(prod.id);
      expect(
        movements.any((m) => m.saleId == sale.id && m.type == 'void_return' && m.qtyChange == 2),
        isTrue,
      );

      // Customer utang balance reversed back to initialBalance
      final balanceAfterVoid = await utangRepo.getCustomerBalance(cust.id);
      expect(balanceAfterVoid, equals(initialBalance));

      // Double-void throws ValidationException
      expect(
        () => saleRepo.voidSale(sale.id, reason: 'Double void'),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('Phase 4 - Backend & Domain Logic Tests (P4-BE-01 to P4-BE-04)', () {
    test('P4-BE-01: SaleCalculator computes integer centavo totals, profit, change, and credit-limit warnings', () {
      const p1 = Product(
        id: 1,
        name: 'Pancit Canton',
        priceCents: 1500,
        costCents: 1200,
        stockQty: 20,
      );
      const p2 = Product(
        id: 2,
        name: 'Coke Mismo',
        priceCents: 2000,
        costCents: 1500,
        stockQty: 15,
      );
      final items = [
        CartItem(product: p1, qty: 2), // 3000 cents, profit 600
        CartItem(product: p2, qty: 1), // 2000 cents, profit 500
      ];

      expect(SaleCalculator.calculateItemCount(items), equals(3));
      expect(SaleCalculator.calculateTotalCents(items), equals(5000));
      expect(SaleCalculator.calculateProfitCents(items), equals(1100));
      expect(
        SaleCalculator.calculateChangeCents(
          totalCents: 5000,
          cashReceivedCents: 10000,
          isUtang: false,
        ),
        equals(5000),
      );

      const limitedCust = Customer(
        id: 10,
        name: 'Mang Juan',
        creditLimitCents: 10000, // ₱100 limit
        balanceCents: 7000, // ₱70 existing balance
      );
      expect(
        SaleCalculator.exceedsCreditLimit(customer: limitedCust, saleTotalCents: 5000),
        isTrue,
      );
    });

    test('P4-BE-02: CartProvider enforces stock guards and supports increment, decrement, remove, and undo restore', () {
      const lowStockProd = Product(
        id: 99,
        name: 'Tingi Tuyo',
        priceCents: 1000,
        costCents: 700,
        stockQty: 2,
      );

      expect(cartProv.addToCart(lowStockProd), isTrue);
      expect(cartProv.incrementQty(99), isTrue);
      expect(cartProv.itemCount, equals(2));

      // 3rd unit blocked by stock guard
      expect(cartProv.incrementQty(99), isFalse);
      expect(cartProv.errorMessage, isNotNull);

      // Decrement to 1
      cartProv.decrementQty(99);
      expect(cartProv.itemCount, equals(1));

      // Remove and undo restore
      final removed = cartProv.removeItem(99);
      expect(cartProv.items, isEmpty);
      cartProv.restoreItem(removed!);
      expect(cartProv.itemCount, equals(1));
    });

    test('P4-BE-03: CartProvider validates checkout eligibility for Cash and Utang modes', () {
      final prod = productProv.allProducts.firstWhere((p) => p.stockQty >= 5);
      cartProv.addToCart(prod);

      // Default exact cash -> eligible
      expect(cartProv.canCheckout, isTrue);

      // Insufficient cash -> blocked
      cartProv.setCashReceived(prod.priceCents - 100);
      expect(cartProv.canCheckout, isFalse);

      // Utang without customer -> blocked
      cartProv.setPaymentMode(PaymentMode.utang);
      expect(cartProv.canCheckout, isFalse);

      // Utang with customer -> eligible
      cartProv.selectCustomer(utangProv.allCustomers.first);
      expect(cartProv.canCheckout, isTrue);
    });

    test('P4-BE-04: CartProvider.voidSale voids completed sale and refreshes ProductProvider & UtangProvider', () async {
      final prod = productProv.allProducts.firstWhere((p) => p.stockQty >= 5);
      final initialStock = prod.stockQty;

      cartProv.addToCart(prod);
      cartProv.incrementQty(prod.id); // qty = 2
      final ok = await cartProv.completeSale(
        productProvider: productProv,
        utangProvider: utangProv,
      );
      expect(ok, isTrue);
      expect(cartProv.recentSales.isNotEmpty, isTrue);

      final saleId = cartProv.recentSales.first.id;
      final voidOk = await cartProv.voidSale(
        saleId,
        reason: 'Customer changed mind',
        productProvider: productProv,
        utangProvider: utangProv,
      );
      expect(voidOk, isTrue);

      final prodAfterVoid = productProv.allProducts.firstWhere((p) => p.id == prod.id);
      expect(prodAfterVoid.stockQty, equals(initialStock));
      expect(cartProv.recentSales.first.isVoided, isTrue);
    });
  });

  group('Phase 4 - UX & Screen Tests (P4-UX-01 to P4-UX-05)', () {
    testWidgets('P4-UX-01: SellScreen displays product grid, filters by search, and blocks 0-stock items', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Set one product to 0 stock to verify out-of-stock guard
      final zeroProd = productProv.allProducts.first;
      await productProv.adjustStock(zeroProd.id, 0, reason: 'Test out of stock');

      await tester.pumpWidget(wrapSellScreen());
      await tester.pumpAndSettle();

      // Search for the 0-stock product
      await tester.enterText(find.byType(TextField), zeroProd.name);
      await tester.pumpAndSettle();

      expect(find.text('Out of Stock'), findsOneWidget);

      // Tap the 0-stock product tile -> cart stays empty and snackbar warns
      await tester.tap(find.text('Out of Stock'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(cartProv.items, isEmpty);
      expect(cartProv.errorMessage, contains('Out of stock'));
      expect(find.textContaining('Out of stock'), findsOneWidget);
    });

    testWidgets('P4-UX-02: Cart bottom sheet supports quantity steppers and swipe-to-remove with Undo', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrapSellScreen());
      await tester.pumpAndSettle();

      final targetProd = productProv.filteredProducts.firstWhere((p) => p.stockQty >= 5);
      await tester.tap(find.text(targetProd.name));
      await tester.pumpAndSettle();

      expect(find.text('Tingnan'), findsOneWidget);

      // Open Cart Bottom Sheet
      await tester.tap(find.text('Tingnan'));
      await tester.pumpAndSettle();

      // Increment quantity to 2
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pumpAndSettle();
      expect(cartProv.itemCount, equals(2));

      // Swipe item left to remove
      await tester.drag(find.byType(Dismissible), const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(cartProv.items, isEmpty);

      // Close modal sheet so SnackBar on Scaffold is clickable, then tap Undo
      Navigator.of(tester.element(find.text('Your cart is empty'))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.undo));
      await tester.pumpAndSettle();
      expect(cartProv.itemCount, equals(2));
    });

    testWidgets('P4-UX-03: Cash Checkout flow calculates change (sukli) and displays Benta Matagumpay receipt', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrapSellScreen());
      await tester.pumpAndSettle();

      final targetProd = productProv.filteredProducts.firstWhere((p) => p.stockQty >= 5);
      await tester.tap(find.text(targetProd.name));
      await tester.pumpAndSettle();

      // Open Cart Sheet -> Charge
      await tester.tap(find.text('Tingnan'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining(AppStrings.charge));
      await tester.pumpAndSettle();

      // Select ₱100 quick cash chip
      await tester.tap(find.text('₱100'));
      await tester.pumpAndSettle();
      expect(cartProv.changeCents, equals(10000 - targetProd.priceCents));

      // Complete Sale
      await tester.tap(find.text(AppStrings.confirmSale));
      await tester.pumpAndSettle();

      expect(find.text('Benta Matagumpay!'), findsOneWidget);
      expect(find.text('Sukli sa Mamimili:'), findsOneWidget);
    });

    testWidgets('P4-UX-04: Utang Checkout flow selects customer, shows credit limit warning when exceeded, and completes credit sale', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Set a low credit limit on the first customer so warning triggers
      final firstCust = utangProv.allCustomers.first;
      await customerRepo.updateCustomer(firstCust.copyWith(creditLimitCents: 100)); // ₱1.00 limit
      await utangProv.loadCustomers();

      await tester.pumpWidget(wrapSellScreen());
      await tester.pumpAndSettle();

      final targetProd = productProv.filteredProducts.firstWhere((p) => p.stockQty >= 5);
      await tester.tap(find.text(targetProd.name));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tingnan'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining(AppStrings.charge));
      await tester.pumpAndSettle();

      // Switch to Utang mode
      await tester.tap(find.text(AppStrings.paymentUtang));
      await tester.pumpAndSettle();

      // Select customer
      cartProv.selectCustomer(utangProv.allCustomers.first);
      await tester.pumpAndSettle();

      // Credit limit warning banner visible
      expect(find.textContaining('Lampas sa credit limit'), findsOneWidget);

      // Owner can still override and complete sale
      await tester.tap(find.text(AppStrings.confirmSale));
      await tester.pumpAndSettle();

      expect(find.text('Benta Matagumpay!'), findsOneWidget);
    });

    testWidgets('P4-UX-05: Sales History sheet lists recent sales and voids a sale with confirmation', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final prod = productProv.allProducts.firstWhere((p) => p.stockQty >= 5);
      final initialStock = prod.stockQty;
      await saleRepo.createSale(
        items: [CartItem(product: prod, qty: 2)],
        paymentType: 'cash',
        cashReceivedCents: prod.priceCents * 2,
        changeCents: 0,
      );
      await productProv.loadProducts();

      await tester.pumpWidget(wrapSellScreen());
      await tester.pumpAndSettle();

      // Tap Sales History icon in AppBar
      await tester.tap(find.byIcon(Icons.history_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Kasaysayan ng Benta (Sales History)'), findsOneWidget);
      expect(find.text('I-void'), findsOneWidget);

      // Tap I-void -> confirm dialog
      await tester.tap(find.text('I-void'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Kumpirmahin ang Void'));
      await tester.pumpAndSettle();

      // Verify stock was restored and sale is marked VOIDED
      final restoredProd = productProv.allProducts.firstWhere((p) => p.id == prod.id);
      expect(restoredProd.stockQty, equals(initialStock));
      expect(find.textContaining('VOIDED'), findsOneWidget);
    });
  });
}
