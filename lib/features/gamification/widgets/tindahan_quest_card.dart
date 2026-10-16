import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/language_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../home/providers/home_provider.dart';
import '../../products/providers/product_provider.dart';
import '../gamification_provider.dart';

/// Gamification card showing Store Level, XP progress, Daily Benta Goal, and Badges.
class TindahanQuestCard extends StatelessWidget {
  const TindahanQuestCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final lang = context.watch<LanguageProvider?>();
    final isTl = lang?.isTagalog ?? false;
    final gameProv = context.watch<GamificationProvider?>() ?? GamificationProvider();
    final homeProv = context.watch<HomeProvider>();
    final productProv = context.watch<ProductProvider>();

    final todaySales = homeProv.todaySalesCents;
    final todayProfit = homeProv.todayProfitCents;
    final itemsSold = homeProv.itemsSoldToday;
    final lowStockCount = productProv.lowStockProducts.length;

    final xp = gameProv.calculateTotalXp(
      todaySalesCents: todaySales,
      itemsSoldToday: itemsSold,
      lowStockCount: lowStockCount,
    );
    final level = gameProv.getLevelFromXp(xp);
    final levelTitle = gameProv.getLevelTitle(level, isTagalog: isTl);
    final goalProgress = gameProv.getDailyGoalProgress(todaySales);
    final goalPercent = (goalProgress * 100).round();
    final badges = gameProv.getBadges(
      todaySalesCents: todaySales,
      todayProfitCents: todayProfit,
      itemsSoldToday: itemsSold,
      lowStockCount: lowStockCount,
    );
    final unlockedCount = badges.where((b) => b.isUnlocked).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF064E3B), const Color(0xFF0F172A)]
              : [const Color(0xFFECFDF5), const Color(0xFFD1FAE5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.primaryGreen.withOpacity(isDark ? 0.4 : 0.28),
          width: 1.4,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Level Pill + XP Counter
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'LVL $level',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  levelTitle,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.accentAmber.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.stars_rounded, size: 14, color: AppTheme.accentAmber),
                    const SizedBox(width: 4),
                    Text(
                      '$xp XP',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.accentAmber,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Daily Sales Goal Progress Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  isTl ? 'Target Benta Ngayon' : 'Daily Sales Goal',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${CurrencyFormatter.format(todaySales)} / ${CurrencyFormatter.formatCompact(gameProv.dailyGoalCents)} ($goalPercent%)',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: goalProgress,
              minHeight: 8,
              backgroundColor: isDark ? Colors.white12 : Colors.white,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryGreen),
            ),
          ),

          const SizedBox(height: 12),

          // Achievement Badges Strip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  isTl
                      ? 'Mga Parangal ($unlockedCount/${badges.length})'
                      : 'Store Badges ($unlockedCount/${badges.length})',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface.withOpacity(0.75),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: badges.map((badge) {
                  final title = isTl ? badge.titleTl : badge.titleEn;
                  return Tooltip(
                    message: title,
                    child: Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: badge.isUnlocked
                            ? badge.color.withOpacity(0.18)
                            : Colors.grey.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: badge.isUnlocked
                              ? badge.color.withOpacity(0.6)
                              : Colors.grey.withOpacity(0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            badge.icon,
                            size: 13,
                            color: badge.isUnlocked ? badge.color : Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
