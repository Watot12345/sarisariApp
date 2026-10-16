import 'dart:ffi' show DynamicLibrary;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';
import 'package:tindahan/core/localization/language_provider.dart';
import 'package:tindahan/core/strings.dart';
import 'package:tindahan/core/theme/app_theme.dart';
import 'package:tindahan/core/theme/theme_provider.dart';
import 'package:tindahan/data/db/app_database.dart';
import 'package:tindahan/data/db/migrations/m001_initial.dart';
import 'package:tindahan/data/db/seed.dart';
import 'package:tindahan/data/models/cart_item.dart';
import 'package:tindahan/data/repositories/customer_repository.dart';
import 'package:tindahan/data/repositories/product_repository.dart';
import 'package:tindahan/data/repositories/reports_repository.dart';
import 'package:tindahan/data/repositories/sale_repository.dart';
import 'package:tindahan/data/repositories/stock_repository.dart';
import 'package:tindahan/data/repositories/utang_repository.dart';
import 'package:tindahan/features/gamification/gamification_provider.dart';
import 'package:tindahan/features/home/providers/home_provider.dart';
import 'package:tindahan/features/home/screens/home_screen.dart';
import 'package:tindahan/features/navigation/navigation_provider.dart';
import 'package:tindahan/features/products/providers/product_provider.dart';
import 'package:tindahan/features/products/screens/products_screen.dart';
import 'package:tindahan/features/reports/screens/reports_screen.dart';
import 'package:tindahan/features/sell/providers/cart_provider.dart';
import 'package:tindahan/features/sell/screens/sell_screen.dart';
import 'package:tindahan/features/utang/providers/utang_provider.dart';
import 'package:tindahan/features/utang/screens/utang_screen.dart';

