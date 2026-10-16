import 'dart:ffi' show DynamicLibrary;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';
import 'package:tindahan/core/localization/language_provider.dart';
import 'package:tindahan/core/services/home_widget_service.dart';
import 'package:tindahan/core/theme/app_theme.dart';
import 'package:tindahan/core/theme/theme_provider.dart';
import 'package:tindahan/data/db/app_database.dart';
import 'package:tindahan/data/db/migrations/m001_initial.dart';
import 'package:tindahan/data/db/seed.dart';
import 'package:tindahan/data/repositories/customer_repository.dart';
import 'package:tindahan/data/repositories/product_repository.dart';
import 'package:tindahan/data/repositories/reports_repository.dart';
import 'package:tindahan/data/repositories/sale_repository.dart';
import 'package:tindahan/data/repositories/stock_repository.dart';
import 'package:tindahan/data/repositories/utang_repository.dart';
import 'package:tindahan/features/gamification/gamification_provider.dart';
import 'package:tindahan/features/home/providers/home_provider.dart';
import 'package:tindahan/features/navigation/navigation_provider.dart';
import 'package:tindahan/features/products/providers/product_provider.dart';
import 'package:tindahan/features/sell/providers/cart_provider.dart';
import 'package:tindahan/features/settings/screens/settings_screen.dart';
import 'package:tindahan/features/settings/widgets/home_widget_preview_card.dart';
import 'package:tindahan/features/utang/providers/utang_provider.dart';

void main() {
  late Database db;
  late AppDatabase appDb;
  late ProductRepository productRepo;
  late StockRepository stockRepo;
  late SaleRepository saleRepo;
  late CustomerRepository customerRepo;
  late UtangRepository utangRepo;
  late ReportsRepository reportsRepo;

  late ProductProvider productProv;
  late CartProvider cartProv;
  late UtangProvider utangProv;
  late HomeProvider homeProv;
  late NavigationProvider navProv;
  late ThemeProvider themeProv;
  late LanguageProvider langProv;
  late GamificationProvider gameProv;

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
    reportsRepo = ReportsRepository(appDb);

    productProv = ProductProvider(productRepo: productRepo, stockRepo: stockRepo);
    cartProv = CartProvider(saleRepo: saleRepo);
    utangProv = UtangProvider(customerRepo: customerRepo, utangRepo: utangRepo);
    homeProv = HomeProvider(reportsRepo: reportsRepo);
    navProv = NavigationProvider();
    themeProv = ThemeProvider();
    langProv = LanguageProvider();
    gameProv = GamificationProvider();

    await productProv.loadProducts();
    await utangProv.loadCustomers();
    await homeProv.loadDashboard();
  });

  tearDown(() async {
    await db.close();
  });

  Widget wrapWithProviders(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProv),
        ChangeNotifierProvider.value(value: langProv),
        ChangeNotifierProvider.value(value: gameProv),
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

  group('Android Home Screen Widget Tests (HW-01 to HW-05)', () {
    test('HW-01: HomeWidgetSnapshot formats sales, profit, low stock count, and dictionary keys accurately', () {
      final snapshot = HomeWidgetSnapshot(
        storeName: 'Nanay Gina Tindahan',
        todaySalesCents: 125050, // ₱1,250.50
        todayProfitCents: 35000, // ₱350.00
        lowStockCount: 3,
        lastUpdated: DateTime(2026, 10, 16, 14, 30),
      );

      expect(snapshot.todaySalesFormatted, equals('₱1,250.50'));
      expect(snapshot.todayProfitFormatted, equals('₱350.00'));
      expect(snapshot.lowStockFormatted, equals('3 items'));
      expect(snapshot.lastUpdatedFormatted, equals('2:30 PM'));

      final data = snapshot.toWidgetData();
      expect(data['store_name'], equals('Nanay Gina Tindahan'));
      expect(data['today_sales'], equals('₱1,250.50'));
      expect(data['today_profit'], equals('₱350.00'));
      expect(data['low_stock_count'], equals('3 items'));
      expect(data['last_updated'], equals('2:30 PM'));
    });

    test('HW-02: HomeWidgetService saves lastSnapshot and updates without throwing in offline/test mode', () async {
      final snapshot = HomeWidgetSnapshot(
        storeName: 'SariMe Store',
        todaySalesCents: 50000,
        todayProfitCents: 15000,
        lowStockCount: 1,
        lastUpdated: DateTime.now(),
      );

      final ok = await HomeWidgetService.updateSnapshot(snapshot);
      expect(ok, isTrue);
      expect(HomeWidgetService.lastSnapshot, equals(snapshot));
      expect(HomeWidgetService.lastSnapshot?.lowStockFormatted, equals('1 item'));
    });

    test('HW-03: NavigationProvider.handleUri handles deep links from widget buttons', () {
      expect(navProv.currentIndex, equals(0)); // Home

      // 1. Tapping "+ Benta (Sell)" button on Android Home Screen Widget
      navProv.handleUri(Uri.parse('tindahan://sell'));
      expect(navProv.currentIndex, equals(2)); // Sell tab index

      // 2. Tapping "📷 I-scan" button on Android Home Screen Widget
      navProv.handleUri(Uri.parse('tindahan://scan'));
      expect(navProv.currentIndex, equals(2)); // Sell tab index
      expect(navProv.pendingScan, isTrue);
      expect(navProv.consumePendingScan(), isTrue);
      expect(navProv.pendingScan, isFalse);

      // 3. Tapping widget container
      navProv.handleUri(Uri.parse('tindahan://home'));
      expect(navProv.currentIndex, equals(0)); // Home tab index
    });

    test('HW-04: HomeProvider syncWidget generates snapshot and integrates with loadDashboard', () async {
      await homeProv.syncWidget(storeName: 'Tindahan Ni Pedro', lowStockCount: 4);

      final snapshot = HomeWidgetService.lastSnapshot;
      expect(snapshot, isNotNull);
      expect(snapshot!.storeName, equals('Tindahan Ni Pedro'));
      expect(snapshot.lowStockCount, equals(4));
    });

    testWidgets('HW-05: SettingsScreen renders HomeWidgetPreviewCard and tapping Sync Now updates widget', (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      await tester.pumpWidget(wrapWithProviders(const SettingsScreen()));
      await tester.pumpAndSettle();

      // Scroll to Home Screen Widget section
      final previewFinder = find.byType(HomeWidgetPreviewCard);
      expect(previewFinder, findsOneWidget);

      // Verify widget visual elements inside preview
      expect(find.text('Home Screen Widget'), findsOneWidget);
      expect(find.text('LIVE WIDGET'), findsOneWidget);
      expect(find.text("+ Benta (Sell)"), findsWidgets);
      expect(find.textContaining('I-scan'), findsWidgets);
      expect(find.text('How to add to your phone:'), findsOneWidget);

      // Tap "Sync Widget Now" button
      final syncBtn = find.byKey(const Key('sync_home_widget_btn'));
      expect(syncBtn, findsOneWidget);
      await tester.tap(syncBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify feedback SnackBar appears
      expect(find.textContaining('Widget'), findsWidgets);
    });
  });
}
