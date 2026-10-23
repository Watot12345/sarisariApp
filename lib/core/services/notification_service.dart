import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

/// Categories of store alerts and push notifications.
enum NotificationType {
  lowStock,
  dailyGoal,
  utangReminder,
  saleSuccess,
  systemAlert,
}

/// Represents an in-app and push notification record.
class AppNotification {
  final int id;
  final String title;
  final String body;
  final NotificationType type;
  final DateTime timestamp;
  final String? payload;
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    DateTime? timestamp,
    this.payload,
    this.isRead = false,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Dedicated icon for the notification type.
  IconData get icon {
    switch (type) {
      case NotificationType.lowStock:
        return Icons.warning_amber_rounded;
      case NotificationType.dailyGoal:
        return Icons.emoji_events_rounded;
      case NotificationType.utangReminder:
        return Icons.menu_book_rounded;
      case NotificationType.saleSuccess:
        return Icons.check_circle_outline_rounded;
      case NotificationType.systemAlert:
        return Icons.notifications_active_rounded;
    }
  }

  /// Color accent for the notification icon pill.
  Color get color {
    switch (type) {
      case NotificationType.lowStock:
        return AppTheme.dangerRed;
      case NotificationType.dailyGoal:
        return const Color(0xFFF59E0B); // Amber / Gold
      case NotificationType.utangReminder:
        return AppTheme.accentBlue;
      case NotificationType.saleSuccess:
        return AppTheme.primaryGreen;
      case NotificationType.systemAlert:
        return const Color(0xFF6366F1); // Indigo
    }
  }

  /// Relative or formatted time label for UI display.
  String get formattedTime {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('MMM d, h:mm a').format(timestamp);
  }

  AppNotification copyWith({
    int? id,
    String? title,
    String? body,
    NotificationType? type,
    DateTime? timestamp,
    String? payload,
    bool? isRead,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      payload: payload ?? this.payload,
      isRead: isRead ?? this.isRead,
    );
  }
}

/// Offline push notification service wrapper using flutter_local_notifications.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const String channelId = 'tindahan_store_alerts';
  static const String channelName = 'SariMe Store Alerts';
  static const String channelDesc =
      'Notifications for low stock alerts, sales milestones, and utang reminders';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  final List<AppNotification> _dispatched = [];

  /// In-memory log of dispatched notifications (useful for tests and offline logs).
  List<AppNotification> get dispatched => List.unmodifiable(_dispatched);

  bool get isTestMode => Platform.environment.containsKey('FLUTTER_TEST');

  /// Initializes the local notification plugin and registers Android channel.
  Future<void> initialize({
    void Function(NotificationResponse)? onDidReceiveNotificationResponse,
  }) async {
    if (_initialized || isTestMode) {
      _initialized = true;
      return;
    }

    const androidSettings = AndroidInitializationSettings('ic_notification');
    const initSettings = InitializationSettings(
      android: androidSettings,
      linux: LinuxInitializationSettings(defaultActionName: 'Open'),
    );

    try {
      await _plugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
      );

      // Create Android Notification Channel
      final androidImplementation = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        await androidImplementation.createNotificationChannel(
          const AndroidNotificationChannel(
            channelId,
            channelName,
            description: channelDesc,
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
          ),
        );
      }
    } catch (_) {
      // Graceful fallback if platform channels are unavailable
    }

    _initialized = true;
  }

  bool _permissionsRequested = false;

  /// Request permissions for Android 13+ (POST_NOTIFICATIONS).
  Future<bool?> requestPermissions() async {
    if (isTestMode) return true;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      _permissionsRequested = true;
      return await android?.requestNotificationsPermission();
    } catch (_) {
      return false;
    }
  }

  /// Display a local push notification on the device status bar.
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    NotificationType type = NotificationType.systemAlert,
    String? payload,
  }) async {
    final notification = AppNotification(
      id: id,
      title: title,
      body: body,
      type: type,
      payload: payload,
    );
    _dispatched.add(notification);

    if (isTestMode) return;

    if (!_initialized) {
      await initialize();
    }
    if (!_permissionsRequested) {
      await requestPermissions();
    }

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      icon: 'ic_notification',
      color: type == NotificationType.lowStock
          ? AppTheme.dangerRed
          : AppTheme.primaryGreen,
      ticker: title,
      styleInformation: BigTextStyleInformation(body),
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
        payload: payload,
      );
    } catch (_) {
      // Fallback silently if system notification service fails
    }
  }

  /// Cancel a specific notification.
  Future<void> cancel(int id) async {
    if (isTestMode) return;
    try {
      await _plugin.cancel(id: id);
    } catch (_) {}
  }

  /// Cancel all active notifications.
  Future<void> cancelAll() async {
    if (isTestMode) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }
}
