import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/notification_provider.dart';
import 'notifications_sheet.dart';

/// Notification Bell Icon button with live unread badge for AppBars.
class NotificationBellButton extends StatelessWidget {
  const NotificationBellButton({super.key});

  @override
  Widget build(BuildContext context) {
    final notifProv = context.watch<NotificationProvider?>();
    final unreadCount = notifProv?.unreadCount ?? 0;

    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          key: const Key('notification_bell_btn'),
          icon: Icon(
            unreadCount > 0
                ? Icons.notifications_active_rounded
                : Icons.notifications_outlined,
            color: unreadCount > 0 ? AppTheme.primaryGreen : null,
          ),
          tooltip: 'Notifications',
          onPressed: () {
            HapticFeedback.lightImpact();
            NotificationsSheet.show(context);
          },
        ),
        if (unreadCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: IgnorePointer(
              child: Container(
                key: const Key('notification_badge_count'),
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AppTheme.dangerRed,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: Center(
                  child: Text(
                    unreadCount > 9 ? '9+' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
