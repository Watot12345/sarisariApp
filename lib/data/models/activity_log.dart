import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Immutable domain model representing a store audit trail / activity log entry.
class ActivityLog {
  final int? id;
  final String actionType;
  final String title;
  final String description;
  final DateTime createdAt;

  const ActivityLog({
    this.id,
    required this.actionType,
    required this.title,
    required this.description,
    required this.createdAt,
  });

  factory ActivityLog.fromMap(Map<String, dynamic> map) {
    return ActivityLog(
      id: map['id'] as int?,
      actionType: (map['action_type'] as String?) ?? 'system',
      title: (map['title'] as String?) ?? '',
      description: (map['description'] as String?) ?? '',
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'action_type': actionType,
      'title': title,
      'description': description,
      'created_at': createdAt.toIso8601String(),
    };
  }

  IconData get icon {
    switch (actionType) {
      case 'sale_completed':
        return Icons.point_of_sale_rounded;
      case 'sale_voided':
        return Icons.remove_shopping_cart_rounded;
      case 'product_added':
      case 'product_edited':
        return Icons.inventory_2_rounded;
      case 'product_deleted':
        return Icons.delete_outline_rounded;
      case 'stock_restocked':
        return Icons.add_box_rounded;
      case 'credit_charged':
        return Icons.menu_book_rounded;
      case 'credit_paid':
        return Icons.payments_rounded;
      case 'security_event':
        return Icons.shield_rounded;
      default:
        return Icons.history_rounded;
    }
  }

  Color get color {
    switch (actionType) {
      case 'sale_completed':
      case 'credit_paid':
        return AppTheme.primaryGreen;
      case 'sale_voided':
      case 'product_deleted':
        return AppTheme.dangerRed;
      case 'credit_charged':
        return AppTheme.accentAmber;
      case 'stock_restocked':
      case 'product_added':
      case 'product_edited':
        return AppTheme.accentBlue;
      default:
        return const Color(0xFF6366F1);
    }
  }
}
