import 'package:flutter/material.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/product.dart';

/// Provider for managing in-app notifications, badge count, and push alerts.
class NotificationProvider extends ChangeNotifier {
  final NotificationService _service;
  final List<AppNotification> _notifications = [];
  int _nextId = 1;

  // Tracking alert cooldowns to avoid repeated spamming
  final Set<int> _notifiedLowStockProductIds = {};
  bool _goalAlertFiredToday = false;

  NotificationProvider({NotificationService? service})
      : _service = service ?? NotificationService.instance {
    // Seed initial informational notification for store owner
    _notifications.add(
      AppNotification(
        id: _nextId++,
        title: 'Maligayang Pagdating sa SariMe! (Welcome)',
        body: 'Handa na ang iyong tindahan para magtala ng benta, imbentaryo, at utang.',
        type: NotificationType.systemAlert,
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        isRead: false,
      ),
    );
  }

  List<AppNotification> get notifications =>
      List.unmodifiable(_notifications.reversed);

  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  bool get hasUnread => unreadCount > 0;

  /// Marks all current notifications as read.
  void markAllAsRead() {
    bool changed = false;
    for (final notif in _notifications) {
      if (!notif.isRead) {
        notif.isRead = true;
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  /// Marks an individual notification as read.
  void markAsRead(int id) {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1 && !_notifications[idx].isRead) {
      _notifications[idx].isRead = true;
      notifyListeners();
    }
  }

  /// Removes an individual notification.
  void removeNotification(int id) {
    _notifications.removeWhere((n) => n.id == id);
    notifyListeners();
  }

  /// Clears all notifications.
  void clearAll() {
    _notifications.clear();
    notifyListeners();
  }

  /// Dispatches a push notification and records it in the app notification feed.
  Future<void> sendNotification({
    required String title,
    required String body,
    NotificationType type = NotificationType.systemAlert,
    String? payload,
  }) async {
    final notifId = _nextId++;
    final notif = AppNotification(
      id: notifId,
      title: title,
      body: body,
      type: type,
      timestamp: DateTime.now(),
      payload: payload,
      isRead: false,
    );

    _notifications.add(notif);
    notifyListeners();

    await _service.showNotification(
      id: notifId,
      title: title,
      body: body,
      type: type,
      payload: payload,
    );
  }

  /// Checks for low stock products and dispatches an alert if threshold reached.
  Future<void> checkLowStockAlerts(
    List<Product> lowStockProducts, {
    bool isTagalog = false,
  }) async {
    for (final prod in lowStockProducts) {
      if (!_notifiedLowStockProductIds.contains(prod.id)) {
        _notifiedLowStockProductIds.add(prod.id);
        final title = isTagalog
            ? '⚠️ Alerto: Paubos na ang ${prod.name}'
            : '⚠️ Low Stock Alert: ${prod.name}';
        final body = isTagalog
            ? 'May natitirang ${prod.stockQty} piraso na lang sa estante. Mag-restock na!'
            : 'Only ${prod.stockQty} items left in stock. Tap to restock now.';

        await sendNotification(
          title: title,
          body: body,
          type: NotificationType.lowStock,
          payload: 'tindahan://products',
        );
      }
    }
  }

  /// Checks if daily sales goal has been reached and fires celebration push notification.
  Future<void> checkDailyGoalAlert({
    required int currentSalesCents,
    required int goalCents,
    bool isTagalog = false,
  }) async {
    if (goalCents > 0 &&
        currentSalesCents >= goalCents &&
        !_goalAlertFiredToday) {
      _goalAlertFiredToday = true;
      final formattedGoal = CurrencyFormatter.format(goalCents);
      final title = isTagalog
          ? '🎉 Naabot ang Target Benta Ngayon!'
          : '🎉 Daily Sales Goal Reached!';
      final body = isTagalog
          ? 'Nakamit mo na ang iyong target na $formattedGoal ngayong araw! Magaling!'
          : 'You hit your target of $formattedGoal for today! Great job!';

      await sendNotification(
        title: title,
        body: body,
        type: NotificationType.dailyGoal,
        payload: 'tindahan://home',
      );
    }
  }

  /// Sends a quick test push notification so the user can verify text and icon.
  Future<void> sendTestNotification({bool isTagalog = false}) async {
    final title = isTagalog
        ? '🔔 SariMe: Test Notipikasyon'
        : '🔔 SariMe: Test Push Notification';
    final body = isTagalog
        ? 'Gumagana ang notification icon at mensahe para sa iyong tindahan!'
        : 'Notification icon and text alerts are working perfectly for your store!';

    await sendNotification(
      title: title,
      body: body,
      type: NotificationType.systemAlert,
      payload: 'tindahan://home',
    );
  }
}
