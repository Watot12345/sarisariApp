import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/language_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../home/providers/home_provider.dart';
import '../../products/providers/product_provider.dart';
import '../gamification_provider.dart';
import '../widgets/animated_store_avatar.dart';

/// Dedicated Store Avatar & Gamification Screen opened when tapping the avatar emoticon on HomeScreen.
/// Keeps the main Home Dashboard focused on store management while giving the storekeeper a fun,
/// motivating place to view their animated avatar, Store Level, Daily Sales Goal, and Badges.
class StoreAvatarScreen extends StatefulWidget {
  const StoreAvatarScreen({super.key});

  @override
  State<StoreAvatarScreen> createState() => _StoreAvatarScreenState();
}

class _StoreAvatarScreenState extends State<StoreAvatarScreen> {
  int _quoteIndex = 0;

  List<String> _getQuotes(bool isTl, int level) {
    if (isTl) {
      return [
        'Kumusta! Tuloy-tuloy lang sa paglista ng benta at kita!',
        'Bawat benta at saktong paninda ay dagdag XP sa iyong tindahan!',
        'Suki tip: Panatilihing kumpleto ang paninda para laging masaya ang mamimili!',
      ];
    }
    return [
      'Keep up the great work managing your store revenue and inventory!',
      'Every recorded sale and healthy stock level earns XP for your store!',
      'Store Tip: Tracking daily sales and utang keeps your profit growing!',
    ];
  }

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
    final levelProgress = gameProv.getLevelProgress(xp);
    final goalProgress = gameProv.getDailyGoalProgress(todaySales);
    final goalPercent = (goalProgress * 100).round();
    final badges = gameProv.getBadges(
      todaySalesCents: todaySales,
      todayProfitCents: todayProfit,
      itemsSoldToday: itemsSold,
      lowStockCount: lowStockCount,
    );
    final unlockedCount = badges.where((b) => b.isUnlocked).length;
    final quotes = _getQuotes(isTl, level);
    final currentQuote = quotes[_quoteIndex % quotes.length];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isTl ? 'Avatar at Antas ng Tindahan' : 'Store Avatar & Progress',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Hero Animated Avatar Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF064E3B), const Color(0xFF0F172A)]
                    : [const Color(0xFFECFDF5), const Color(0xFFD1FAE5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppTheme.primaryGreen.withOpacity(isDark ? 0.45 : 0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                // Moving Animated Avatar Emoticon
                AnimatedStoreAvatar(
                  key: const Key('hero_animated_store_avatar'),
                  level: level,
                  size: 108,
                  isInteractive: true,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _quoteIndex = (_quoteIndex + 1) % quotes.length;
                    });
                  },
                ),
                const SizedBox(height: 12),

                // Level & Title Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'LVL $level • $levelTitle',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // XP Pill
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.stars_rounded, size: 18, color: AppTheme.accentAmber),
                    const SizedBox(width: 4),
                    Text(
                      '$xp XP',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.accentAmber,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Level XP Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: levelProgress,
                    minHeight: 8,
                    backgroundColor: isDark ? Colors.white12 : Colors.white,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accentAmber),
                  ),
                ),
                const SizedBox(height: 14),

                // Avatar Speech Bubble
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black26 : Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Text(
                        currentQuote,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isTl
                            ? '(Pindutin ang avatar para magpalit ng mensahe)'
                            : '(Tap the avatar to cheer & see another tip)',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: theme.colorScheme.onSurface.withOpacity(0.55),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 2. Daily Sales Goal Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          isTl ? 'Target Benta Ngayon' : 'Daily Sales Goal',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${CurrencyFormatter.format(todaySales)} / ${CurrencyFormatter.formatCompact(gameProv.dailyGoalCents)} ($goalPercent%)',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: goalProgress,
                      minHeight: 10,
                      backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryGreen),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [50000, 100000, 150000, 200000, 500000].map((cents) {
                      final isSelected = gameProv.dailyGoalCents == cents;
                      return ChoiceChip(
                        label: Text(CurrencyFormatter.formatCompact(cents)),
                        selected: isSelected,
                        onSelected: (_) => gameProv.setDailyGoalCents(cents),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 3. Store Achievement Badges Section
          Text(
            isTl
                ? 'Mga Parangal ($unlockedCount/${badges.length})'
                : 'Store Badges ($unlockedCount/${badges.length})',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ...badges.map((badge) {
            final title = isTl ? badge.titleTl : badge.titleEn;
            final desc = isTl ? badge.descTl : badge.descEn;
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: badge.isUnlocked
                      ? badge.color.withOpacity(0.18)
                      : Colors.grey.withOpacity(0.15),
                  child: Icon(
                    badge.icon,
                    color: badge.isUnlocked ? badge.color : Colors.grey,
                  ),
                ),
                title: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: badge.isUnlocked
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
                subtitle: Text(
                  desc,
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Icon(
                  badge.isUnlocked ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
                  color: badge.isUnlocked ? AppTheme.primaryGreen : Colors.grey,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
