import 'dart:ffi' show DynamicLibrary;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';
import 'package:tindahan/core/localization/language_provider.dart';
import 'package:tindahan/core/services/notification_service.dart';
import 'package:tindahan/core/theme/app_theme.dart';
import 'package:tindahan/core/theme/theme_provider.dart';
import 'package:tindahan/data/db/app_database.dart';
import 'package:tindahan/data/db/migrations/m001_initial.dart';
import 'package:tindahan/data/db/seed.dart';
import 'package:tindahan/data/models/product.dart';
import 'package:tindahan/data/repositories/customer_repository.dart';
import 'package:tindahan/data/repositories/product_repository.dart';
import 'package:tindahan/data/repositories/reports_repository.dart';
import 'package:tindahan/data/repositories/sale_repository.dart';
import 'package:tindahan/data/repositories/stock_repository.dart';
import 'package:tindahan/data/repositories/utang_repository.dart';
import 'package:tindahan/features/gamification/gamification_provider.dart';
import 'package:tindahan/features/home/providers/home_provider.dart';
import 'package:tindahan/features/navigation/navigation_provider.dart';
import 'package:tindahan/features/notifications/providers/notification_provider.dart';
import 'package:tindahan/features/notifications/widgets/notification_bell_button.dart';
import 'package:tindahan/features/notifications/widgets/notifications_sheet.dart';
import 'package:tindahan/features/onboarding/providers/onboarding_provider.dart';
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

  late NavigationProvider navProv;
  late HomeProvider homeProv;
  late ProductProvider productProv;
  late CartProvider cartProv;
  late UtangProvider utangProv;
  late NotificationProvider notifProv;
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
    notifProv = NotificationProvider();
    langProv = LanguageProvider();
    gameProv = GamificationProvider();

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
        ChangeNotifierProvider(create: (_) => OnboardingProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider.value(value: langProv),
        ChangeNotifierProvider.value(value: gameProv),
        ChangeNotifierProvider.value(value: notifProv),
        ChangeNotifierProvider.value(value: navProv),
        ChangeNotifierProvider.value(value: homeProv),
        ChangeNotifierProvider.value(value: productProv),
        ChangeNotifierProvider.value(value: cartProv),
        ChangeNotifierProvider.value(value: utangProv),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          appBar: AppBar(
            title: const Text('Test AppBar'),
            actions: const [NotificationBellButton()],
          ),
          body: child,
        ),
      ),
    );
  }

  group('Push Notifications & In-App Notification Center Tests (NOTIF-01 to NOTIF-06)', () {
    test('NOTIF-01: AppNotification model provides distinct icon, color accent, formatted time, and copyWith', () {
      final notif1 = AppNotification(
        id: 1,
        title: 'Low Stock Alert',
        body: 'Lucky Me is running low',
        type: NotificationType.lowStock,
      );

      final notif2 = AppNotification(
        id: 2,
        title: 'Goal Hit',
        body: 'Target achieved',
        type: NotificationType.dailyGoal,
      );

      final notif3 = AppNotification(
        id: 3,
        title: 'Utang Reminder',
        body: 'Aling Nena balance',
        type: NotificationType.utangReminder,
      );

      expect(notif1.icon, equals(Icons.warning_amber_rounded));
      expect(notif1.color, equals(AppTheme.dangerRed));
      expect(notif1.formattedTime, equals('Just now'));
      expect(notif1.isRead, isFalse);

      expect(notif2.icon, equals(Icons.emoji_events_rounded));
      expect(notif2.color, equals(const Color(0xFFF59E0B)));

      expect(notif3.icon, equals(Icons.menu_book_rounded));
      expect(notif3.color, equals(AppTheme.accentBlue));

      final updated = notif1.copyWith(isRead: true);
      expect(updated.isRead, isTrue);
      expect(updated.title, equals(notif1.title));
    });

    test('NOTIF-02: NotificationService handles test environment without stalling and logs dispatched alerts', () async {
      final service = NotificationService.instance;
      expect(service.isTestMode, isTrue);

      await service.initialize();
      expect(await service.requestPermissions(), isTrue);

      await service.showNotification(
        id: 99,
        title: 'Test Notification',
        body: 'Dispatched successfully',
        type: NotificationType.systemAlert,
      );

      expect(service.dispatched.any((n) => n.id == 99), isTrue);
      expect(service.dispatched.firstWhere((n) => n.id == 99).title, equals('Test Notification'));
    });

    test('NOTIF-03: NotificationProvider tracks notifications list, calculates unreadCount, marks read, and clears', () async {
      final prov = NotificationProvider();
      expect(prov.notifications.isNotEmpty, isTrue);
      final initialUnread = prov.unreadCount;
      expect(initialUnread, greaterThan(0));

      await prov.sendNotification(
        title: 'New Stock Added',
        body: 'Pancit Canton was restocked +20 pcs',
        type: NotificationType.saleSuccess,
      );

      expect(prov.unreadCount, equals(initialUnread + 1));
      expect(prov.notifications.first.title, equals('New Stock Added'));

      // Mark first as read
      prov.markAsRead(prov.notifications.first.id);
      expect(prov.unreadCount, equals(initialUnread));

      // Mark all as read
      prov.markAllAsRead();
      expect(prov.unreadCount, equals(0));
      expect(prov.hasUnread, isFalse);

      // Clear all
      prov.clearAll();
      expect(prov.notifications, isEmpty);
      expect(prov.unreadCount, equals(0));
    });

    test('NOTIF-04: NotificationProvider triggers low stock and daily goal notifications with distinct text and icon', () async {
      final prov = NotificationProvider();
      prov.clearAll();

      const lowProd = Product(
        id: 77,
        name: 'Great Taste White Twin',
        priceCents: 1500,
        costCents: 1200,
        stockQty: 2,
        lowStockLevel: 5,
      );

      await prov.checkLowStockAlerts([lowProd], isTagalog: false);
      expect(prov.notifications.length, equals(1));
      expect(prov.notifications.first.type, equals(NotificationType.lowStock));
      expect(prov.notifications.first.title, contains('Low Stock Alert: Great Taste White Twin'));
      expect(prov.notifications.first.body, contains('Only 2 items left'));

      // Check daily goal notification
      await prov.checkDailyGoalAlert(
        currentSalesCents: 150000,
        goalCents: 100000,
        isTagalog: false,
      );

      expect(prov.notifications.length, equals(2));
      expect(prov.notifications.first.type, equals(NotificationType.dailyGoal));
      expect(prov.notifications.first.title, contains('Daily Sales Goal Reached!'));
    });

    testWidgets('NOTIF-05: NotificationBellButton renders unread badge count and opens NotificationsSheet on tap', (tester) async {
      await tester.pumpWidget(wrapWithProviders(const Center(child: Text('Home Content'))));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('notification_bell_btn')), findsOneWidget);
      expect(find.byKey(const Key('notification_badge_count')), findsOneWidget);

      // Tap Notification Bell
      await tester.tap(find.byKey(const Key('notification_bell_btn')));
      await tester.pumpAndSettle();

      // NotificationsSheet should be visible
      expect(find.byType(NotificationsSheet), findsOneWidget);
      expect(find.text('Store Notifications'), findsOneWidget);
      // Dev test push button should be removed in release mode
      expect(find.byKey(const Key('send_test_push_btn')), findsNothing);

      // Tap "Mark all read"
      await tester.tap(find.byKey(const Key('mark_all_read_btn')));
      await tester.pumpAndSettle();

      expect(notifProv.unreadCount, equals(0));
    });

    testWidgets('NOTIF-06: SettingsScreen displays Notifications & Alerts tile and opens sheet without dev test button', (tester) async {
      tester.view.physicalSize = const Size(412, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrapWithProviders(const SettingsScreen()));
      await tester.pumpAndSettle();

      // Scroll to Notifications card
      await tester.scrollUntilVisible(
        find.byKey(const Key('settings_notifications_tile')),
        200,
      );
      await tester.pumpAndSettle();

      expect(find.text('Notifications & Alerts', skipOffstage: false), findsOneWidget);
      expect(find.byKey(const Key('settings_notifications_tile')), findsOneWidget);
      // Dev test button is removed for release
      expect(find.byKey(const Key('settings_quick_test_notif_btn')), findsNothing);

      // Tap Notifications tile to open sheet
      await tester.tap(find.byKey(const Key('settings_notifications_tile')));
      await tester.pumpAndSettle();

      expect(find.byType(NotificationsSheet), findsOneWidget);
    });
  });
}