void main() {
  late Database db;
  late AppDatabase appDb;
  late SaleRepository saleRepo;
  late ReportsRepository reportsRepo;
  late ProductRepository productRepo;
  late StockRepository stockRepo;
  late UtangRepository utangRepo;
  late CustomerRepository customerRepo;

  late NavigationProvider navProv;
  late HomeProvider homeProv;
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
    reportsRepo = ReportsRepository(appDb);
    productRepo = ProductRepository(appDb);
    stockRepo = StockRepository(appDb);
    utangRepo = UtangRepository(appDb);
    customerRepo = CustomerRepository(appDb);

    navProv = NavigationProvider();
    homeProv = HomeProvider(reportsRepo: reportsRepo);
    productProv = ProductProvider(productRepo: productRepo, stockRepo: stockRepo);
    cartProv = CartProvider(saleRepo: saleRepo);
    utangProv = UtangProvider(customerRepo: customerRepo, utangRepo: utangRepo);

    await homeProv.loadDashboard();
    await productProv.loadProducts();
    await utangProv.loadCustomers();
  });

  tearDown(() async {
    await db.close();
  });

  Widget wrapWithProviders(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => GamificationProvider()),
        ChangeNotifierProvider.value(value: navProv),
        ChangeNotifierProvider.value(value: homeProv),
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

  group('UX & Screen Tests (UX-01 to UX-06)', () {
    testWidgets('UX-01: Home Dashboard displays revenue cards, profit, utang summary, and quick actions', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Record a sample sale first so today's sales & profit are non-zero
      final p1 = productProv.allProducts.first;
      await saleRepo.createSale(
        items: [CartItem(product: p1, qty: 2)],
        paymentType: 'cash',
        cashReceivedCents: 10000,
        changeCents: 10000 - (2 * p1.priceCents),
      );
      await homeProv.loadDashboard();

      await tester.pumpWidget(wrapWithProviders(const HomeScreen()));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.todaySales), findsOneWidget);
      expect(find.text(AppStrings.estProfit), findsOneWidget);
      expect(find.text(AppStrings.itemsSold), findsOneWidget);
      expect(find.text(AppStrings.totalUtang), findsOneWidget);
      expect(find.text(AppStrings.actionNewSale), findsOneWidget);
    });

    testWidgets('UX-02: Reports Screen switches timeframes (Today / This Week / This Month) and displays revenue, profit & top sellers', (tester) async {
      final p1 = productProv.allProducts.first;
      await saleRepo.createSale(
        items: [CartItem(product: p1, qty: 4)],
        paymentType: 'cash',
        cashReceivedCents: 10000,
        changeCents: 0,
      );
      await homeProv.loadDashboard();

      await tester.pumpWidget(wrapWithProviders(const ReportsScreen()));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.reportsTitle), findsOneWidget);
      expect(find.text(AppStrings.grossRevenue), findsOneWidget);
      expect(find.text(AppStrings.netProfit), findsOneWidget);
      expect(find.text(AppStrings.topSellers), findsOneWidget);
      expect(find.text(p1.name), findsOneWidget);

      // Switch to This Week and This Month tabs
      await tester.tap(find.text(AppStrings.tabWeek));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.grossRevenue), findsOneWidget);

      await tester.tap(find.text(AppStrings.tabMonth));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.netProfit), findsOneWidget);
    });

    testWidgets('UX-03: POS Sell Screen searches products, adds item to cart on tap, and shows Floating Cart Bar', (tester) async {
      await tester.pumpWidget(wrapWithProviders(const SellScreen()));
      await tester.pumpAndSettle();

      // Search for "Lucky Me"
      await tester.enterText(find.byType(TextField), 'Lucky Me');
      await tester.pumpAndSettle();

      expect(find.textContaining('Lucky Me Pancit Canton'), findsWidgets);

      // Tap the first product card to add to cart
      await tester.tap(find.textContaining('Lucky Me Pancit Canton').first);
      await tester.pumpAndSettle();

      // Verify item is in cart and Floating Cart Bar appears with "Tingnan" button
      expect(cartProv.itemCount, equals(1));
      expect(find.text('x1'), findsOneWidget);
      expect(find.text('Tingnan'), findsOneWidget);
    });

    testWidgets('UX-04: POS Checkout Bottom Sheet opens payment modal, calculates change, and completes sale', (tester) async {
      await tester.pumpWidget(wrapWithProviders(const SellScreen()));
      await tester.pumpAndSettle();

      // Add product to cart
      final firstProd = productProv.filteredProducts.first;
      cartProv.addToCart(firstProd);
      await tester.pumpAndSettle();

      // Open Cart Bottom Sheet via "Tingnan"
      await tester.tap(find.text('Tingnan'));
      await tester.pumpAndSettle();

      expect(find.textContaining(AppStrings.cartTitle), findsOneWidget);

      // Tap Charge button to open Payment Sheet
      await tester.tap(find.textContaining(AppStrings.charge));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.paymentTitle), findsOneWidget);
      expect(find.text(AppStrings.change), findsOneWidget);

      // Tap Complete Sale
      await tester.tap(find.text(AppStrings.confirmSale));
      await tester.pumpAndSettle();

      // Cart should now be empty after completed sale
      expect(cartProv.items.isEmpty, isTrue);
    });

    testWidgets('UX-05: Products Inventory Screen filters by Low Stock and restocks product via dialog', (tester) async {
      await tester.pumpWidget(wrapWithProviders(const ProductsScreen()));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.productsTitle), findsOneWidget);

      // Toggle Low Stock filter chip ("Mababa (N)")
      await tester.tap(find.textContaining('Mababa'));
      await tester.pumpAndSettle();
      expect(productProv.filterLowStockOnly, isTrue);

      // Untoggle Low Stock filter chip to see all products
      await tester.tap(find.textContaining('Mababa'));
      await tester.pumpAndSettle();

      final targetProd = productProv.filteredProducts.first;
      final initialQty = targetProd.stockQty;

      // Tap restock button on the first product
      await tester.tap(find.text('Restock').first);
      await tester.pumpAndSettle();

      expect(find.text('Quick Restock: ${targetProd.name}'), findsOneWidget);

      // Confirm +10 default restock
      await tester.tap(find.text('I-kumpirma'));
      await tester.pumpAndSettle();

      final updatedProd = productProv.allProducts.firstWhere((p) => p.id == targetProd.id);
      expect(updatedProd.stockQty, equals(initialQty + 10));
    });

    testWidgets('UX-06: Utang Screen searches customers and records utang payment via bottom sheet', (tester) async {
      await tester.pumpWidget(wrapWithProviders(const UtangScreen()));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.utangTitle), findsOneWidget);
      expect(find.text(AppStrings.totalReceivables), findsOneWidget);

      // Find a customer with positive utang balance
      final debtor = utangProv.allCustomers.firstWhere((c) => c.balanceCents > 0);
      final initialBalance = debtor.balanceCents;

      // Filter by debtor name
      await tester.enterText(find.byType(TextField), debtor.name);
      await tester.pumpAndSettle();

      expect(find.text(debtor.displayName), findsOneWidget);

      // Tap "Bayad" button
      await tester.tap(find.text('Bayad').first);
      await tester.pumpAndSettle();

      expect(find.text('Pay Utang: ${debtor.displayName}'), findsOneWidget);

      // Select ₱50 chip and confirm payment
      await tester.tap(find.text('₱50'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirm Payment'));
      await tester.pumpAndSettle();

      final updatedDebtor = utangProv.allCustomers.firstWhere((c) => c.id == debtor.id);
      expect(updatedDebtor.balanceCents, equals(initialBalance - 5000));
    });
  });
}
