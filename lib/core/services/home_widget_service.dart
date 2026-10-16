import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import '../utils/currency_formatter.dart';

/// Data model representing a snapshot of sari-sari metrics shown on the Android Home Screen Widget.
class HomeWidgetSnapshot {
  final String storeName;
  final int todaySalesCents;
  final int todayProfitCents;
  final int lowStockCount;
  final DateTime lastUpdated;

  const HomeWidgetSnapshot({
    required this.storeName,
    required this.todaySalesCents,
    required this.todayProfitCents,
    required this.lowStockCount,
    required this.lastUpdated,
  });

  String get todaySalesFormatted => CurrencyFormatter.format(todaySalesCents);
  String get todayProfitFormatted => CurrencyFormatter.format(todayProfitCents);
  String get lowStockFormatted =>
      '$lowStockCount ${lowStockCount == 1 ? 'item' : 'items'}';
  String get lastUpdatedFormatted => DateFormat('h:mm a').format(lastUpdated);

  Map<String, String> toWidgetData() {
    return {
      'store_name': storeName.trim().isEmpty ? AppConstants.appName : storeName,
      'today_sales': todaySalesFormatted,
      'today_profit': todayProfitFormatted,
      'low_stock_count': lowStockFormatted,
      'last_updated': lastUpdatedFormatted,
    };
  }

  @override
  String toString() =>
      'HomeWidgetSnapshot(store: $storeName, sales: $todaySalesFormatted, profit: $todayProfitFormatted, lowStock: $lowStockFormatted)';
}

/// Service managing synchronization between Tindahan SQLite records and the Android Home Screen Widget.
/// Operates 100% offline via local SharedPreferences and AppWidgetManager.
class HomeWidgetService {
  HomeWidgetService._();

  static const String androidWidgetProvider = 'SariWidgetProvider';
  static const String appGroupId = 'group.com.tindahan.app';

  static HomeWidgetSnapshot? _lastSnapshot;
  static HomeWidgetSnapshot? get lastSnapshot => _lastSnapshot;

  static bool get _isFlutterTest {
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  /// Updates the Android Home Screen Widget with the latest sari-sari store statistics.
  /// Safe to call across all platforms and test suites (catches MissingPluginException gracefully).
  static Future<bool> updateSnapshot(HomeWidgetSnapshot snapshot) async {
    _lastSnapshot = snapshot;

    if (kIsWeb || _isFlutterTest) return true;

    try {
      final data = snapshot.toWidgetData();
      for (final entry in data.entries) {
        await HomeWidget.saveWidgetData<String>(entry.key, entry.value);
      }

      await HomeWidget.updateWidget(
        name: androidWidgetProvider,
        androidName: androidWidgetProvider,
      );
      return true;
    } catch (e) {
      if (e.toString().contains('MissingPluginException')) {
        return true;
      }
      debugPrint('HomeWidgetService update note: $e');
      return false;
    }
  }

  /// Checks if the app was launched by tapping a quick action on the Android home screen widget.
  static Future<Uri?> getInitiallyLaunchedUri() async {
    if (kIsWeb || _isFlutterTest) return null;
    try {
      return await HomeWidget.initiallyLaunchedFromHomeWidget();
    } catch (_) {
      return null;
    }
  }

  /// Listens to widget click events while the app is in the background or active.
  static Stream<Uri?> get widgetClicked {
    if (_isFlutterTest) return const Stream.empty();
    return HomeWidget.widgetClicked;
  }
}
