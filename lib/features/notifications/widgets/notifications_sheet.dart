import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants.dart';
import '../../../core/localization/language_provider.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../navigation/navigation_provider.dart';
import '../providers/notification_provider.dart';

/// Bottom sheet displaying the in-app notification center and test push notification triggers.
class NotificationsSheet extends StatelessWidget {
  const NotificationsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const NotificationsSheet(),
    );
  }

  void _handleNotificationTap(BuildContext context, AppNotification notif) {
    context.read<NotificationProvider>().markAsRead(notif.id);
    Navigator.pop(context);

    if (notif.payload != null) {
      final nav = context.read<NavigationProvider?>();
      if (nav != null) {
        if (notif.payload == 'tindahan://products') {
          nav.openProducts();
        } else if (notif.payload == 'tindahan://utang') {
          nav.openUtang();
        } else if (notif.payload == 'tindahan://sell') {
          nav.openSell();
        } else if (notif.payload == 'tindahan://home') {
          nav.openHome();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final notifProv = context.watch<NotificationProvider>();
    final langProv = context.watch<LanguageProvider?>();
    final isTl = langProv?.isTagalog ?? false;
    final notifications = notifProv.notifications;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppConstants.borderRadiusTopSheet,
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.notifications_rounded,
                      color: AppTheme.primaryGreen,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isTl ? 'Mga Alerto ng Tindahan' : 'Store Notifications',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          isTl
                              ? '${notifProv.unreadCount} hindi pa nababasa'
                              : '${notifProv.unreadCount} unread',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (notifProv.hasUnread)
                    TextButton(
                      key: const Key('mark_all_read_btn'),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        notifProv.markAllAsRead();
                      },
                      child: Text(
                        isTl ? 'Basahin Lahat' : 'Mark all read',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  if (notifications.isNotEmpty)
                    IconButton(
                      key: const Key('clear_all_notifications_btn'),
                      icon: const Icon(Icons.delete_sweep_outlined, size: 20),
                      tooltip: isTl ? 'Burahin Lahat' : 'Clear all',
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        notifProv.clearAll();
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Notifications List
            Expanded(
              child: notifications.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_off_outlined,
                            size: 48,
                            color: Colors.grey.withOpacity(0.4),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isTl
                                ? 'Walang bagong alerto'
                                : 'No notifications yet',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isTl
                                ? 'Lalabas dito ang mga paalala sa paubos na paninda at benta.'
                                : 'Alerts for low stock and sales goals will show up here.',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface.withOpacity(0.4),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: notifications.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, index) {
                        final notif = notifications[index];
                        return _NotificationCard(
                          notification: notif,
                          onTap: () => _handleNotificationTap(context, notif),
                          onDismissed: () =>
                              notifProv.removeNotification(notif.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismissed;

  const _NotificationCard({
    required this.notification,
    required this.onTap,
    required this.onDismissed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dismissible(
      key: ValueKey<int>(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: AppTheme.dangerRed,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => onDismissed(),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: notification.isRead
                ? (isDark ? const Color(0xFF131B2B) : const Color(0xFFF8FAFC))
                : (isDark
                    ? const Color(0xFF1A263D)
                    : AppTheme.primaryGreen.withOpacity(0.06)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: notification.isRead
                  ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0))
                  : AppTheme.primaryGreen.withOpacity(0.3),
              width: notification.isRead ? 1 : 1.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Notification Category Icon with colorful pill
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: notification.color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  notification.icon,
                  color: notification.color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),

              // Title, Body, and Timestamp
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: notification.isRead
                                  ? FontWeight.w600
                                  : FontWeight.w800,
                            ),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppTheme.primaryGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withOpacity(0.75),
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notification.formattedTime,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface.withOpacity(0.45),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
