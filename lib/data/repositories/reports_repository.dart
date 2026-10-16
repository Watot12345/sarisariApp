import 'package:sqflite/sqflite.dart';
import '../db/app_database.dart';

class SalesPeriodSummary {
  final int grossRevenueCents;
  final int netProfitCents;
  final int transactionCount;
  final int cashSalesCents;
  final int utangSalesCents;

  const SalesPeriodSummary({
    required this.grossRevenueCents,
    required this.netProfitCents,
    required this.transactionCount,
    required this.cashSalesCents,
    required this.utangSalesCents,
  });

  factory SalesPeriodSummary.zero() => const SalesPeriodSummary(
        grossRevenueCents: 0,
        netProfitCents: 0,
        transactionCount: 0,
        cashSalesCents: 0,
        utangSalesCents: 0,
      );
}

class TopSellingProduct {
  final String name;
  final int qty;
  final int revenueCents;

  const TopSellingProduct({
    required this.name,
    required this.qty,
    required this.revenueCents,
  });
}

class ReportsRepository {
  final AppDatabase _appDb;
  ReportsRepository([AppDatabase? appDb]) : _appDb = appDb ?? AppDatabase.instance;

  Future<Database> get _db async => await _appDb.database;

  /// Aggregates sales and profit within a UTC date range.
  Future<SalesPeriodSummary> getSalesSummary(DateTime from, DateTime to) async {
    final db = await _db;
    final fromIso = from.toUtc().toIso8601String();
    final toIso = to.toUtc().toIso8601String();

    // 1. Sales totals
    final salesRows = await db.rawQuery('''
      SELECT 
        COUNT(*) AS tx_count,
        COALESCE(SUM(total_cents), 0) AS total_revenue,
        COALESCE(SUM(CASE WHEN payment_type = 'cash' THEN total_cents ELSE 0 END), 0) AS cash_revenue,
        COALESCE(SUM(CASE WHEN payment_type = 'utang' THEN total_cents ELSE 0 END), 0) AS utang_revenue
      FROM sales
      WHERE status = 'completed'
        AND sold_at >= ? AND sold_at <= ?
    ''', [fromIso, toIso]);

    final txCount = (salesRows.first['tx_count'] as int?) ?? 0;
    final revenue = (salesRows.first['total_revenue'] as int?) ?? 0;
    final cash = (salesRows.first['cash_revenue'] as int?) ?? 0;
    final utang = (salesRows.first['utang_revenue'] as int?) ?? 0;

    // 2. Net profit calculation: SUM((unit_price_cents - unit_cost_cents) * qty)
    final profitRows = await db.rawQuery('''
      SELECT 
        COALESCE(SUM((si.unit_price_cents - si.unit_cost_cents) * si.qty), 0) AS net_profit
      FROM sale_items si
      JOIN sales s ON si.sale_id = s.id
      WHERE s.status = 'completed'
        AND s.sold_at >= ? AND s.sold_at <= ?
    ''', [fromIso, toIso]);

    final profit = (profitRows.first['net_profit'] as int?) ?? 0;

    return SalesPeriodSummary(
      grossRevenueCents: revenue,
      netProfitCents: profit,
      transactionCount: txCount,
      cashSalesCents: cash,
      utangSalesCents: utang,
    );
  }

  Future<SalesPeriodSummary> getTodayStats() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return getSalesSummary(startOfDay, endOfDay);
  }

  Future<SalesPeriodSummary> getThisWeekStats() {
    final now = DateTime.now();
    // Last 7 days
    final startOfWeek = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    final endOfWeek = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return getSalesSummary(startOfWeek, endOfWeek);
  }

  Future<SalesPeriodSummary> getThisMonthStats() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return getSalesSummary(startOfMonth, endOfMonth);
  }

  Future<List<TopSellingProduct>> getTopSellingProducts({int limit = 5}) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT 
        si.product_name AS name,
        SUM(si.qty) AS total_qty,
        SUM(si.unit_price_cents * si.qty) AS total_revenue
      FROM sale_items si
      JOIN sales s ON si.sale_id = s.id
      WHERE s.status = 'completed'
      GROUP BY si.product_name
      ORDER BY total_qty DESC
      LIMIT ?
    ''', [limit]);

    return rows.map((r) {
      return TopSellingProduct(
        name: r['name'] as String,
        qty: (r['total_qty'] as int?) ?? 0,
        revenueCents: (r['total_revenue'] as int?) ?? 0,
      );
    }).toList();
  }
}
