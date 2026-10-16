import 'dart:ffi' show DynamicLibrary;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';
import 'package:tindahan/core/localization/language_provider.dart';
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
import 'package:tindahan/features/gamification/screens/store_avatar_screen.dart';
import 'package:tindahan/features/gamification/widgets/animated_store_avatar.dart';
import 'package:tindahan/features/home/providers/home_provider.dart';
import 'package:tindahan/features/home/screens/home_screen.dart';
import 'package:tindahan/features/navigation/navigation_provider.dart';
import 'package:tindahan/features/onboarding/providers/onboarding_provider.dart';
import 'package:tindahan/features/onboarding/screens/policy_consent_screen.dart';
import 'package:tindahan/features/products/providers/product_provider.dart';
import 'package:tindahan/features/sell/providers/cart_provider.dart';
import 'package:tindahan/features/settings/screens/settings_screen.dart';
import 'package:tindahan/features/utang/providers/utang_provider.dart';

void main() {
  late Database db;
  late AppDatabase appDb;
  late SaleRepository saleRepo;
  late ReportsRepository reportsRepo;
  late ProductRepository productRepo;
  late StockRepository stockRepo;
  late UtangRepository utangRepo;
  late CustomerRepository customerRepo;

  late LanguageProvider langProv;
  late GamificationProvider gameProv;
  late ThemeProvider themeProv;
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

    themeProv = ThemeProvider();
    langProv = LanguageProvider();
    gameProv = GamificationProvider();
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

  Widget wrapScreen(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => OnboardingProvider()),
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

  group('Language (English & Tagalog) and Gamification Tests (LG-01 to LG-05)', () {
    test('LG-01: LanguageProvider switches between English and Tagalog accurately', () {
      expect(langProv.isEnglish, isTrue);
      expect(langProv.todaysSales, equals("Today's Sales"));
      expect(langProv.navHome, equals('Home'));
      expect(langProv.levelTitle(1), equals('Starter Storekeeper'));

      langProv.toggleLanguage();
      expect(langProv.isTagalog, isTrue);
      expect(langProv.todaysSales, equals('Benta Ngayon'));
      expect(langProv.navHome, equals('Tahanan'));
      expect(langProv.levelTitle(1), equals('Baguhang Tindera'));
      expect(langProv.levelTitle(5), equals('Alamat ng Sari-Sari'));
    });

    test('LG-02: GamificationProvider calculates XP, Levels 1-5, Daily Goal Progress, and Badges', () {
      // Initial state: 0 sales, 0 items sold, 4 low-stock items -> 50 base XP -> Level 1
      final initialXp = gameProv.calculateTotalXp(
        todaySalesCents: 0,
        itemsSoldToday: 0,
        lowStockCount: 4,
      );
      expect(initialXp, equals(50));
      expect(gameProv.getLevelFromXp(initialXp), equals(1));
      expect(gameProv.getDailyGoalProgress(0), equals(0.0));

      // Reach daily goal (₱1,600 today sales = 160,000 cents), 6 items sold, 1 low-stock item
      final activeXp = gameProv.calculateTotalXp(
        todaySalesCents: 160000,
        itemsSoldToday: 6,
        lowStockCount: 1,
      );
      expect(gameProv.getDailyGoalProgress(160000), equals(1.0));
      expect(gameProv.getLevelFromXp(activeXp), greaterThanOrEqualTo(4));

      // Verify all 4 badges unlock when conditions are met
      final badges = gameProv.getBadges(
        todaySalesCents: 160000,
        todayProfitCents: 35000,
        itemsSoldToday: 6,
        lowStockCount: 1,
      );
      expect(badges.where((b) => b.isUnlocked).length, equals(4));
    });

    testWidgets('LG-03: HomeScreen focuses on management, shows compact Avatar Emoticon button, and opens StoreAvatarScreen on tap', (tester) async {
      tester.view.physicalSize = const Size(412, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Record a sale so First Sale badge unlocks and XP increases
      final p1 = productProv.allProducts.first;
      await saleRepo.createSale(
        items: [CartItem(product: p1, qty: 2)],
        paymentType: 'cash',
        cashReceivedCents: p1.priceCents * 2,
        changeCents: 0,
      );
      await homeProv.loadDashboard();

      await tester.pumpWidget(wrapScreen(const HomeScreen()));
      await tester.pumpAndSettle();

      // HomeScreen shows management metrics in English by default
      expect(find.text("Today's Sales"), findsOneWidget);
      expect(find.byType(StoreAvatarAppBarButton), findsOneWidget);

      // Verify language toggle chip and theme toggle button have been removed from Home AppBar
      expect(find.text('EN'), findsNothing);
      expect(find.text('TL'), findsNothing);
      expect(find.byIcon(Icons.light_mode_rounded), findsNothing);
      expect(find.byIcon(Icons.dark_mode_rounded), findsNothing);

      // Verify HomeScreen dynamically updates when language is changed
      langProv.toggleLanguage();
      await tester.pumpAndSettle();
      expect(find.text('Benta Ngayon'), findsOneWidget);

      langProv.toggleLanguage();
      await tester.pumpAndSettle();
      expect(find.text("Today's Sales"), findsOneWidget);

      // Tap the compact Avatar Emoticon button in the AppBar to open StoreAvatarScreen
      await tester.tap(find.byKey(const Key('store_avatar_appbar_button')));
      await tester.pumpAndSettle();

      // Dedicated StoreAvatarScreen opens with moving hero avatar, Daily Sales Goal, and Badges
      expect(find.byType(StoreAvatarScreen), findsOneWidget);
      expect(find.byKey(const Key('hero_animated_store_avatar')), findsOneWidget);
      expect(find.text('Store Avatar & Progress'), findsOneWidget);
      expect(find.text('Daily Sales Goal'), findsOneWidget);
      expect(find.textContaining('Store Badges'), findsOneWidget);

      // Tap the hero animated avatar to trigger cheer animation & cycle tip quote
      await tester.tap(find.byKey(const Key('hero_animated_store_avatar')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Every recorded sale'), findsOneWidget);
    });

    testWidgets('LG-04: SettingsScreen allows switching Language, Daily Sales Goal, and Theme Mode', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrapScreen(const SettingsScreen()));
      await tester.pumpAndSettle();

      // Tap Language tile
      await tester.tap(find.text('Language'));
      await tester.pumpAndSettle();

      // Select Tagalog (Filipino)
      await tester.tap(find.text('Tagalog (Filipino)'));
      await tester.pumpAndSettle();

      expect(langProv.isTagalog, isTrue);
      expect(find.text('Wika (Language)'), findsOneWidget);

      // Tap Daily Sales Goal tile (now in Tagalog: 'Target Benta Ngayon')
      await tester.tap(find.text('Target Benta Ngayon'));
      await tester.pumpAndSettle();

      // Select ₱2000 / araw
      await tester.tap(find.text('₱2000 / araw'));
      await tester.pumpAndSettle();

      expect(gameProv.dailySalesGoalCents, equals(200000));
      expect(find.text('₱2000'), findsOneWidget);

      // Dark Mode / Light Mode button in SettingsScreen
      expect(themeProv.themeMode, equals(ThemeMode.system));
      final themeToggleBtn = find.byTooltip('Switch to Dark Mode');
      expect(themeToggleBtn, findsOneWidget);
      await tester.tap(themeToggleBtn);
      await tester.pumpAndSettle();
      expect(themeProv.themeMode, equals(ThemeMode.dark));
    });

    testWidgets('LG-05: PolicyConsentScreen renders in English by default and supports language toggle', (tester) async {
      tester.view.physicalSize = const Size(412, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrapScreen(const PolicyConsentScreen()));
      await tester.pumpAndSettle();

      // Verify English consent content is displayed by default
      expect(find.text('100% Offline & Private (Zero Internet)'), findsOneWidget);
      expect(find.text('Camera Access (Barcode Scanner)'), findsOneWidget);
      expect(find.text('I understand and accept the SariMe Privacy Policy and Offline Terms.'), findsOneWidget);
      expect(find.text('I Agree & Start Store'), findsOneWidget);

      // Toggle to Tagalog and verify Tagalog consent text
      await tester.tap(find.text('English (EN)'));
      await tester.pumpAndSettle();
      expect(find.text('100% Offline & Pribado (Zero Internet)'), findsOneWidget);
      expect(find.text('Sumasang-ayon Ako at Magsimula'), findsOneWidget);
    });
  });
}
