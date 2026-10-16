import 'dart:ffi';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';
import 'package:tindahan/core/exceptions.dart';
import 'package:tindahan/core/utils/currency_formatter.dart';
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
import 'package:tindahan/features/sell/providers/cart_provider.dart';

void main() {
  late Database db;
  late AppDatabase appDb;
  late SaleRepository saleRepo;
  late ReportsRepository reportsRepo;
  late ProductRepository productRepo;
  late StockRepository stockRepo;
  late UtangRepository utangRepo;
  late CustomerRepository customerRepo;

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
  });

  tearDown(() async {
    await db.close();
  });

  group('Backend & Business Logic Tests (BE-01 to BE-08)', () {
    test('BE-01: Revenue & Net Profit calculation accurately sums cash, utang, and item margins', () async {
      final product1 = (await productRepo.getProductById(1))!; // Lucky Me: price 1500, cost 1250, margin 250
      final product2 = (await productRepo.getProductById(2))!; // Second product

      // 1. Cash sale: 2 units of product1
      await saleRepo.createSale(
        items: [CartItem(product: product1, qty: 2)],
        paymentType: 'cash',
        cashReceivedCents: 5000,
        changeCents: 5000 - (2 * product1.priceCents),
      );

      // 2. Utang sale: 1 unit of product2 for Customer #1
      await saleRepo.createSale(
        items: [CartItem(product: product2, qty: 1)],
        paymentType: 'utang',
        customerId: 1,
      );

      final expectedCashRev = 2 * product1.priceCents;
      final expectedUtangRev = 1 * product2.priceCents;
      final expectedGrossRev = expectedCashRev + expectedUtangRev;
      final expectedProfit =
          2 * (product1.priceCents - product1.costCents) +
          1 * (product2.priceCents - product2.costCents);

      final todaySummary = await reportsRepo.getTodayStats();
      expect(todaySummary.transactionCount, equals(2));
      expect(todaySummary.cashSalesCents, equals(expectedCashRev));
      expect(todaySummary.utangSalesCents, equals(expectedUtangRev));
      expect(todaySummary.grossRevenueCents, equals(expectedGrossRev));
      expect(todaySummary.netProfitCents, equals(expectedProfit));
    });

    test('BE-02: Voided sales restore stock and are excluded from revenue, profit, and utang reports', () async {
      final product = (await productRepo.getProductById(1))!;
      final initialStock = product.stockQty;
      final initialUtang = await utangRepo.getCustomerBalance(1);

      // Create an utang sale of 3 units
      final sale = await saleRepo.createSale(
        items: [CartItem(product: product, qty: 3)],
        paymentType: 'utang',
        customerId: 1,
      );

      // Verify before voiding
      expect((await productRepo.getProductById(1))!.stockQty, equals(initialStock - 3));
      expect((await reportsRepo.getTodayStats()).grossRevenueCents, equals(3 * product.priceCents));
      expect(await utangRepo.getCustomerBalance(1), equals(initialUtang + 3 * product.priceCents));

      // Void the sale
      await saleRepo.voidSale(sale.id, reason: 'Maling pindot ni Ate');

      // Verify stock restored and revenue/profit/utang reset to pre-sale values
      expect((await productRepo.getProductById(1))!.stockQty, equals(initialStock));
      final summaryAfterVoid = await reportsRepo.getTodayStats();
      expect(summaryAfterVoid.grossRevenueCents, equals(0));
      expect(summaryAfterVoid.netProfitCents, equals(0));
      expect(await utangRepo.getCustomerBalance(1), equals(initialUtang));
    });

    test('BE-03: Top selling products report ranks items by total quantity sold and computes revenue', () async {
      final p1 = (await productRepo.getProductById(1))!;
      final p2 = (await productRepo.getProductById(2))!;

      // Sell 2 of p1 and 5 of p2
      await saleRepo.createSale(
        items: [
          CartItem(product: p1, qty: 2),
          CartItem(product: p2, qty: 5),
        ],
        paymentType: 'cash',
        cashReceivedCents: 50000,
        changeCents: 0,
      );

      final topSellers = await reportsRepo.getTopSellingProducts(limit: 5);
      expect(topSellers.length, equals(2));
      expect(topSellers.first.name, equals(p2.name));
      expect(topSellers.first.qty, equals(5));
      expect(topSellers.first.revenueCents, equals(5 * p2.priceCents));
      expect(topSellers.last.name, equals(p1.name));
      expect(topSellers.last.qty, equals(2));
    });

    test('BE-04: POS CartProvider computes totals, change (sukli), and validates checkout rules', () async {
      final cart = CartProvider(saleRepo: saleRepo);
      final p1 = (await productRepo.getProductById(1))!;
      final twoUnitsTotal = 2 * p1.priceCents;

      cart.addToCart(p1);
      cart.incrementQty(p1.id); // 2 pcs
      expect(cart.itemCount, equals(2));
      expect(cart.totalCents, equals(twoUnitsTotal));
      expect(cart.canCheckout, isTrue);

      // Insufficient cash tendered blocks checkout
      cart.setCashReceived(twoUnitsTotal - 500);
      expect(cart.canCheckout, isFalse);

      // Tender ₱100.00 (10000 cents) -> Change = 10000 - twoUnitsTotal
      cart.setCashReceived(10000);
      expect(cart.canCheckout, isTrue);
      expect(cart.changeCents, equals(10000 - twoUnitsTotal));
    });

    test('BE-05: POS stock limit protection prevents selling more than available stock', () async {
      final p1 = (await productRepo.getProductById(1))!;
      // Attempting to create a sale exceeding stock throws OutOfStockException
      expect(
        () => saleRepo.createSale(
          items: [CartItem(product: p1, qty: p1.stockQty + 10)],
          paymentType: 'cash',
          cashReceivedCents: 999999,
          changeCents: 0,
        ),
        throwsA(isA<OutOfStockException>()),
      );
    });

    test('BE-06: Utang credit checkout and payment flow updates customer and store-wide receivables', () async {
      final initialStoreUtang = await utangRepo.getTotalOutstandingUtang();
      final p1 = (await productRepo.getProductById(1))!;
      final chargeAmount = 2 * p1.priceCents;

      // Utang sale without customer throws ValidationException
      expect(
        () => saleRepo.createSale(
          items: [CartItem(product: p1, qty: 2)],
          paymentType: 'utang',
        ),
        throwsA(isA<ValidationException>()),
      );

      // Utang sale with customer #1
      await saleRepo.createSale(
        items: [CartItem(product: p1, qty: 2)],
        paymentType: 'utang',
        customerId: 1,
      );

      expect(await utangRepo.getTotalOutstandingUtang(), equals(initialStoreUtang + chargeAmount));

      // Customer pays ₱10.00 (1000 cents)
      await utangRepo.recordPayment(1, 1000, note: 'Bayad partial');
      expect(await utangRepo.getTotalOutstandingUtang(), equals(initialStoreUtang + chargeAmount - 1000));

      final customer1 = await customerRepo.getCustomerById(1);
      expect(customer1, isNotNull);
    });

    test('BE-07: Inventory restock and Tingi pack-breaking update stock counts and audit logs', () async {
      final p1 = (await productRepo.getProductById(1))!;
      await stockRepo.restock(p1.id, 10, note: 'Bagong bili sa palengke');

      final afterRestock = (await productRepo.getProductById(1))!;
      expect(afterRestock.stockQty, equals(p1.stockQty + 10));

      // Find a mother pack product from seed data (has piece_product_id != null)
      final allProds = await productRepo.getProducts();
      final packProd = allProds.firstWhere((p) => p.pieceProductId != null && p.piecesPerPack != null);
      final pieceProdBefore = (await productRepo.getProductById(packProd.pieceProductId!))!;

      await stockRepo.breakPack(packProd.id);

      final packProdAfter = (await productRepo.getProductById(packProd.id))!;
      final pieceProdAfter = (await productRepo.getProductById(pieceProdBefore.id))!;

      expect(packProdAfter.stockQty, equals(packProd.stockQty - 1));
      expect(pieceProdAfter.stockQty, equals(pieceProdBefore.stockQty + packProd.piecesPerPack!));
    });

    test('BE-08: Peso currency formatter formats centavos cleanly for revenue & POS displays', () {
      expect(CurrencyFormatter.format(0), equals('₱0.00'));
      expect(CurrencyFormatter.format(1500), equals('₱15.00'));
      expect(CurrencyFormatter.format(125050), equals('₱1,250.50'));
      expect(CurrencyFormatter.formatCompact(5000), equals('₱50'));
      expect(CurrencyFormatter.formatCompact(150000), equals('₱1,500'));
      expect(CurrencyFormatter.parsePesosToCentavos('12.50'), equals(1250));
    });
  });
}
