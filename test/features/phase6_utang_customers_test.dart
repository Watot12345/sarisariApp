import 'dart:ffi' show DynamicLibrary;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';
import 'package:tindahan/core/exceptions.dart';
import 'package:tindahan/core/strings.dart';
import 'package:tindahan/core/theme/app_theme.dart';
import 'package:tindahan/core/theme/theme_provider.dart';
import 'package:tindahan/data/db/app_database.dart';
import 'package:tindahan/data/db/migrations/m001_initial.dart';
import 'package:tindahan/data/db/seed.dart';
import 'package:tindahan/core/localization/language_provider.dart';
import 'package:tindahan/data/models/cart_item.dart';
import 'package:tindahan/data/models/customer.dart';
import 'package:tindahan/data/models/utang_entry.dart';
import 'package:tindahan/data/repositories/customer_repository.dart';
import 'package:tindahan/data/repositories/product_repository.dart';
import 'package:tindahan/data/repositories/sale_repository.dart';
import 'package:tindahan/data/repositories/stock_repository.dart';
import 'package:tindahan/data/repositories/utang_repository.dart';
import 'package:tindahan/domain/utang_ledger.dart';
import 'package:tindahan/features/gamification/gamification_provider.dart';
import 'package:tindahan/features/products/providers/product_provider.dart';
import 'package:tindahan/features/sell/providers/cart_provider.dart';
import 'package:tindahan/features/utang/providers/utang_provider.dart';
import 'package:tindahan/features/utang/screens/utang_screen.dart';
import 'package:tindahan/features/utang/widgets/add_edit_customer_sheet.dart';
import 'package:tindahan/features/utang/widgets/customer_detail_sheet.dart';
import 'package:tindahan/features/utang/widgets/record_payment_sheet.dart';

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
  late ThemeProvider themeProv;

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
    themeProv = ThemeProvider();

    await productProv.loadProducts();
    await utangProv.loadCustomers();
  });

  tearDown(() async {
    await db.close();
  });

  Widget wrapWithProviders(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProv),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => GamificationProvider()),
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

  group('Phase 6 - Database Tests (P6-DB-01 to P6-DB-03)', () {
    test('P6-DB-01: Utang balance calculation accurately computes sum of charges minus payments across multiple entries', () async {
      // Create a fresh test customer with 0 initial balance
      final customerId = await customerRepo.insertCustomer(const Customer(
        id: 0,
        name: 'Tatay Berting',
        creditLimitCents: 50000,
        balanceCents: 0,
      ));

      expect(await utangRepo.getCustomerBalance(customerId), equals(0));

      // Charge 1: ₱100 (10000 cents)
      await utangRepo.recordCharge(customerId, 10000, note: 'Tindahan grocery items');
      expect(await utangRepo.getCustomerBalance(customerId), equals(10000));

      // Charge 2: ₱50 (5000 cents)
      await utangRepo.recordCharge(customerId, 5000, note: 'Gasul refill share');
      expect(await utangRepo.getCustomerBalance(customerId), equals(15000));

      // Payment 1: ₱60 (6000 cents)
      await utangRepo.recordPayment(customerId, 6000, note: 'Partial payment on payday');
      expect(await utangRepo.getCustomerBalance(customerId), equals(9000));

      // Verify entries list returns all 3 entries in chronological order
      final entries = await utangRepo.getEntriesForCustomer(customerId);
      expect(entries.length, equals(3));
      expect(entries[0].type, equals('charge'));
      expect(entries[0].amountCents, equals(10000));
      expect(entries[1].type, equals('charge'));
      expect(entries[1].amountCents, equals(5000));
      expect(entries[2].type, equals('payment'));
      expect(entries[2].amountCents, equals(6000));
    });

    test('P6-DB-02: Partial payment reduces customer balance, and payment exceeding balance throws ValidationException', () async {
      final customerId = await customerRepo.insertCustomer(const Customer(
        id: 0,
        name: 'Nanay Coring',
        creditLimitCents: 30000,
        balanceCents: 0,
      ));

      await utangRepo.recordCharge(customerId, 8000, note: 'Coffee and sugar');
      expect(await utangRepo.getCustomerBalance(customerId), equals(8000));

      // Valid partial payment of ₱30 (3000 cents)
      await utangRepo.recordPayment(customerId, 3000, note: 'Partial bayad');
      expect(await utangRepo.getCustomerBalance(customerId), equals(5000));

      // Attempt payment of 0 or negative centavos
      expect(
        () async => await utangRepo.recordPayment(customerId, 0),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () async => await utangRepo.recordPayment(customerId, -500),
        throwsA(isA<ValidationException>()),
      );

      // Attempt overpayment exceeding current ₱50 balance (e.g. ₱60 / 6000 cents)
      expect(
        () async => await utangRepo.recordPayment(customerId, 6000),
        throwsA(isA<ValidationException>()),
      );

      // Remaining balance remains untouched after rejected payments
      expect(await utangRepo.getCustomerBalance(customerId), equals(5000));

      // Pay exact full balance: ₱50 (5000 cents)
      await utangRepo.recordPayment(customerId, 5000, note: 'Full settlement');
      expect(await utangRepo.getCustomerBalance(customerId), equals(0));
    });

    test('P6-DB-03: Voided sale charges are excluded from customer utang balance and ledger history', () async {
      final customerId = await customerRepo.insertCustomer(const Customer(
        id: 0,
        name: 'Tito Boy',
        creditLimitCents: 50000,
        balanceCents: 0,
      ));

      // Initial charge outside POS
      await utangRepo.recordCharge(customerId, 2000, note: 'Prior utang');
      expect(await utangRepo.getCustomerBalance(customerId), equals(2000));

      // Complete a sale on credit for customer
      final product = (await productRepo.getProducts()).first;
      final sale = await saleRepo.createSale(
        items: [CartItem(product: product, qty: 2)],
        paymentType: 'utang',
        customerId: customerId,
      );

      // Balance now includes both the prior utang and the credit sale
      final balanceAfterSale = await utangRepo.getCustomerBalance(customerId);
      expect(balanceAfterSale, equals(2000 + (product.priceCents * 2)));

      // Void the sale
      await saleRepo.voidSale(sale.id, reason: 'Customer cancelled transaction');

      // Voided sale charge is automatically excluded from balance
      final balanceAfterVoid = await utangRepo.getCustomerBalance(customerId);
      expect(balanceAfterVoid, equals(2000));

      // And excluded from customer's ledger timeline
      final entries = await utangRepo.getEntriesForCustomer(customerId);
      expect(entries.length, equals(1));
      expect(entries.first.note, equals('Prior utang'));
    });
  });

  group('Phase 6 - Backend & Domain Logic Tests (P6-BE-01 to P6-BE-03)', () {
    test('P6-BE-01: UtangLedger calculates running balance timeline and validates non-zero / non-excess payments', () {
      final entries = [
        const UtangEntry(
          id: 1,
          customerId: 10,
          type: 'charge',
          amountCents: 10000,
          createdAt: '2026-10-01T08:00:00Z',
        ),
        const UtangEntry(
          id: 2,
          customerId: 10,
          type: 'charge',
          amountCents: 5000,
          createdAt: '2026-10-02T09:00:00Z',
        ),
        const UtangEntry(
          id: 3,
          customerId: 10,
          type: 'payment',
          amountCents: 4000,
          createdAt: '2026-10-03T10:00:00Z',
        ),
      ];

      // Net balance
      expect(UtangLedger.balanceOf(entries), equals(11000));

      // Running ledger chronological progression
      final timeline = UtangLedger.buildRunningLedger(entries);
      expect(timeline.length, equals(3));
      expect(timeline[0].runningBalanceCents, equals(10000));
      expect(timeline[1].runningBalanceCents, equals(15000));
      expect(timeline[2].runningBalanceCents, equals(11000));

      // Validation logic
      expect(
        UtangLedger.validatePayment(amountCents: 0, balanceCents: 11000),
        equals('Payment must be greater than ₱0.00'),
      );
      expect(
        UtangLedger.validatePayment(amountCents: -500, balanceCents: 11000),
        equals('Payment must be greater than ₱0.00'),
      );
      expect(
        UtangLedger.validatePayment(amountCents: 5000, balanceCents: 0),
        equals('This customer has no outstanding utang'),
      );
      expect(
        UtangLedger.validatePayment(amountCents: 12000, balanceCents: 11000),
        contains('Payment cannot exceed balance'),
      );
      expect(
        UtangLedger.validatePayment(amountCents: 5000, balanceCents: 11000),
        isNull,
      );
      expect(
        UtangLedger.validatePayment(amountCents: 11000, balanceCents: 11000),
        isNull,
      );
    });

    test('P6-BE-02: UtangProvider validates customer inputs on add and update', () async {
      // Empty name validation
      final fail1 = await utangProv.addCustomer(name: '   ');
      expect(fail1, isNull);
      expect(utangProv.errorMessage, equals('Customer name is required'));

      // Negative credit limit validation
      final fail2 = await utangProv.addCustomer(name: 'Valid Name', creditLimitCents: -100);
      expect(fail2, isNull);
      expect(utangProv.errorMessage, equals('Credit limit cannot be negative'));

      // Successful addition
      final newId = await utangProv.addCustomer(
        name: 'Ate Linda',
        nickname: 'Gulay Vendor',
        phone: '09191234567',
        creditLimitCents: 75000,
        notes: 'Pays every Sunday',
      );
      expect(newId, isNotNull);

      final customer = utangProv.customerById(newId!);
      expect(customer, isNotNull);
      expect(customer!.name, equals('Ate Linda'));
      expect(customer.nickname, equals('Gulay Vendor'));
      expect(customer.displayName, equals('Ate Linda (Gulay Vendor)'));
      expect(customer.creditLimitCents, equals(75000));

      // Update customer
      final updated = await utangProv.updateCustomer(customer.copyWith(
        notes: 'Now pays every Monday',
      ));
      expect(updated, isTrue);
      expect(utangProv.customerById(newId)!.notes, equals('Now pays every Monday'));
    });

    test('P6-BE-03: UtangLedger.buildStatement formats clean plain-text receipt with store name, itemized lines, and balance', () {
      const customer = Customer(
        id: 7,
        name: 'Pedro Penduko',
        nickname: 'Engkanto',
        balanceCents: 3500,
      );

      final entries = [
        const UtangEntry(
          id: 1,
          customerId: 7,
          type: 'charge',
          amountCents: 5000,
          createdAt: '2026-10-10T12:00:00Z',
        ),
        const UtangEntry(
          id: 2,
          customerId: 7,
          type: 'payment',
          amountCents: 1500,
          createdAt: '2026-10-12T15:30:00Z',
        ),
      ];

      final statement = UtangLedger.buildStatement(
        storeName: 'Nanay Nena Sari-Sari Store',
        customer: customer,
        entries: entries,
        now: DateTime(2026, 10, 16),
      );

      expect(statement, contains('Nanay Nena Sari-Sari Store — Utang Statement'));
      expect(statement, contains('Customer: Pedro Penduko (Engkanto)'));
      expect(statement, contains('Date: 2026-10-16'));
      expect(statement, contains('2026-10-10  Utang  +₱50.00'));
      expect(statement, contains('2026-10-12  Bayad  -₱15.00'));
      expect(statement, contains('Current Balance: ₱35.00'));
      expect(statement, contains('Salamat po!'));
    });
  });

  group('Phase 6 - UX & Screen Tests (P6-UX-01 to P6-UX-04)', () {
    testWidgets('P6-UX-01: UtangScreen displays customers, live balance, risk chips, and search filtering', (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      await tester.pumpWidget(wrapWithProviders(const UtangScreen()));
      await tester.pumpAndSettle();

      // Verify header receivables & customer list
      expect(find.text(AppStrings.utangTitle), findsOneWidget);
      expect(find.text(AppStrings.totalReceivables), findsOneWidget);

      // Verify seeded customers are rendered
      expect(find.textContaining('Elena Santos'), findsOneWidget);
      expect(find.textContaining('Rodrigo Cruz'), findsOneWidget);

      // Verify risk chips are visible
      expect(find.text(AppStrings.riskLow), findsWidgets);

      // Search filter for "Rodrigo"
      final searchInput = find.byType(TextField);
      await tester.enterText(searchInput, 'Rodrigo');
      await tester.pumpAndSettle();

      expect(find.textContaining('Rodrigo Cruz'), findsOneWidget);
      expect(find.textContaining('Elena Santos'), findsNothing);

      // Clear search
      await tester.enterText(searchInput, '');
      await tester.pumpAndSettle();
      expect(find.textContaining('Elena Santos'), findsOneWidget);
    });

    testWidgets('P6-UX-02: Recording payment via RecordPaymentSheet updates customer balance and chips', (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      await tester.pumpWidget(wrapWithProviders(const UtangScreen()));
      await tester.pumpAndSettle();

      // Find debtor with balance
      final debtor = utangProv.allCustomers.firstWhere((c) => c.balanceCents > 0);
      final initialBalance = debtor.balanceCents;

      // Filter to debtor
      await tester.enterText(find.byType(TextField), debtor.name);
      await tester.pumpAndSettle();

      // Tap "Bayad" button
      await tester.tap(find.text('Bayad').first);
      await tester.pumpAndSettle();

      // Verify RecordPaymentSheet is displayed
      expect(find.text('Pay Utang: ${debtor.displayName}'), findsOneWidget);
      expect(find.text('Quick Payment Amount:'), findsOneWidget);

      // Tap ₱50 quick chip (5000 cents)
      await tester.tap(find.text('₱50'));
      await tester.pumpAndSettle();

      // Confirm payment
      await tester.tap(find.text('Confirm Payment'));
      await tester.pumpAndSettle();

      // Verify debtor balance reduced by ₱50 (5000 cents)
      final updatedDebtor = utangProv.allCustomers.firstWhere((c) => c.id == debtor.id);
      expect(updatedDebtor.balanceCents, equals(initialBalance - 5000));
    });

    testWidgets('P6-UX-03: Add customer FAB opens AddEditCustomerSheet, validates form, and adds customer', (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      await tester.pumpWidget(wrapWithProviders(const UtangScreen()));
      await tester.pumpAndSettle();

      // Tap FAB "Magdagdag ng Customer"
      await tester.tap(find.byIcon(Icons.person_add_alt_1));
      await tester.pumpAndSettle();

      // Verify AddEditCustomerSheet is displayed
      expect(find.byType(AddEditCustomerSheet), findsOneWidget);

      // Try saving without entering name
      await tester.tap(find.byKey(const Key('save_customer_btn')));
      await tester.pumpAndSettle();
      expect(find.text('Customer name is required'), findsOneWidget);

      // Enter customer info
      await tester.enterText(find.byKey(const Key('customer_name_field')), 'Kuya Cardo');
      await tester.enterText(find.byKey(const Key('customer_nickname_field')), 'Ang Panday');
      await tester.enterText(find.byKey(const Key('customer_phone_field')), '09887776655');
      await tester.pumpAndSettle();

      // Save customer
      await tester.tap(find.byKey(const Key('save_customer_btn')));
      await tester.pumpAndSettle();

      // Verify customer appears in UtangScreen
      expect(find.textContaining('Kuya Cardo (Ang Panday)'), findsOneWidget);
    });

    testWidgets('P6-UX-04: CustomerDetailSheet renders running ledger timeline and triggers statement share', (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));

      // Add test customer with 2 utang entries in DB
      final customerId = await customerRepo.insertCustomer(const Customer(
        id: 0,
        name: 'Aling Marites',
        nickname: 'Chismis Queen',
        creditLimitCents: 50000,
        balanceCents: 0,
      ));
      await utangRepo.recordCharge(customerId, 12000, note: 'Sari-sari goods');
      await utangRepo.recordPayment(customerId, 4000, note: 'Partial bayad');
      await utangProv.loadCustomers();

      await tester.pumpWidget(wrapWithProviders(const UtangScreen()));
      await tester.pumpAndSettle();

      // Filter and tap Aling Marites card to open CustomerDetailSheet
      await tester.enterText(find.byType(TextField), 'Aling Marites');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(Card, 'Aling Marites (Chismis Queen)'));
      await tester.pumpAndSettle();

      // Verify detail sheet shows customer displayName, Credit Limit, and Ledger History
      expect(find.text('Aling Marites (Chismis Queen)'), findsWidgets);
      expect(find.text('Current Balance (Utang):'), findsOneWidget);
      expect(find.text('Ledger History'), findsOneWidget);
      expect(find.text('Utang Charge'), findsOneWidget);
      expect(find.text('Bayad (Payment)'), findsOneWidget);

      // Verify action buttons: Bayad Utang & Share Statement
      expect(find.byKey(const Key('customer_detail_bayad_btn')), findsOneWidget);
      expect(find.byKey(const Key('customer_detail_share_btn')), findsOneWidget);

      // Tap "Share Statement" button
      await tester.tap(find.byKey(const Key('customer_detail_share_btn')));
      await tester.pumpAndSettle();

      // Verify statement clipboard fallback occurs cleanly without throwing
      expect(find.byKey(const Key('customer_detail_share_btn')), findsOneWidget);
    });
  });
}
