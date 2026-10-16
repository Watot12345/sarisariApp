import 'package:flutter/material.dart';
import '../../../data/repositories/reports_repository.dart';

class DailySalePoint {
  final String dayName;
  final int salesCents;
  const DailySalePoint(this.dayName, this.salesCents);
}

/// Provider managing Home Dashboard statistics and real SQLite Reports.
class HomeProvider extends ChangeNotifier {
  final ReportsRepository _reportsRepo;

  SalesPeriodSummary _todaySummary = SalesPeriodSummary.zero();
  SalesPeriodSummary _weekSummary = SalesPeriodSummary.zero();
  SalesPeriodSummary _monthSummary = SalesPeriodSummary.zero();
  List<TopSellingProduct> _topSellers = [];
  bool _isLoading = false;

  final List<DailySalePoint> _last7DaysSales = const [
    DailySalePoint('Mon', 0),
    DailySalePoint('Tue', 0),
    DailySalePoint('Wed', 0),
    DailySalePoint('Thu', 0),
    DailySalePoint('Fri', 0),
    DailySalePoint('Sat', 0),
    DailySalePoint('Today', 0),
  ];

  HomeProvider({ReportsRepository? reportsRepo})
      : _reportsRepo = reportsRepo ?? ReportsRepository() {
    loadDashboard();
  }

  bool get isLoading => _isLoading;

  // Real SQLite Period Metrics
  int get todaySalesCents => _todaySummary.grossRevenueCents;
  int get todayProfitCents => _todaySummary.netProfitCents;
  int get itemsSoldToday => _todaySummary.transactionCount;

  int get weekSalesCents => _weekSummary.grossRevenueCents;
  int get weekProfitCents => _weekSummary.netProfitCents;

  int get monthSalesCents => _monthSummary.grossRevenueCents;
  int get monthProfitCents => _monthSummary.netProfitCents;

  List<TopSellingProduct> get topSellers => List.unmodifiable(_topSellers);
  List<DailySalePoint> get last7DaysSales => _last7DaysSales;

  Future<void> loadDashboard() async {
    _isLoading = true;
    notifyListeners();

    try {
      _todaySummary = await _reportsRepo.getTodayStats();
      _weekSummary = await _reportsRepo.getThisWeekStats();
      _monthSummary = await _reportsRepo.getThisMonthStats();
      _topSellers = await _reportsRepo.getTopSellingProducts(limit: 5);
    } catch (_) {
      // Fallback to zero summary on error
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
