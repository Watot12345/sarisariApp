import 'package:flutter/material.dart';

class StoreBadge {
  final String id;
  final String titleEn;
  final String titleTl;
  final String descEn;
  final String descTl;
  final IconData icon;
  final Color color;
  final bool isUnlocked;

  const StoreBadge({
    required this.id,
    required this.titleEn,
    required this.titleTl,
    required this.descEn,
    required this.descTl,
    required this.icon,
    required this.color,
    required this.isUnlocked,
  });
}

/// Gamification engine that gives life and purpose to managing a Sari-Sari Store.
/// Rewards owners with XP, Store Levels, Daily Benta Quests, and Badges for healthy store habits.
class GamificationProvider extends ChangeNotifier {
  int _dailyGoalCents = 150000; // Default ₱1,500.00 daily sales goal
  int _bonusXp = 0;

  int get dailyGoalCents => _dailyGoalCents;
  int get dailySalesGoalCents => _dailyGoalCents;
  int get bonusXp => _bonusXp;

  void setDailyGoalCents(int cents) {
    if (cents <= 0) return;
    _dailyGoalCents = cents;
    notifyListeners();
  }

  void setDailySalesGoalCents(int cents) => setDailyGoalCents(cents);

  void addBonusXp(int xp) {
    if (xp <= 0) return;
    _bonusXp += xp;
    notifyListeners();
  }

  /// Computes total XP from store activity:
  /// - Base 50 XP for setting up the store
  /// - +25 XP per sale transaction today
  /// - +10 XP per ₱100 of gross sales today
  /// - +40 XP bonus when daily sales goal is reached
  /// - +30 XP when low-stock alerts are kept under 3 items
  int calculateTotalXp({
    required int todaySalesCents,
    required int itemsSoldToday,
    required int lowStockCount,
  }) {
    int xp = 50 + _bonusXp;
    xp += itemsSoldToday * 25;
    xp += (todaySalesCents ~/ 10000) * 10;
    if (todaySalesCents >= _dailyGoalCents) {
      xp += 40;
    }
    if (lowStockCount < 3) {
      xp += 30;
    }
    return xp;
  }

  /// Determines Store Level (1 to 5) from XP (every 100 XP = 1 level, up to Level 5).
  int getLevelFromXp(int xp) {
    return ((xp ~/ 100) + 1).clamp(1, 5);
  }

  /// Progress (0.0 to 1.0) within the current level.
  double getLevelProgress(int xp) {
    final level = getLevelFromXp(xp);
    if (level >= 5) return 1.0;
    return ((xp % 100) / 100.0).clamp(0.0, 1.0);
  }

  /// Bilingual Store Level Titles
  String getLevelTitle(int level, {required bool isTagalog}) {
    switch (level) {
      case 1:
        return isTagalog ? 'Baguhang Tindera 🌱' : 'Starter Storekeeper 🌱';
      case 2:
        return isTagalog ? 'Masipag na Tindahan ⭐' : 'Hardworking Store ⭐';
      case 3:
        return isTagalog ? 'Suki Magnet 🔥' : 'Suki Favorite 🔥';
      case 4:
        return isTagalog ? 'Barangay Boss 👑' : 'Barangay Boss 👑';
      default:
        return isTagalog ? 'Alamat ng Sari-Sari 🏆' : 'Sari-Sari Legend 🏆';
    }
  }

  /// Daily sales goal progress (0.0 to 1.0).
  double getDailyGoalProgress(int todaySalesCents) {
    if (_dailyGoalCents <= 0) return 1.0;
    return (todaySalesCents / _dailyGoalCents).clamp(0.0, 1.0);
  }

  /// Evaluates the 4 core Sari-Sari Store Achievement Badges.
  List<StoreBadge> getBadges({
    required int todaySalesCents,
    required int todayProfitCents,
    required int itemsSoldToday,
    required int lowStockCount,
  }) {
    return [
      StoreBadge(
        id: 'first_sale',
        titleEn: 'First Sale Today',
        titleTl: 'Unang Benta',
        descEn: 'Complete at least 1 sale today',
        descTl: 'Nakapagtala ng unang benta ngayong araw',
        icon: Icons.bolt_rounded,
        color: const Color(0xFFF59E0B),
        isUnlocked: itemsSoldToday > 0 || todaySalesCents > 0,
      ),
      StoreBadge(
        id: 'profit_earner',
        titleEn: 'Profit Earner',
        titleTl: 'Kita Master',
        descEn: 'Earn positive net profit today',
        descTl: 'May malinis na tubo ngayong araw',
        icon: Icons.trending_up_rounded,
        color: const Color(0xFF10B981),
        isUnlocked: todayProfitCents > 0,
      ),
      StoreBadge(
        id: 'shelf_guardian',
        titleEn: 'Shelf Guardian',
        titleTl: 'Puno ang Estante',
        descEn: 'Keep low-stock items under 3',
        descTl: 'Mas mababa sa 3 ang kulang na paninda',
        icon: Icons.inventory_2_rounded,
        color: const Color(0xFF3B82F6),
        isUnlocked: lowStockCount < 3,
      ),
      StoreBadge(
        id: 'goal_crusher',
        titleEn: 'Goal Crusher',
        titleTl: 'Target Benta Hit!',
        descEn: 'Reach the daily sales target',
        descTl: 'Naabot ang target na benta ngayong araw',
        icon: Icons.emoji_events_rounded,
        color: const Color(0xFF8B5CF6),
        isUnlocked: todaySalesCents >= _dailyGoalCents,
      ),
    ];
  }
}
